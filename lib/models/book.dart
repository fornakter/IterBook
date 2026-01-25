import 'dart:convert';

/// Model representing a book/PDF document
class Book {
  final String id;
  final String title;
  final String? author;
  final String filePath;
  final int currentPage;
  final int totalPages;
  final DateTime dateAdded;
  final DateTime? lastRead;

  // RSVP reading progress
  final int currentWordIndex;
  final int totalWords;
  final int lastWpm;

  Book({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    this.currentPage = 0,
    this.totalPages = 0,
    required this.dateAdded,
    this.lastRead,
    this.currentWordIndex = 0,
    this.totalWords = 0,
    this.lastWpm = 300,
  });

  /// Page progress as a value between 0.0 and 1.0
  double get progress {
    if (totalPages == 0) return 0.0;
    return currentPage / totalPages;
  }

  /// RSVP word progress as a value between 0.0 and 1.0
  double get rsvpProgress {
    if (totalWords == 0) return 0.0;
    return currentWordIndex / totalWords;
  }

  /// Check if book has been started (read at least one page or word)
  bool get isStarted => currentPage > 0 || currentWordIndex > 0;

  /// Check if book is completed (reached last page)
  bool get isCompleted => currentPage >= totalPages && totalPages > 0;

  /// Check if RSVP reading is completed
  bool get isRsvpCompleted => currentWordIndex >= totalWords && totalWords > 0;

  /// Create a copy with updated fields
  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    int? currentPage,
    int? totalPages,
    DateTime? dateAdded,
    DateTime? lastRead,
    int? currentWordIndex,
    int? totalWords,
    int? lastWpm,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      dateAdded: dateAdded ?? this.dateAdded,
      lastRead: lastRead ?? this.lastRead,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      totalWords: totalWords ?? this.totalWords,
      lastWpm: lastWpm ?? this.lastWpm,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'dateAdded': dateAdded.toIso8601String(),
      'lastRead': lastRead?.toIso8601String(),
      'currentWordIndex': currentWordIndex,
      'totalWords': totalWords,
      'lastWpm': lastWpm,
    };
  }

  /// Create from JSON
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      filePath: json['filePath'] as String,
      currentPage: json['currentPage'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
      lastRead: json['lastRead'] != null
          ? DateTime.parse(json['lastRead'] as String)
          : null,
      currentWordIndex: json['currentWordIndex'] as int? ?? 0,
      totalWords: json['totalWords'] as int? ?? 0,
      lastWpm: json['lastWpm'] as int? ?? 300,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory Book.fromJsonString(String jsonString) {
    return Book.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'Book(id: $id, title: $title, author: $author, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
