import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bibliod/core/constants/app_constants.dart';
import 'package:bibliod/features/books/data/csv_export_service.dart';
import 'package:bibliod/features/books/domain/book.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';
import 'package:bibliod/features/books/presentation/widgets/book_form_dialog.dart';
import 'package:bibliod/features/books/presentation/widgets/book_table_view.dart';
import 'package:bibliod/features/books/presentation/widgets/columns_dialog.dart';
import 'package:bibliod/features/books/presentation/widgets/csv_import_dialog.dart';
import 'package:bibliod/features/books/presentation/widgets/statistics_dialog.dart';
import 'package:bibliod/features/books/presentation/widgets/toolbar_widget.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';
import 'package:bibliod/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:bibliod/features/sync/data/webdav_service.dart';
import 'package:bibliod/features/sync/domain/sync_result.dart';

class HomeScreen extends StatefulWidget {
  final BookNotifier bookNotifier;
  final SettingsNotifier settingsNotifier;

  const HomeScreen({
    super.key,
    required this.bookNotifier,
    required this.settingsNotifier,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CsvExportService _csvExportService = CsvExportService();
  final WebDavService _webDavService = WebDavService();
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: _handleExitRequested,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStartupSyncOrConflict();
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _handleExitRequested() async {
    final settings = widget.settingsNotifier;
    if (!settings.webdavEnabled || settings.webdavUrl.trim().isEmpty) {
      return AppExitResponse.exit;
    }
    final hasUnsynced = await widget.bookNotifier.repository
        .hasUnsyncedChanges();
    if (!hasUnsynced) {
      return AppExitResponse.exit;
    }
    await _executeAutoSyncOnExit(settings);
    return AppExitResponse.exit;
  }

  Future<void> _executeAutoSyncOnExit(SettingsNotifier settings) async {
    try {
      await _webDavService
          .performSync(
            url: settings.webdavUrl,
            username: settings.webdavUsername,
            password: settings.webdavPassword,
            repository: widget.bookNotifier.repository,
            isAutoSyncOnExit: true,
          )
          .timeout(const Duration(seconds: 4));
    } catch (e, stack) {
      developer.log(
        'Auto sync on exit failed: $e',
        error: e,
        stackTrace: stack,
        name: 'HomeScreen',
      );
    }
  }

  Future<void> _checkStartupSyncOrConflict() async {
    final pending = widget.settingsNotifier.webdavPendingConflict;
    if (pending.isNotEmpty) {
      await _showPendingConflictPrompt(pending);
      return;
    }
    await _performBackgroundStartupSync();
  }

  Future<void> _performBackgroundStartupSync() async {
    final settings = widget.settingsNotifier;
    if (!settings.webdavEnabled || settings.webdavUrl.trim().isEmpty) return;

    try {
      final res = await _webDavService.performSync(
        url: settings.webdavUrl,
        username: settings.webdavUsername,
        password: settings.webdavPassword,
        repository: widget.bookNotifier.repository,
      );
      if (res.status == SyncStatus.downloadedRemote && mounted) {
        await widget.bookNotifier.loadBooks();
      } else if (res.status == SyncStatus.conflict && mounted) {
        await _showStartupConflictDialog(res);
      }
    } catch (e, stack) {
      developer.log(
        'Startup sync failed: $e',
        error: e,
        stackTrace: stack,
        name: 'HomeScreen',
      );
    }
  }

  Future<void> _showPendingConflictPrompt(String conflictFile) async {
    if (!mounted) return;
    final resolveNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conflit WebDAV en attente'),
          ],
        ),
        content: Text(
          'Un conflit de synchronisation a été détecté lors de la session précédente.\n'
          'Une copie locale a été archivée sur le serveur ($conflictFile).\n\n'
          'Voulez-vous ouvrir les paramètres pour le résoudre ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
    if (resolveNow == true && mounted) {
      _openSettingsDialog(context);
    }
  }

  Future<void> _showStartupConflictDialog(SyncResult res) async {
    if (!mounted) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conflit de synchronisation'),
          ],
        ),
        content: const Text(
          'Des modifications distantes et locales ont été détectées simultanément.\n\n'
          'Voulez-vous ouvrir les paramètres pour choisir la version à conserver ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ignorer pour le moment'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Résoudre dans les paramètres'),
          ),
        ],
      ),
    );
    if (openSettings == true && mounted) {
      _openSettingsDialog(context);
    }
  }

  Future<void> _openAddBookDialog(BuildContext context) async {
    await BookFormDialog.show(
      context,
      bookNotifier: widget.bookNotifier,
      settingsNotifier: widget.settingsNotifier,
    );
  }

  Future<void> _openEditBookDialog(BuildContext context, Book book) async {
    final result = await BookFormDialog.show(
      context,
      book: book,
      bookNotifier: widget.bookNotifier,
      settingsNotifier: widget.settingsNotifier,
    );
    if (!context.mounted || result == null) return;
    if (result == 'delete') {
      await _handleBookDeletion(context, book);
    }
  }

  Future<void> _handleBookDeletion(BuildContext context, Book book) async {
    final id = book.id;
    if (id == null) return;
    final confirm = await _showDeleteConfirmDialog(context, book.title);
    if (confirm == true && context.mounted) {
      await widget.bookNotifier.deleteBook(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le livre "${book.title}" a été supprimé.')),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "$title" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _openColumnsDialog(BuildContext context) {
    ColumnsDialog.show(context, widget.settingsNotifier);
  }

  void _openStatisticsDialog(BuildContext context) {
    StatisticsDialog.show(context, widget.bookNotifier.statistics);
  }

  void _openCsvImportDialog(BuildContext context) {
    CsvImportDialog.show(context, widget.bookNotifier);
  }

  void _openSettingsDialog(BuildContext context) {
    SettingsDialog.show(
      context,
      bookNotifier: widget.bookNotifier,
      settingsNotifier: widget.settingsNotifier,
      onImportCsv: () => _openCsvImportDialog(context),
      onExportCsv: () => _exportCsv(context),
      onShowColumns: () => _openColumnsDialog(context),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final books = widget.bookNotifier.books;
    if (books.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aucun livre à exporter.')));
      return;
    }
    final now = DateTime.now();
    final d =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final bytes = Uint8List.fromList(
      utf8.encode(_csvExportService.generateCsvString(books)),
    );
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Exporter la bibliothèque en CSV',
      fileName: 'bibliod_export_$d.csv',
      bytes: bytes,
      mimeType: 'text/csv',
    );
    if (uri != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${books.length} livres exportés avec succès !'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final toolbarColor = isDark ? const Color(0xFF1E232B) : Colors.white;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _openAddBookDialog(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: toolbarColor,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([
                  widget.bookNotifier,
                  widget.settingsNotifier,
                ]),
                builder: (context, _) => ToolbarWidget(
                  bookNotifier: widget.bookNotifier,
                  settingsNotifier: widget.settingsNotifier,
                  onAddBook: () => _openAddBookDialog(context),
                  onShowColumns: () => _openColumnsDialog(context),
                  onShowStatistics: () => _openStatisticsDialog(context),
                  onOpenSettings: () => _openSettingsDialog(context),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    widget.bookNotifier,
                    widget.settingsNotifier,
                  ]),
                  builder: (context, _) => BookTableView(
                    bookNotifier: widget.bookNotifier,
                    settingsNotifier: widget.settingsNotifier,
                    onBookDoubleTap: (book) =>
                        _openEditBookDialog(context, book),
                  ),
                ),
              ),
              _buildStatusBar(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, bool isDark) {
    return ListenableBuilder(
      listenable: widget.bookNotifier,
      builder: (context, _) {
        final total = widget.bookNotifier.totalCount;
        final currentCount = widget.bookNotifier.books.length;
        final sortColLabel =
            AppConstants.columnLabels[widget.bookNotifier.sortColumn] ??
            widget.bookNotifier.sortColumn;
        final sortDir = widget.bookNotifier.sortAscending
            ? 'croissant'
            : 'décroissant';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A22) : const Color(0xFFEAECEF),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF262E3B) : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                widget.bookNotifier.searchQuery.isNotEmpty
                    ? '$currentCount affiché(s) sur $total livre(s)'
                    : '$total livre(s) dans la bibliothèque',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const Spacer(),
              Text(
                'Tri : $sortColLabel ($sortDir)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 16),
              const Text(
                'Double-clic sur une ligne pour ouvrir la fiche',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
