import 'dart:async';
import 'package:flutter/foundation.dart';

/// State of RSVP playback
enum RsvpState {
  idle,      // No content loaded
  ready,     // Content loaded, not playing
  playing,   // Currently playing
  paused,    // Paused
  finished,  // Reached end of content
}

/// RSVP Engine Service for rapid serial visual presentation
/// Manages word-by-word display with configurable speed
class RsvpService extends ChangeNotifier {
  // Content
  List<String> _words = [];
  int _currentIndex = 0;

  // Playback state
  RsvpState _state = RsvpState.idle;
  Timer? _timer;

  // Settings
  int _wordsPerMinute = 300; // Default WPM
  static const int minWpm = 100;
  static const int maxWpm = 1000;
  static const int wpmStep = 50;
  static const double sentenceEndPauseMultiplier = 2.0;

  // Getters
  RsvpState get state => _state;
  bool get isPlaying => _state == RsvpState.playing;
  bool get isPaused => _state == RsvpState.paused;
  bool get isReady => _state == RsvpState.ready;
  bool get isFinished => _state == RsvpState.finished;
  bool get isIdle => _state == RsvpState.idle;
  bool get hasContent => _words.isNotEmpty;

  int get currentIndex => _currentIndex;
  int get totalWords => _words.length;
  String get currentWord => _words.isNotEmpty && _currentIndex < _words.length
      ? _words[_currentIndex]
      : '';

  int get wordsPerMinute => _wordsPerMinute;
  int get millisecondsPerWord => (60000 / _wordsPerMinute).round();

  /// Progress as value 0.0 - 1.0
  double get progress {
    if (_words.isEmpty) return 0.0;
    return _currentIndex / _words.length;
  }

  /// Remaining words count
  int get remainingWords => _words.length - _currentIndex;

  /// Estimated remaining time in seconds
  int get remainingTimeSeconds {
    if (_wordsPerMinute == 0) return 0;
    return (remainingWords * 60 / _wordsPerMinute).round();
  }

  /// Formatted remaining time (mm:ss)
  String get remainingTimeFormatted {
    final seconds = remainingTimeSeconds;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CONTENT MANAGEMENT
  // ============================================================

  /// Load words for RSVP display
  void loadWords(List<String> words) {
    stop();
    _words = List.from(words);
    _currentIndex = 0;
    _state = _words.isEmpty ? RsvpState.idle : RsvpState.ready;
    notifyListeners();
  }

  /// Load text and split into words
  void loadText(String text, {bool toLowerCase = false, bool removePunctuation = false}) {
    String processedText = text;

    if (removePunctuation) {
      processedText = processedText.replaceAll(
        RegExp(r'[^\w\s\u00C0-\u024F]'),
        ' ',
      );
    }

    if (toLowerCase) {
      processedText = processedText.toLowerCase();
    }

    final words = processedText
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    loadWords(words);
  }

  /// Clear all content
  void clear() {
    stop();
    _words = [];
    _currentIndex = 0;
    _state = RsvpState.idle;
    notifyListeners();
  }

  // ============================================================
  // PLAYBACK CONTROL
  // ============================================================

  /// Start or resume playback
  void play() {
    if (_words.isEmpty) return;
    if (_state == RsvpState.finished) {
      _currentIndex = 0; // Restart from beginning
    }

    _state = RsvpState.playing;
    _startTimer();
    notifyListeners();
  }

  /// Pause playback
  void pause() {
    if (_state != RsvpState.playing) return;

    _stopTimer();
    _state = RsvpState.paused;
    notifyListeners();
  }

  /// Toggle play/pause
  void togglePlayPause() {
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Stop playback and reset to beginning
  void stop() {
    _stopTimer();
    _currentIndex = 0;
    _state = _words.isEmpty ? RsvpState.idle : RsvpState.ready;
    notifyListeners();
  }

  /// Restart from beginning
  void restart() {
    _stopTimer();
    _currentIndex = 0;
    _state = RsvpState.ready;
    notifyListeners();
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  /// Move to next word
  void nextWord() {
    if (_words.isEmpty) return;

    if (_currentIndex < _words.length - 1) {
      _currentIndex++;
      notifyListeners();
    } else {
      _onFinished();
    }
  }

  /// Move to previous word
  void previousWord() {
    if (_words.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
      if (_state == RsvpState.finished) {
        _state = RsvpState.paused;
      }
      notifyListeners();
    }
  }

  /// Skip forward by N words
  void skipForward(int count) {
    if (_words.isEmpty) return;

    _currentIndex = (_currentIndex + count).clamp(0, _words.length - 1);
    if (_currentIndex >= _words.length - 1) {
      _onFinished();
    } else {
      notifyListeners();
    }
  }

  /// Skip backward by N words
  void skipBackward(int count) {
    if (_words.isEmpty) return;

    _currentIndex = (_currentIndex - count).clamp(0, _words.length - 1);
    if (_state == RsvpState.finished) {
      _state = RsvpState.paused;
    }
    notifyListeners();
  }

  /// Jump to specific word index
  void jumpToIndex(int index) {
    if (_words.isEmpty) return;

    _currentIndex = index.clamp(0, _words.length - 1);
    if (_state == RsvpState.finished && _currentIndex < _words.length - 1) {
      _state = RsvpState.paused;
    }
    notifyListeners();
  }

  /// Jump to specific progress (0.0 - 1.0)
  void jumpToProgress(double progress) {
    if (_words.isEmpty) return;

    final index = (progress * _words.length).floor();
    jumpToIndex(index);
  }

  // ============================================================
  // SPEED CONTROL
  // ============================================================

  /// Set words per minute
  void setWpm(int wpm) {
    _wordsPerMinute = wpm.clamp(minWpm, maxWpm);

    // Restart timer with new speed if playing
    if (isPlaying) {
      _stopTimer();
      _startTimer();
    }

    notifyListeners();
  }

  /// Increase WPM by step
  void increaseSpeed() {
    setWpm(_wordsPerMinute + wpmStep);
  }

  /// Decrease WPM by step
  void decreaseSpeed() {
    setWpm(_wordsPerMinute - wpmStep);
  }

  // ============================================================
  // TIMER MANAGEMENT
  // ============================================================

  /// Check if word ends with sentence-ending punctuation
  bool _isSentenceEnd(String word) {
    if (word.isEmpty) return false;
    final lastChar = word[word.length - 1];
    return lastChar == '.' || lastChar == '?' || lastChar == '!';
  }

  /// Calculate display duration for current word
  int _getWordDisplayMilliseconds() {
    if (_currentIndex >= _words.length) return millisecondsPerWord;

    final word = _words[_currentIndex];
    if (_isSentenceEnd(word)) {
      return (millisecondsPerWord * sentenceEndPauseMultiplier).round();
    }
    return millisecondsPerWord;
  }

  void _startTimer() {
    _stopTimer();
    _scheduleNextWord();
  }

  void _scheduleNextWord() {
    final duration = Duration(milliseconds: _getWordDisplayMilliseconds());
    _timer = Timer(duration, () {
      _onTimerTick();
      if (_state == RsvpState.playing) {
        _scheduleNextWord();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTimerTick() {
    if (_currentIndex < _words.length - 1) {
      _currentIndex++;
      notifyListeners();
    } else {
      _onFinished();
    }
  }

  void _onFinished() {
    _stopTimer();
    _state = RsvpState.finished;
    notifyListeners();
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  /// Get reading statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalWords': totalWords,
      'currentIndex': currentIndex,
      'remainingWords': remainingWords,
      'progress': progress,
      'wpm': wordsPerMinute,
      'remainingTimeSeconds': remainingTimeSeconds,
      'remainingTimeFormatted': remainingTimeFormatted,
      'state': state.name,
    };
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
