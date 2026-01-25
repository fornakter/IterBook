import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

/// Service for managing books in the application
class BookService extends ChangeNotifier {
  static const String _booksKey = 'books_list';

  List<Book> _books = [];
  bool _isLoaded = false;

  List<Book> get books => List.unmodifiable(_books);
  bool get isLoaded => _isLoaded;

  /// Initialize service and load books from storage
  Future<void> initialize() async {
    if (_isLoaded) return;
    await _loadBooks();
    _isLoaded = true;
  }

  /// Load books from SharedPreferences
  Future<void> _loadBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final booksJson = prefs.getString(_booksKey);

      if (booksJson != null && booksJson.isNotEmpty) {
        final List<dynamic> booksList = jsonDecode(booksJson) as List<dynamic>;
        _books = booksList
            .map((json) => Book.fromJson(json as Map<String, dynamic>))
            .toList();

        // Sort by last read date (most recent first), then by date added
        _books.sort((a, b) {
          if (a.lastRead != null && b.lastRead != null) {
            return b.lastRead!.compareTo(a.lastRead!);
          } else if (a.lastRead != null) {
            return -1;
          } else if (b.lastRead != null) {
            return 1;
          }
          return b.dateAdded.compareTo(a.dateAdded);
        });

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading books: $e');
      _books = [];
    }
  }

  /// Save books to SharedPreferences
  Future<void> _saveBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final booksJson = jsonEncode(_books.map((book) => book.toJson()).toList());
      await prefs.setString(_booksKey, booksJson);
    } catch (e) {
      debugPrint('Error saving books: $e');
    }
  }

  /// Add a new book
  Future<void> addBook(Book book) async {
    // Check if book with same file path already exists
    final existingIndex = _books.indexWhere((b) => b.filePath == book.filePath);

    if (existingIndex != -1) {
      // Update existing book
      _books[existingIndex] = book;
    } else {
      // Add new book
      _books.insert(0, book); // Add to beginning of list
    }

    await _saveBooks();
    notifyListeners();
  }

  /// Remove a book by ID
  Future<void> removeBook(String bookId) async {
    _books.removeWhere((book) => book.id == bookId);
    await _saveBooks();
    notifyListeners();
  }

  /// Update an existing book
  Future<void> updateBook(Book updatedBook) async {
    final index = _books.indexWhere((book) => book.id == updatedBook.id);

    if (index != -1) {
      _books[index] = updatedBook;

      // Re-sort after update
      _books.sort((a, b) {
        if (a.lastRead != null && b.lastRead != null) {
          return b.lastRead!.compareTo(a.lastRead!);
        } else if (a.lastRead != null) {
          return -1;
        } else if (b.lastRead != null) {
          return 1;
        }
        return b.dateAdded.compareTo(a.dateAdded);
      });

      await _saveBooks();
      notifyListeners();
    }
  }

  /// Get book by ID
  Book? getBookById(String bookId) {
    try {
      return _books.firstWhere((book) => book.id == bookId);
    } catch (e) {
      return null;
    }
  }

  /// Update book reading progress (page-based)
  Future<void> updateProgress(String bookId, int currentPage) async {
    final book = getBookById(bookId);
    if (book != null) {
      final updatedBook = book.copyWith(
        currentPage: currentPage,
        lastRead: DateTime.now(),
      );
      await updateBook(updatedBook);
    }
  }

  /// Update RSVP reading progress (word-based)
  Future<void> updateRsvpProgress(
    String bookId, {
    required int currentWordIndex,
    int? totalWords,
    int? lastWpm,
  }) async {
    final book = getBookById(bookId);
    if (book != null) {
      final updatedBook = book.copyWith(
        currentWordIndex: currentWordIndex,
        totalWords: totalWords ?? book.totalWords,
        lastWpm: lastWpm ?? book.lastWpm,
        lastRead: DateTime.now(),
      );
      await updateBook(updatedBook);
    }
  }

  /// Initialize RSVP session for a book
  Future<void> initializeRsvpSession(
    String bookId, {
    required int totalWords,
    int? wpm,
  }) async {
    final book = getBookById(bookId);
    if (book != null) {
      final updatedBook = book.copyWith(
        totalWords: totalWords,
        lastWpm: wpm ?? book.lastWpm,
      );
      await updateBook(updatedBook);
    }
  }

  /// Clear all books (for testing/debugging)
  Future<void> clearAllBooks() async {
    _books.clear();
    await _saveBooks();
    notifyListeners();
  }

  /// Get statistics
  int get totalBooks => _books.length;
  int get booksInProgress => _books.where((b) => b.isStarted && !b.isCompleted).length;
  int get completedBooks => _books.where((b) => b.isCompleted).length;
  int get notStartedBooks => _books.where((b) => !b.isStarted).length;
}
