import 'package:flutter/foundation.dart';
import 'book_service.dart';
import 'rsvp_service.dart';
import '../models/book.dart';

/// Service for automatically saving reading progress
/// Integrates with RsvpService and BookService
class ReadingProgressService extends ChangeNotifier {
  final BookService _bookService;
  final RsvpService _rsvpService;

  // Configuration
  int _autoSaveInterval = 10; // Save every N words
  bool _autoSaveEnabled = true;

  // State
  Book? _currentBook;
  int _lastSavedWordIndex = 0;
  bool _isDirty = false;
  bool _isDisposed = false;

  ReadingProgressService({
    required BookService bookService,
    required RsvpService rsvpService,
    int autoSaveInterval = 10,
  })  : _bookService = bookService,
        _rsvpService = rsvpService,
        _autoSaveInterval = autoSaveInterval {
    // Listen to RSVP changes
    _rsvpService.addListener(_onRsvpChanged);
  }

  // Getters
  int get autoSaveInterval => _autoSaveInterval;
  bool get autoSaveEnabled => _autoSaveEnabled;
  Book? get currentBook => _currentBook;
  bool get isDirty => _isDirty;
  bool get hasActiveSession => _currentBook != null;

  /// Set auto-save interval (save every N words)
  void setAutoSaveInterval(int interval) {
    if (interval > 0) {
      _autoSaveInterval = interval;
      notifyListeners();
    }
  }

  /// Enable/disable auto-save
  void setAutoSaveEnabled(bool enabled) {
    _autoSaveEnabled = enabled;
    notifyListeners();
  }

  /// Start tracking progress for a book
  Future<void> startTracking(Book book) async {
    _currentBook = book;
    _lastSavedWordIndex = book.currentWordIndex;
    _isDirty = false;

    // Set RSVP to saved position if resuming
    if (book.currentWordIndex > 0 && _rsvpService.hasContent) {
      _rsvpService.jumpToIndex(book.currentWordIndex);
    }

    // Set saved WPM
    if (book.lastWpm > 0) {
      _rsvpService.setWpm(book.lastWpm);
    }

    notifyListeners();
  }

  /// Stop tracking and save final progress
  Future<void> stopTracking() async {
    await saveProgress();
    _currentBook = null;
    _lastSavedWordIndex = 0;
    _isDirty = false;
    notifyListeners();
  }

  /// Manually save current progress
  Future<void> saveProgress() async {
    if (_isDisposed || _currentBook == null) return;

    final currentIndex = _rsvpService.currentIndex;
    final totalWords = _rsvpService.totalWords;
    final wpm = _rsvpService.wordsPerMinute;

    await _bookService.updateRsvpProgress(
      _currentBook!.id,
      currentWordIndex: currentIndex,
      totalWords: totalWords,
      lastWpm: wpm,
    );

    _lastSavedWordIndex = currentIndex;
    _isDirty = false;

    // Update local book reference
    _currentBook = _bookService.getBookById(_currentBook!.id);

    debugPrint('Progress saved: word $currentIndex/$totalWords at $wpm WPM');
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Called when RSVP state changes
  void _onRsvpChanged() {
    if (_isDisposed || _currentBook == null || !_autoSaveEnabled) return;

    final currentIndex = _rsvpService.currentIndex;
    final wordsSinceLastSave = currentIndex - _lastSavedWordIndex;

    // Mark as dirty if we've moved
    if (wordsSinceLastSave != 0) {
      _isDirty = true;
    }

    // Auto-save if we've read enough words
    if (wordsSinceLastSave.abs() >= _autoSaveInterval) {
      saveProgress();
    }

    // Also save when finished
    if (_rsvpService.isFinished && _isDirty) {
      saveProgress();
    }
  }

  /// Get reading statistics for current session
  Map<String, dynamic> getSessionStats() {
    return {
      'book': _currentBook?.title,
      'currentWordIndex': _rsvpService.currentIndex,
      'totalWords': _rsvpService.totalWords,
      'progress': _rsvpService.progress,
      'wpm': _rsvpService.wordsPerMinute,
      'lastSavedIndex': _lastSavedWordIndex,
      'isDirty': _isDirty,
      'autoSaveEnabled': _autoSaveEnabled,
      'autoSaveInterval': _autoSaveInterval,
    };
  }

  /// Load saved progress for a book
  Future<Book?> loadSavedProgress(String bookId) async {
    return _bookService.getBookById(bookId);
  }

  /// Check if book has saved progress
  bool hasSavedProgress(Book book) {
    return book.currentWordIndex > 0;
  }

  /// Reset progress for a book
  Future<void> resetProgress(String bookId) async {
    await _bookService.updateRsvpProgress(
      bookId,
      currentWordIndex: 0,
    );

    if (_currentBook?.id == bookId) {
      _lastSavedWordIndex = 0;
      _isDirty = false;
      _rsvpService.restart();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _rsvpService.removeListener(_onRsvpChanged);
    super.dispose();
  }
}
