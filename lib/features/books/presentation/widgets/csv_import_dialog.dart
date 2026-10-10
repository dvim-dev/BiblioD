import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:bibliod/features/books/data/csv_service.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';

class CsvImportDialog extends StatefulWidget {
  final BookNotifier bookNotifier;

  const CsvImportDialog({super.key, required this.bookNotifier});

  static Future<void> show(BuildContext context, BookNotifier bookNotifier) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CsvImportDialog(bookNotifier: bookNotifier),
    );
  }

  @override
  State<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<CsvImportDialog> {
  final _csvService = CsvService();
  String? _selectedFilePath;
  CsvImportResult? _importResult;
  bool _isParsing = false;
  bool _isImporting = false;

  Future<void> _pickAndParseFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    final path = files.firstOrNull?.path;
    if (path == null) return;

    setState(() {
      _selectedFilePath = path;
      _isParsing = true;
      _importResult = null;
    });

    final parseResult = await _csvService.parseCsvFile(path);

    if (!mounted) return;
    setState(() {
      _isParsing = false;
      _importResult = parseResult;
    });
  }

  Future<void> _doImport() async {
    final result = _importResult;
    if (result == null || result.books.isEmpty) return;

    setState(() => _isImporting = true);
    final count = await widget.bookNotifier.importBooks(result.books);
    setState(() => _isImporting = false);

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count livres ont été importés avec succès !')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _importResult;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: const Row(
        children: [
          Icon(Icons.file_upload_outlined),
          SizedBox(width: 10),
          Text('Importer une base de livres (CSV)'),
        ],
      ),
      content: SizedBox(
        width: 680,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sélectionnez un fichier CSV (.csv). Les délimiteurs (virgule, point-virgule) et les colonnes (Titre, Auteur, ISBN, Genre, etc.) seront automatiquement détectés.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isParsing || _isImporting
                      ? null
                      : _pickAndParseFile,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Choisir un fichier CSV'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _selectedFilePath != null
                        ? _selectedFilePath!
                        : 'Aucun fichier sélectionné',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedFilePath != null
                          ? theme.colorScheme.primary
                          : Colors.grey,
                      fontFamily: _selectedFilePath != null
                          ? 'monospace'
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isParsing)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Analyse du fichier CSV en cours...'),
                    ],
                  ),
                ),
              )
            else if (result != null)
              Expanded(child: _buildPreview(result, theme))
            else
              Expanded(
                child: Center(
                  child: Text(
                    'En attente d\'un fichier CSV...',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: (_isImporting || result == null || result.books.isEmpty)
              ? null
              : _doImport,
          icon: _isImporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text('Importer (${result?.books.length ?? 0} livres)'),
        ),
      ],
    );
  }

  Widget _buildPreview(CsvImportResult result, ThemeData theme) {
    if (result.books.isEmpty) {
      return Center(
        child: Text(
          'Aucun livre valide trouvé dans ce fichier.',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    final previewBooks = result.books.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aperçu (${previewBooks.length} sur ${result.books.length} détectés) :',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.separated(
              itemCount: previewBooks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final book = previewBooks[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${book.authorDisplayNatural} • ${book.format}${book.genre != null ? " • ${book.genre}" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: book.rating > 0
                      ? Text(
                          '★ ${book.rating}',
                          style: const TextStyle(color: Color(0xFFD49B35)),
                        )
                      : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
