package com.jeromegsq.speech_to_text

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class SpeechToTextPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler,
    ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null

    private var speechRecognizer: SpeechRecognizer? = null
    private var lastTranscript: String = ""
    private var accumulatedTranscript: String = "" // Accumulates text across restarts
    private var lastConfidence: Double = 0.0
    private var isManuallyStopped: Boolean = false
    private var currentLanguage: String = "en-US"
    private var isListening: Boolean = false
    private var restartCount: Int = 0
    private val maxRestarts: Int = 50 // Max restarts to prevent infinite loop

    private var permissionResult: Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "SpeechToTextPlugin"
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "com.jeromegsq.speech_to_text/methods"
        )
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "com.jeromegsq.speech_to_text/events"
        )
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        destroySpeechRecognizer()
    }

    // MARK: - ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // MARK: - EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "onListen: EventSink registered")
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel: EventSink cancelled")
        eventSink = null
    }

    // MARK: - MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "start" -> {
                val language = call.argument<String>("language")
                if (language == null) {
                    result.error("INVALID_ARGUMENTS", "Language is required", null)
                    return
                }
                start(language, result)
            }
            "stop" -> stop(result)
            "requestPermissions" -> requestPermissions(result)
            "isAvailable" -> isAvailable(result)
            else -> result.notImplemented()
        }
    }

    // MARK: - Public Methods

    private fun start(language: String, result: Result) {
        Log.i(TAG, "╔════════════════════════════════════════════════════════════")
        Log.i(TAG, "║ 🎤 START RECORDING - User initiated")
        Log.i(TAG, "║ Language: $language")
        Log.i(TAG, "╚════════════════════════════════════════════════════════════")
        
        val ctx = context ?: run {
            Log.e(TAG, "❌ START FAILED: Context not available")
            result.error("NOT_AVAILABLE", "Context not available", null)
            return
        }

        lastTranscript = ""
        accumulatedTranscript = ""
        lastConfidence = 0.0
        isManuallyStopped = false
        currentLanguage = language
        isListening = true
        restartCount = 0

        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "❌ START FAILED: Permission denied")
            result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(ctx)) {
            Log.e(TAG, "❌ START FAILED: Speech recognition not available")
            result.error("NOT_AVAILABLE", "Speech recognition not available", null)
            return
        }

        mainHandler.post {
            startListeningInternal(ctx, result)
        }
    }

    private fun startListeningInternal(ctx: Context, result: Result?) {
        Log.d(TAG, "┌─────────────────────────────────────────────────────────────")
        Log.d(TAG, "│ 🔄 startListeningInternal - Creating speech recognizer...")
        Log.d(TAG, "└─────────────────────────────────────────────────────────────")
        
        try {
            // Properly cleanup previous recognizer if exists
            speechRecognizer?.let { recognizer ->
                try {
                    recognizer.cancel()
                    recognizer.destroy()
                } catch (e: Exception) {
                    Log.w(TAG, "│ Warning: Error cleaning up previous recognizer: ${e.message}")
                }
            }
            speechRecognizer = null
            
            // Create new recognizer
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(ctx)

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, currentLanguage)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                // Increase silence detection timeout to 10 seconds
                putExtra(
                    RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                    10000L
                )
                putExtra(
                    RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                    10000L
                )
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 60000L)
            }

            speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    Log.i(TAG, "✅ onReadyForSpeech - Microphone is now listening")
                }
                override fun onBeginningOfSpeech() {
                    Log.i(TAG, "🗣️ onBeginningOfSpeech - User started speaking")
                }
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    Log.w(TAG, "╔════════════════════════════════════════════════════════════")
                    Log.w(TAG, "║ ⚠️ onEndOfSpeech - OS detected end of speech")
                    Log.w(TAG, "║ isManuallyStopped=$isManuallyStopped, isListening=$isListening")
                    Log.w(TAG, "║ 📍 This is triggered by: ANDROID OS (silence detected)")
                    Log.w(TAG, "╚════════════════════════════════════════════════════════════")
                    // Don't send end event here - onResults or onError will handle restart
                }

                override fun onError(error: Int) {
                    val errorName = when (error) {
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ERROR_NETWORK_TIMEOUT"
                        SpeechRecognizer.ERROR_NETWORK -> "ERROR_NETWORK"
                        SpeechRecognizer.ERROR_AUDIO -> "ERROR_AUDIO"
                        SpeechRecognizer.ERROR_SERVER -> "ERROR_SERVER"
                        SpeechRecognizer.ERROR_CLIENT -> "ERROR_CLIENT"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "ERROR_SPEECH_TIMEOUT"
                        SpeechRecognizer.ERROR_NO_MATCH -> "ERROR_NO_MATCH"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "ERROR_RECOGNIZER_BUSY"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "ERROR_INSUFFICIENT_PERMISSIONS"
                        10 -> "ERROR_TOO_MANY_REQUESTS"
                        11 -> "ERROR_SERVER_DISCONNECTED"
                        12 -> "ERROR_LANGUAGE_NOT_SUPPORTED"
                        13 -> "ERROR_LANGUAGE_UNAVAILABLE"
                        else -> "UNKNOWN_ERROR($error)"
                    }
                    
                    Log.w(TAG, "╔════════════════════════════════════════════════════════════")
                    Log.w(TAG, "║ ⚠️ onError - Error from Android OS")
                    Log.w(TAG, "║ Error: $errorName (code: $error)")
                    Log.w(TAG, "║ isManuallyStopped=$isManuallyStopped, isListening=$isListening")
                    Log.w(TAG, "║ restartCount=$restartCount/$maxRestarts")
                    Log.w(TAG, "║ 📍 This is triggered by: ANDROID OS")
                    Log.w(TAG, "╚════════════════════════════════════════════════════════════")
                    
                    if (isManuallyStopped) {
                        Log.d(TAG, "│ Ignoring error because manually stopped")
                        return
                    }
                    
                    // Recoverable errors - restart listening
                    // ERROR_NO_MATCH (7): No speech detected
                    // ERROR_SPEECH_TIMEOUT (6): No speech input
                    // ERROR_SERVER_DISCONNECTED (11): Server connection lost during restart
                    // ERROR_CLIENT (5): Can happen during rapid restarts
                    // ERROR_RECOGNIZER_BUSY (8): Previous recognizer still running
                    val isRecoverableError = error == SpeechRecognizer.ERROR_NO_MATCH ||
                            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT ||
                            error == 11 || // ERROR_SERVER_DISCONNECTED
                            error == SpeechRecognizer.ERROR_CLIENT ||
                            error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY
                    
                    if (isRecoverableError && isListening && restartCount < maxRestarts) {
                        Log.i(TAG, "🔄 Recoverable error, restarting... ($errorName)")
                        restartListening()
                        return
                    }
                    
                    if (restartCount >= maxRestarts) {
                        Log.e(TAG, "🛑 Max restarts ($maxRestarts) reached, stopping")
                    }

                    val errorCode = when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "AUDIO_ERROR"
                        SpeechRecognizer.ERROR_CLIENT -> "CLIENT_ERROR"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSION_DENIED"
                        SpeechRecognizer.ERROR_NETWORK -> "NETWORK_ERROR"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "NETWORK_TIMEOUT"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RECOGNIZER_BUSY"
                        SpeechRecognizer.ERROR_SERVER -> "SERVER_ERROR"
                        else -> "UNKNOWN_ERROR"
                    }

                    val errorMessage = when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                        SpeechRecognizer.ERROR_CLIENT -> "Client error"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                        SpeechRecognizer.ERROR_NETWORK -> "Network error"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
                        SpeechRecognizer.ERROR_SERVER -> "Server error"
                        else -> "Unknown error"
                    }

                    Log.e(TAG, "🛑 STOPPING - Fatal error, not restarting")
                    isListening = false
                    sendEvent(
                        "onSpeechError", mapOf(
                            "code" to errorCode,
                            "message" to errorMessage
                        )
                    )
                    sendEvent("onSpeechEnd", emptyMap())
                }

                override fun onResults(results: Bundle?) {
                    Log.i(TAG, "╔════════════════════════════════════════════════════════════")
                    Log.i(TAG, "║ 📝 onResults - Got final results from Android OS")
                    Log.i(TAG, "║ isManuallyStopped=$isManuallyStopped, isListening=$isListening")
                    Log.i(TAG, "║ 📍 This is triggered by: ANDROID OS (phrase complete)")
                    Log.i(TAG, "╚════════════════════════════════════════════════════════════")
                    
                    // Reset restart counter on successful result
                    restartCount = 0
                    
                    results?.let {
                        val matches =
                            it.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val scores = it.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)

                        if (matches != null && matches.isNotEmpty() && matches[0].isNotEmpty()) {
                            val newText = matches[0]
                            lastConfidence = scores?.get(0)?.toDouble() ?: 0.0
                            
                            // Accumulate text across restarts
                            accumulatedTranscript = if (accumulatedTranscript.isEmpty()) {
                                newText
                            } else {
                                "$accumulatedTranscript $newText"
                            }
                            lastTranscript = accumulatedTranscript
                            
                            Log.d(TAG, "│ New text: '$newText'")
                            Log.d(TAG, "│ Accumulated: '$accumulatedTranscript'")
                            Log.d(TAG, "│ Confidence: $lastConfidence")

                            sendEvent(
                                "onSpeechResult", mapOf(
                                    "transcript" to accumulatedTranscript,
                                    "isFinal" to false, // Mark as non-final since we'll keep listening
                                    "confidence" to lastConfidence
                                )
                            )
                        }
                    }
                    
                    // Restart listening to continue recognition (continuous mode)
                    if (!isManuallyStopped && isListening) {
                        Log.i(TAG, "🔄 Restarting listening for continuous mode")
                        restartListening()
                    }
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    partialResults?.let {
                        val matches =
                            it.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val scores = it.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)

                        if (matches != null && matches.isNotEmpty() && matches[0].isNotEmpty()) {
                            val currentPartial = matches[0]
                            lastConfidence = scores?.get(0)?.toDouble() ?: 0.0
                            
                            // Combine accumulated text with current partial
                            val fullTranscript = if (accumulatedTranscript.isEmpty()) {
                                currentPartial
                            } else {
                                "$accumulatedTranscript $currentPartial"
                            }
                            lastTranscript = fullTranscript
                            
                            Log.d(TAG, "📝 onPartialResults: '$currentPartial' (full: '$fullTranscript')")

                            sendEvent(
                                "onSpeechResult", mapOf(
                                    "transcript" to fullTranscript,
                                    "isFinal" to false,
                                    "confidence" to lastConfidence
                                )
                            )
                        }
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            speechRecognizer?.startListening(intent)
            Log.i(TAG, "✅ Speech recognizer started listening")
            result?.success(null)

        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start recognition: ${e.message}", e)
            isListening = false
            result?.error("START_FAILED", "Failed to start recognition: ${e.message}", null)
        }
    }

    private fun restartListening() {
        val ctx = context ?: return
        
        restartCount++
        
        if (restartCount > maxRestarts) {
            Log.e(TAG, "🛑 Max restarts reached ($restartCount/$maxRestarts), stopping")
            isListening = false
            sendEvent("onSpeechEnd", emptyMap())
            return
        }
        
        // Minimal delay - just enough for Android to process
        val delay = 50L
        Log.d(TAG, "⏳ restartListening - Scheduling restart #$restartCount in ${delay}ms...")
        
        mainHandler.postDelayed({
            if (isListening && !isManuallyStopped) {
                Log.i(TAG, "🔄 restartListening - Restarting speech recognizer now (attempt #$restartCount)")
                startListeningInternal(ctx, null)
            } else {
                Log.d(TAG, "│ Restart cancelled: isListening=$isListening, isManuallyStopped=$isManuallyStopped")
            }
        }, delay)
    }

    private fun stop(result: Result) {
        Log.i(TAG, "╔════════════════════════════════════════════════════════════")
        Log.i(TAG, "║ 🛑 STOP RECORDING - User initiated")
        Log.i(TAG, "║ Accumulated transcript: '$accumulatedTranscript'")
        Log.i(TAG, "║ 📍 This is triggered by: USER (manual stop)")
        Log.i(TAG, "╚════════════════════════════════════════════════════════════")
        
        isManuallyStopped = true
        isListening = false

        mainHandler.post {
            try {
                // Use accumulated transcript for the final result
                val finalTranscript = if (accumulatedTranscript.isNotEmpty()) {
                    accumulatedTranscript
                } else {
                    lastTranscript
                }
                
                if (finalTranscript.isNotEmpty()) {
                    Log.d(TAG, "│ Sending final result to Flutter: '$finalTranscript'")
                    sendEvent(
                        "onSpeechResult", mapOf(
                            "transcript" to finalTranscript,
                            "isFinal" to true,
                            "confidence" to lastConfidence
                        )
                    )
                }

                Log.d(TAG, "│ Stopping and destroying recognizer")
                speechRecognizer?.stopListening()
                speechRecognizer?.destroy()
                speechRecognizer = null

                Log.d(TAG, "│ Sending onSpeechEnd event")
                sendEvent("onSpeechEnd", emptyMap())

                Log.i(TAG, "✅ Recording stopped successfully by USER")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error stopping recognition", e)
                result.error("STOP_FAILED", "Failed to stop recognition: ${e.message}", null)
            }
        }
    }

    private fun requestPermissions(result: Result) {
        val act = activity
        val ctx = context

        if (act == null || ctx == null) {
            result.error("NOT_AVAILABLE", "Activity or context not available", null)
            return
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            ctx,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (hasPermission) {
            result.success(true)
            return
        }

        permissionResult = result
        ActivityCompat.requestPermissions(
            act,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PERMISSION_REQUEST_CODE
        )
    }

    private fun isAvailable(result: Result) {
        val ctx = context ?: run {
            result.success(false)
            return
        }
        val available = SpeechRecognizer.isRecognitionAvailable(ctx)
        result.success(available)
    }

    // MARK: - PluginRegistry.RequestPermissionsResultListener

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionResult?.success(granted)
            permissionResult = null
            return true
        }
        return false
    }

    // MARK: - Private Methods

    private fun sendEvent(type: String, data: Map<String, Any>) {
        val emoji = when (type) {
            "onSpeechResult" -> "📝"
            "onSpeechEnd" -> "🏁"
            "onSpeechError" -> "❌"
            else -> "📨"
        }
        Log.d(TAG, "$emoji sendEvent → Flutter: type=$type, data=$data")
        mainHandler.post {
            val sink = eventSink
            if (sink != null) {
                sink.success(
                    mapOf(
                        "type" to type,
                        "data" to data
                    )
                )
            } else {
                Log.w(TAG, "⚠️ sendEvent: eventSink is null, event not sent!")
            }
        }
    }

    private fun destroySpeechRecognizer() {
        Log.w(TAG, "╔════════════════════════════════════════════════════════════")
        Log.w(TAG, "║ 💀 destroySpeechRecognizer - Plugin detached")
        Log.w(TAG, "║ 📍 This is triggered by: SYSTEM (app lifecycle)")
        Log.w(TAG, "╚════════════════════════════════════════════════════════════")
        isListening = false
        isManuallyStopped = true
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }
}

