import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/reading_preferences_service.dart';
import '../services/file_picker_service.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';

/// Main menu screen - displays list of books and settings button
class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.bookService,
    required this.preferencesService,
  });

  final BookService bookService;
  final ReadingPreferencesService preferencesService;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? _loadingBookId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.bookService,
      builder: (context, child) {
        final l10n = AppLocalizations.of(context)!;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(l10n.appTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: l10n.settings,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        preferencesService: widget.preferencesService,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: _buildBody(context, l10n),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _handleAddBook(context),
            tooltip: l10n.addBook,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    // Initialize bookService if not loaded
    if (!widget.bookService.isLoaded) {
      widget.bookService.initialize();
      return const Center(child: CircularProgressIndicator());
    }

    final books = widget.bookService.books;

    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noBooksYet,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tapToAddBook,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: books.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookCard(
          context,
          book: book,
        );
      },
    );
  }

  /// Open book with loading indicator
  void _openBook(BuildContext context, Book book) {
    final navigator = Navigator.of(context);
    setState(() => _loadingBookId = book.id);

    // Wait for frame to render, then navigate
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => ReadingScreen(
            book: book,
            bookService: widget.bookService,
            preferencesService: widget.preferencesService,
          ),
        ),
      );
      if (mounted) {
        setState(() => _loadingBookId = null);
      }
    });
  }

  /// Handle adding a new book
  Future<void> _handleAddBook(BuildContext context) async {
    final filePickerService = FilePickerService();

    try {
      final book = await filePickerService.pickPdfFile();

      if (book != null) {
        await widget.bookService.addBook(book);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added: ${book.title}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding book: $e')),
        );
      }
    }
  }

  Widget _buildBookCard(
    BuildContext context, {
    required Book book,
  }) {
    final isLoading = _loadingBookId == book.id;

    return Card(
      elevation: 2,
      child: Stack(
        children: [
          InkWell(
            onTap: isLoading ? null : () => _openBook(context, book),
            onLongPress: () {
              _showBookOptions(context, book);
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (book.isRsvpCompleted)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 24,
                        ),
                    ],
                  ),
                  if (book.author != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.author!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: book.rsvpProgress,
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(book.rsvpProgress * 100).toInt()}% completed',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (book.totalWords > 0)
                        Text(
                          '${book.currentWordIndex}/${book.totalWords} words',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Loading overlay
          if (isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Show book options dialog
  void _showBookOptions(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Book Info'),
              subtitle: Text(book.filePath),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove Book', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveBook(context, book);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Confirm book removal
  void _confirmRemoveBook(BuildContext context, Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Book'),
        content: Text('Are you sure you want to remove "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.bookService.removeBook(book.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed: ${book.title}')),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
