import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_speech_to_text/flutter_speech_to_text.dart';

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
      debugPrint(
          '🎤 Result: ${result.transcript} (final: ${result.isFinal}, confidence: ${result.confidence})');
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
    debugPrint(
        '▶️ Starting listening with language: ${_selectedLanguage ?? "device default"}');
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

  void _onLanguageSelected(String? code) {
    setState(() {
      _selectedLanguage = code;
    });
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
              _Header(
                selectedLanguage: _selectedLanguage,
                languages: _languages,
                onLanguageSelected: _onLanguageSelected,
              ),
              Expanded(
                child: _Content(
                  isAvailable: _isAvailable,
                  isListening: _isListening,
                  confidence: _confidence,
                  transcript: _transcript,
                  errorMessage: _errorMessage,
                ),
              ),
              _MicButton(
                isListening: _isListening,
                isAvailable: _isAvailable,
                pulseAnimation: _pulseAnimation,
                onTap: _toggleListening,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedLanguage,
    required this.languages,
    required this.onLanguageSelected,
  });

  final String? selectedLanguage;
  final List<Map<String, String?>> languages;
  final ValueChanged<String?> onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
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
          _LanguageSelector(
            selectedLanguage: selectedLanguage,
            languages: languages,
            onSelected: onLanguageSelected,
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.selectedLanguage,
    required this.languages,
    required this.onSelected,
  });

  final String? selectedLanguage;
  final List<Map<String, String?>> languages;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final displayLanguage = selectedLanguage ?? 'Auto';
    return PopupMenuButton<String?>(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
      onSelected: onSelected,
      itemBuilder: (context) => languages.map((lang) {
        return PopupMenuItem<String?>(
          value: lang['code'],
          child: Text(lang['name']!),
        );
      }).toList(),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.isAvailable,
    required this.isListening,
    required this.confidence,
    required this.transcript,
    required this.errorMessage,
  });

  final bool isAvailable;
  final bool isListening;
  final double confidence;
  final String transcript;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _StatusCard(
            isAvailable: isAvailable,
            isListening: isListening,
            confidence: confidence,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _TranscriptCard(
              transcript: transcript,
              errorMessage: errorMessage,
              isListening: isListening,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.isAvailable,
    required this.isListening,
    required this.confidence,
  });

  final bool isAvailable;
  final bool isListening;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _StatusItem(
            icon: isAvailable ? Icons.check_circle : Icons.cancel,
            label: 'Available',
            value: isAvailable ? 'Yes' : 'No',
            color: isAvailable ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 40, color: Colors.white12),
          const SizedBox(width: 16),
          _StatusItem(
            icon: isListening ? Icons.hearing : Icons.hearing_disabled,
            label: 'Status',
            value: isListening ? 'Listening' : 'Idle',
            color: isListening ? const Color(0xFF6366F1) : Colors.white54,
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 40, color: Colors.white12),
          const SizedBox(width: 16),
          _StatusItem(
            icon: Icons.speed,
            label: 'Confidence',
            value: '${(confidence * 100).toStringAsFixed(0)}%',
            color: Colors.amber,
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({
    required this.transcript,
    required this.errorMessage,
    required this.isListening,
  });

  final String transcript;
  final String? errorMessage;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_fields, color: Colors.white54, size: 20),
              SizedBox(width: 8),
              Text(
                'Transcript',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
              Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: errorMessage != null
                  ? _ErrorMessage(message: errorMessage!)
                  : _TranscriptText(
                      transcript: transcript,
                      isListening: isListening,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptText extends StatelessWidget {
  const _TranscriptText({
    required this.transcript,
    required this.isListening,
  });

  final String transcript;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    if (transcript.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isListening ? Icons.graphic_eq : Icons.mic_none,
              size: 48,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              isListening
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
      transcript,
      style: const TextStyle(fontSize: 20, color: Colors.white, height: 1.6),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isListening,
    required this.isAvailable,
    required this.pulseAnimation,
    required this.onTap,
  });

  final bool isListening;
  final bool isAvailable;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isListening ? pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: isAvailable ? onTap : null,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isListening
                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                      : isAvailable
                          ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                          : [Colors.grey.shade600, Colors.grey.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isListening
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6366F1))
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: isListening ? 5 : 0,
                  ),
                ],
              ),
              child: Icon(
                isListening ? Icons.stop_rounded : Icons.mic_rounded,
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
