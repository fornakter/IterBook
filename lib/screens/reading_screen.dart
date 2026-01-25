import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/reading_preferences_service.dart';
import '../services/reading_session_service.dart';
import '../services/rsvp_service.dart';

/// Reading screen - main RSVP view with word display
/// Uses ReadingSessionService for automatic progress saving
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.book,
    required this.bookService,
    required this.preferencesService,
  });

  final Book book;
  final BookService bookService;
  final ReadingPreferencesService preferencesService;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late final ReadingSessionService _sessionService;
  bool _showResumedMessage = false;
  bool _wakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    _sessionService = ReadingSessionService(
      bookService: widget.bookService,
      autoSaveInterval: 10, // Save every 10 words
    );
    _startSession();
    // Listen to RSVP state changes for wakelock control
    _sessionService.rsvp.addListener(_onRsvpStateChanged);
  }

  /// Handle wakelock based on playback state
  void _onRsvpStateChanged() {
    final isPlaying = _sessionService.rsvp.isPlaying;
    if (isPlaying && !_wakelockEnabled) {
      WakelockPlus.enable();
      _wakelockEnabled = true;
    } else if (!isPlaying && _wakelockEnabled) {
      WakelockPlus.disable();
      _wakelockEnabled = false;
    }
  }

  Future<void> _startSession() async {
    final result = await _sessionService.startSession(widget.book);

    if (result.success && result.resumed) {
      setState(() {
        _showResumedMessage = true;
      });
      // Hide message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showResumedMessage = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // Disable wakelock when leaving
    if (_wakelockEnabled) {
      WakelockPlus.disable();
    }
    // Remove listener
    _sessionService.rsvp.removeListener(_onRsvpStateChanged);
    // Note: Don't call endSession() here - it causes race condition
    // Progress is already saved by back button's saveProgress() call
    _sessionService.dispose();
    super.dispose();
  }

  RsvpService get _rsvpService => _sessionService.rsvp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          widget.book.title,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            _rsvpService.pause();
            await _sessionService.saveProgress();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          // Manual save button
          if (_sessionService.canSaveProgress)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save progress',
              onPressed: () async {
                await _sessionService.saveProgress();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Progress saved'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          // Reset progress button
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                _showResetConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Reset progress'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text('Are you sure you want to reset your reading progress for this book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sessionService.resetProgress();
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Progress reset')),
                );
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: _sessionService,
      builder: (context, child) {
        if (_sessionService.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading book content...'),
              ],
            ),
          );
        }

        if (_sessionService.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sessionService.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _startSession,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListenableBuilder(
          listenable: _rsvpService,
          builder: (context, child) {
            return Stack(
              children: [
                Column(
                  children: [
                    // Main word display area - centered
                    Expanded(
                      flex: 3,
                      child: _buildWordDisplay(),
                    ),

                    // Progress indicator
                    _buildProgressBar(),

                    // Control panel
                    Expanded(
                      flex: 1,
                      child: _buildControlPanel(),
                    ),
                  ],
                ),
                // Resumed message overlay
                if (_showResumedMessage)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.green[700],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Resumed from word ${widget.book.currentWordIndex + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWordDisplay() {
    final prefs = widget.preferencesService;

    return GestureDetector(
      onTap: () => _rsvpService.togglePlayPause(),
      child: ListenableBuilder(
        listenable: prefs,
        builder: (context, child) {
          return Container(
            color: prefs.backgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _rsvpService.currentWord.isNotEmpty
                          ? _rsvpService.currentWord
                          : 'Tap to start',
                      style: TextStyle(
                        fontSize: prefs.fontSize,
                        fontWeight: FontWeight.bold,
                        color: prefs.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_rsvpService.isFinished)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'Finished! Tap to restart',
                          style: TextStyle(
                            fontSize: 16,
                            color: prefs.textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _sessionService.progress;
    final isDirty = progress?.isDirty ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        children: [
          Text(
            '${_rsvpService.currentIndex + 1}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LinearProgressIndicator(
                value: _rsvpService.progress,
                backgroundColor: Colors.grey[300],
              ),
            ),
          ),
          Text(
            '${_rsvpService.totalWords}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          // Auto-save indicator
          if (isDirty)
            Icon(Icons.cloud_upload, size: 14, color: Colors.grey[500])
          else
            Icon(Icons.cloud_done, size: 14, color: Colors.green[600]),
          const SizedBox(width: 8),
          Icon(Icons.timer, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            _rsvpService.remainingTimeFormatted,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Navigation and Play/Pause buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Skip backward
              IconButton(
                icon: const Icon(Icons.replay_10, size: 32),
                onPressed: () => _rsvpService.skipBackward(10),
                tooltip: 'Back 10 words',
              ),
              // Previous word
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                onPressed: _rsvpService.previousWord,
                tooltip: 'Previous word',
              ),
              // Play/Pause button
              IconButton(
                icon: Icon(
                  _rsvpService.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 64,
                ),
                onPressed: () => _rsvpService.togglePlayPause(),
                color: Theme.of(context).colorScheme.primary,
              ),
              // Next word
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed: _rsvpService.nextWord,
                tooltip: 'Next word',
              ),
              // Skip forward
              IconButton(
                icon: const Icon(Icons.forward_10, size: 32),
                onPressed: () => _rsvpService.skipForward(10),
                tooltip: 'Forward 10 words',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Speed slider
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _rsvpService.decreaseSpeed,
                tooltip: 'Decrease speed',
              ),
              Expanded(
                child: Slider(
                  value: _rsvpService.wordsPerMinute.toDouble(),
                  min: RsvpService.minWpm.toDouble(),
                  max: RsvpService.maxWpm.toDouble(),
                  divisions: (RsvpService.maxWpm - RsvpService.minWpm) ~/ RsvpService.wpmStep,
                  label: '${_rsvpService.wordsPerMinute} WPM',
                  onChanged: (value) => _rsvpService.setWpm(value.toInt()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _rsvpService.increaseSpeed,
                tooltip: 'Increase speed',
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '${_rsvpService.wordsPerMinute} WPM',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
