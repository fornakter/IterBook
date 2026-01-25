import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/reading_preferences_service.dart';

/// Settings screen - app configuration and personalization
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.preferencesService,
  });

  final ReadingPreferencesService preferencesService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.preferencesService,
      builder: (context, child) {
        final l10n = AppLocalizations.of(context)!;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(l10n.settings),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Reading display section
              _buildSectionTitle(context, l10n.readingDisplay),

              // Font size slider
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.fontSize,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            '${widget.preferencesService.fontSize.toInt()} px',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: widget.preferencesService.fontSize,
                        min: ReadingPreferencesService.minFontSize,
                        max: ReadingPreferencesService.maxFontSize,
                        divisions: 12,
                        label: '${widget.preferencesService.fontSize.toInt()}',
                        onChanged: (value) {
                          widget.preferencesService.setFontSize(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Background color
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.backgroundColor,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: ReadingPreferencesService.backgroundPresets
                            .map((color) => _buildColorOption(
                                  color: color,
                                  isSelected: widget.preferencesService.backgroundColor == color,
                                  onTap: () => widget.preferencesService.setBackgroundColor(color),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Text color
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.textColor,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: ReadingPreferencesService.textPresets
                            .map((color) => _buildColorOption(
                                  color: color,
                                  isSelected: widget.preferencesService.textColor == color,
                                  onTap: () => widget.preferencesService.setTextColor(color),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Preview
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.preview,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: widget.preferencesService.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Center(
                          child: Text(
                            l10n.sample,
                            style: TextStyle(
                              fontSize: widget.preferencesService.fontSize,
                              fontWeight: FontWeight.bold,
                              color: widget.preferencesService.textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reset button
              OutlinedButton.icon(
                onPressed: () {
                  widget.preferencesService.resetToDefaults();
                },
                icon: const Icon(Icons.restore),
                label: Text(l10n.resetToDefaults),
              ),
              const SizedBox(height: 32),

              // About section
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.about),
                subtitle: const Text('IterBook v1.0.0'),
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorOption({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: _contrastColor(color),
                size: 24,
              )
            : null,
      ),
    );
  }

  Color _contrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'IterBook',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026',
      applicationIcon: const Icon(
        Icons.menu_book,
        size: 48,
        color: Colors.deepPurple,
      ),
      children: const [
        SizedBox(height: 16),
        Text('Aplikacja do szybkiego czytania metodą RSVP (Rapid Serial Visual Presentation).'),
        SizedBox(height: 16),
        Divider(),
        SizedBox(height: 8),
        Text(
          'Informacja prawna',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Twórca aplikacji nie posiada żadnych praw do książek wczytywanych przez użytkowników. '
          'Użytkownik jest odpowiedzialny za posiadanie legalnych praw do czytanych treści. '
          'Przed wczytaniem książki upewnij się, że posiadasz prawo do jej użytkowania (np. poprzez zakup).',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
