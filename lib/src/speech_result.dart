/// Represents the result of speech recognition.
class SpeechResult {
  /// The recognized text transcript.
  final String transcript;

  /// Confidence score from 0.0 to 1.0.
  final double confidence;

  /// Whether this is the final result or a partial/interim result.
  final bool isFinal;

  const SpeechResult({
    required this.transcript,
    required this.confidence,
    required this.isFinal,
  });

  factory SpeechResult.fromMap(Map<dynamic, dynamic> map) {
    return SpeechResult(
      transcript: map['transcript'] as String? ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      isFinal: map['isFinal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transcript': transcript,
      'confidence': confidence,
      'isFinal': isFinal,
    };
  }

  @override
  String toString() {
    return 'SpeechResult(transcript: $transcript, confidence: $confidence, isFinal: $isFinal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpeechResult &&
        other.transcript == transcript &&
        other.confidence == confidence &&
        other.isFinal == isFinal;
  }

  @override
  int get hashCode => Object.hash(transcript, confidence, isFinal);
}
