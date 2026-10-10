import 'package:flutter/material.dart';
import 'package:bibliod/features/books/data/wikipedia_service.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';
import 'package:bibliod/features/books/presentation/widgets/author_bibliography_dialog.dart';

import 'package:bibliod/features/settings/presentation/settings_notifier.dart';

class AuthorWikiDialog extends StatelessWidget {
  final AuthorWikiInfo info;
  final BookNotifier? bookNotifier;
  final SettingsNotifier? settingsNotifier;

  const AuthorWikiDialog({
    super.key,
    required this.info,
    this.bookNotifier,
    this.settingsNotifier,
  });

  static void show(
    BuildContext context,
    AuthorWikiInfo info, {
    BookNotifier? bookNotifier,
    SettingsNotifier? settingsNotifier,
  }) {
    showDialog(
      context: context,
      builder: (context) => AuthorWikiDialog(
        info: info,
        bookNotifier: bookNotifier,
        settingsNotifier: settingsNotifier,
      ),
    );
  }

  void _openBibliography(BuildContext context, BookNotifier notifier) {
    AuthorBibliographyDialog.show(
      context,
      authorName: info.authorName,
      bookNotifier: notifier,
      settingsNotifier: settingsNotifier,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final thumb = info.thumbnailUrl;
    final notifier = bookNotifier;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E3846) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.menu_book_outlined, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.pageTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Wikipédia France',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumb != null && thumb.isNotEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(),
                    ),
                  ),
                ),
              Text(
                info.extract,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              SelectableText(
                'Source : ${info.pageUrl}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (notifier != null)
          OutlinedButton.icon(
            onPressed: () => _openBibliography(context, notifier),
            icon: const Icon(Icons.auto_stories_rounded, size: 18),
            label: const Text('Tous les livres de l\'auteur'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
