import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text_native/speech_to_text_native.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech to Text Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const SpeechToTextDemo(),
    );
  }
}

class SpeechToTextDemo extends StatefulWidget {
  const SpeechToTextDemo({super.key});

  @override
  State<SpeechToTextDemo> createState() => _SpeechToTextDemoState();
}

class _SpeechToTextDemoState extends State<SpeechToTextDemo>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();

  String _transcript = '';
  double _confidence = 0.0;
  bool _isListening = false;
  bool _isAvailable = false;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<SpeechResult>? _resultSubscription;
  StreamSubscription<SpeechError>? _errorSubscription;
  StreamSubscription<void>? _endSubscription;

  String? _selectedLanguage; // null = use device language
  final List<Map<String, String?>> _languages = [
    {'code': null, 'name': 'Auto (Device)'},
    {'code': 'en-US', 'name': 'English (US)'},
    {'code': 'en-GB', 'name': 'English (UK)'},
    {'code': 'fr-FR', 'name': 'Français'},
    {'code': 'es-ES', 'name': 'Español'},
    {'code': 'de-DE', 'name': 'Deutsch'},
    {'code': 'it-IT', 'name': 'Italiano'},
    {'code': 'pt-BR', 'name': 'Português (BR)'},
    {'code': 'ja-JP', 'name': '日本語'},
    {'code': 'zh-CN', 'name': '中文'},
    {'code': 'ko-KR', 'name': '한국어'},
  ];

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _initSpeechToText();
  }

  void _initAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseController.forward();
      }
    });
  }

  Future<void> _initSpeechToText() async {
    // Set up listeners
    _resultSubscription = _speechToText.onResult.listen((result) {
      debugPrint('🎤 Result: ${result.transcript} (final: ${result.isFinal}, confidence: ${result.confidence})');
      setState(() {
        _transcript = result.transcript;
        _confidence = result.confidence;
        if (result.isFinal) {
          _isListening = false;
          _pulseController.stop();
        }
      });
    });

    _errorSubscription = _speechToText.onError.listen((error) {
      debugPrint('❌ Error: ${error.errorCode} - ${error.message}');
      setState(() {
        _errorMessage = error.message;
        _isListening = false;
        _pulseController.stop();
      });
    });

    _endSubscription = _speechToText.onEnd.listen((_) {
      debugPrint('🛑 Speech ended');
      setState(() {
        _isListening = false;
        _pulseController.stop();
      });
    });

    // Check availability
    final available = await _speechToText.isAvailable();
    debugPrint('📱 Speech recognition available: $available');
    setState(() {
      _isAvailable = available;
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    debugPrint('▶️ Starting listening with language: ${_selectedLanguage ?? "device default"}');
    setState(() {
      _errorMessage = null;
      _transcript = '';
      _confidence = 0.0;
    });

    try {
      final hasPermission = await _speechToText.requestPermissions();
      debugPrint('🔐 Permission granted: $hasPermission');
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Permission denied';
        });
        return;
      }

      await _speechToText.start(language: _selectedLanguage);
      debugPrint('✅ Started successfully');
      setState(() {
        _isListening = true;
      });
      _pulseController.forward();
    } on SpeechError catch (e) {
      debugPrint('❌ Start error: ${e.message}');
      setState(() {
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _stopListening() async {
    debugPrint('⏹️ Stopping listening...');
    try {
      await _speechToText.stop();
      debugPrint('✅ Stopped successfully');
    } on SpeechError catch (e) {
      debugPrint('❌ Stop error: ${e.message}');
      setState(() {
        _errorMessage = e.message;
      });
    }
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _errorSubscription?.cancel();
    _endSubscription?.cancel();
    _pulseController.dispose();
    _speechToText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildContent()),
              _buildMicButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Color(0xFF6366F1),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Speech to Text',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Native Recognition',
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
              ],
            ),
          ),
          _buildLanguageSelector(),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final displayLanguage = _selectedLanguage ?? 'Auto';
    return PopupMenuButton<String?>(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLanguage,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
      onSelected: (String? code) {
        setState(() {
          _selectedLanguage = code;
        });
      },
      itemBuilder: (context) => _languages.map((lang) {
        return PopupMenuItem<String?>(value: lang['code'], child: Text(lang['name']!));
      }).toList(),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 24),
          Expanded(child: _buildTranscriptCard()),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildStatusItem(
            icon: _isAvailable ? Icons.check_circle : Icons.cancel,
            label: 'Available',
            value: _isAvailable ? 'Yes' : 'No',
            color: _isAvailable ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 40, color: Colors.white12),
          const SizedBox(width: 16),
          _buildStatusItem(
            icon: _isListening ? Icons.hearing : Icons.hearing_disabled,
            label: 'Status',
            value: _isListening ? 'Listening' : 'Idle',
            color: _isListening ? const Color(0xFF6366F1) : Colors.white54,
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 40, color: Colors.white12),
          const SizedBox(width: 16),
          _buildStatusItem(
            icon: Icons.speed,
            label: 'Confidence',
            value: '${(_confidence * 100).toStringAsFixed(0)}%',
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Transcript',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: _errorMessage != null
                  ? _buildErrorMessage()
                  : _buildTranscriptText(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptText() {
    if (_transcript.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isListening ? Icons.graphic_eq : Icons.mic_none,
              size: 48,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              _isListening
                  ? 'Listening...\nSpeak now'
                  : 'Tap the microphone\nto start',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return Text(
      _transcript,
      style: const TextStyle(fontSize: 20, color: Colors.white, height: 1.6),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isListening ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: _isAvailable ? _toggleListening : null,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isListening
                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                      : _isAvailable
                      ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                      : [Colors.grey.shade600, Colors.grey.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isListening
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6366F1))
                            .withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: _isListening ? 5 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        );
      },
    );
  }
}
