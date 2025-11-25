package com.dbkable.speech_to_text

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
    private var lastConfidence: Double = 0.0
    private var isManuallyStopped: Boolean = false

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
            "com.dbkable.speech_to_text/methods"
        )
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "com.dbkable.speech_to_text/events"
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
        val ctx = context ?: run {
            result.error("NOT_AVAILABLE", "Context not available", null)
            return
        }

        lastTranscript = ""
        lastConfidence = 0.0
        isManuallyStopped = false

        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(ctx)) {
            result.error("NOT_AVAILABLE", "Speech recognition not available", null)
            return
        }

        mainHandler.post {
            try {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(ctx)

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                    )
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    putExtra(
                        RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                        2000L
                    )
                    putExtra(
                        RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                        2000L
                    )
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 10000L)
                }

                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {}
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        if (!isManuallyStopped) {
                            sendEvent("onSpeechEnd", emptyMap())
                        }
                    }

                    override fun onError(error: Int) {
                        if (!isManuallyStopped) {
                            if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                                error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
                            ) {
                                return
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

                            sendEvent(
                                "onSpeechError", mapOf(
                                    "code" to errorCode,
                                    "message" to errorMessage
                                )
                            )
                        }
                    }

                    override fun onResults(results: Bundle?) {
                        results?.let {
                            val matches =
                                it.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val scores = it.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)

                            if (matches != null && matches.isNotEmpty()) {
                                lastTranscript = matches[0]
                                lastConfidence = scores?.get(0)?.toDouble() ?: 0.0

                                sendEvent(
                                    "onSpeechResult", mapOf(
                                        "transcript" to lastTranscript,
                                        "isFinal" to true,
                                        "confidence" to lastConfidence
                                    )
                                )
                            }
                        }
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        partialResults?.let {
                            val matches =
                                it.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val scores = it.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)

                            if (matches != null && matches.isNotEmpty()) {
                                lastTranscript = matches[0]
                                lastConfidence = scores?.get(0)?.toDouble() ?: 0.0

                                sendEvent(
                                    "onSpeechResult", mapOf(
                                        "transcript" to lastTranscript,
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
                result.success(null)

            } catch (e: Exception) {
                result.error("START_FAILED", "Failed to start recognition: ${e.message}", null)
            }
        }
    }

    private fun stop(result: Result) {
        Log.d(TAG, "stop: called, lastTranscript='$lastTranscript'")
        isManuallyStopped = true

        mainHandler.post {
            try {
                if (lastTranscript.isNotEmpty()) {
                    Log.d(TAG, "stop: sending final result")
                    sendEvent(
                        "onSpeechResult", mapOf(
                            "transcript" to lastTranscript,
                            "isFinal" to true,
                            "confidence" to lastConfidence
                        )
                    )
                }

                Log.d(TAG, "stop: stopping and destroying recognizer")
                speechRecognizer?.stopListening()
                speechRecognizer?.destroy()
                speechRecognizer = null

                Log.d(TAG, "stop: sending onSpeechEnd event")
                sendEvent("onSpeechEnd", emptyMap())

                Log.d(TAG, "stop: success")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "stop: error", e)
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
        Log.d(TAG, "sendEvent: type=$type, data=$data, eventSink=${eventSink != null}")
        mainHandler.post {
            val sink = eventSink
            if (sink != null) {
                Log.d(TAG, "sendEvent: sending to eventSink")
                sink.success(
                    mapOf(
                        "type" to type,
                        "data" to data
                    )
                )
            } else {
                Log.w(TAG, "sendEvent: eventSink is null, event not sent!")
            }
        }
    }

    private fun destroySpeechRecognizer() {
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }
}

