import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bibliod/core/storage/storage_path_service.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';
import 'package:bibliod/features/sync/data/webdav_service.dart';
import 'package:bibliod/features/sync/domain/sync_result.dart';

class SettingsDialog extends StatefulWidget {
  final BookNotifier bookNotifier;
  final SettingsNotifier settingsNotifier;
  final VoidCallback onImportCsv;
  final VoidCallback onExportCsv;
  final VoidCallback? onShowColumns;

  const SettingsDialog({
    super.key,
    required this.bookNotifier,
    required this.settingsNotifier,
    required this.onImportCsv,
    required this.onExportCsv,
    this.onShowColumns,
  });

  static Future<void> show(
    BuildContext context, {
    required BookNotifier bookNotifier,
    required SettingsNotifier settingsNotifier,
    required VoidCallback onImportCsv,
    required VoidCallback onExportCsv,
    VoidCallback? onShowColumns,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SettingsDialog(
        bookNotifier: bookNotifier,
        settingsNotifier: settingsNotifier,
        onImportCsv: onImportCsv,
        onExportCsv: onExportCsv,
        onShowColumns: onShowColumns,
      ),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _storageService = StoragePathService.instance;
  final _webDavService = WebDavService();

  String _currentDirectory = '';
  String _defaultDirectory = '';
  bool _isCustom = false;
  bool _isLoading = true;
  bool _isRelocating = false;

  late final TextEditingController _webdavUrlController;
  late final TextEditingController _webdavUsernameController;
  late final TextEditingController _webdavPasswordController;
  bool _obscurePassword = true;
  bool _isTestingConnection = false;
  bool? _connectionTestResult;
  bool _isSyncing = false;
  int _pendingChangesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDirectoryInfo();
    _initWebDavState();
  }

  void _initWebDavState() {
    _webdavUrlController = TextEditingController(
      text: widget.settingsNotifier.webdavUrl,
    );
    _webdavUsernameController = TextEditingController(
      text: widget.settingsNotifier.webdavUsername,
    );
    _webdavPasswordController = TextEditingController(
      text: widget.settingsNotifier.webdavPassword,
    );
    _refreshPendingChanges();
  }

  @override
  void dispose() {
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectoryInfo() async {
    final current = await _storageService.getCurrentDataDirectory();
    final def = await _storageService.getDefaultDataDirectory();
    final custom = await _storageService.isCustomDirectory();
    if (!mounted) return;
    setState(() {
      _currentDirectory = current;
      _defaultDirectory = def;
      _isCustom = custom;
      _isLoading = false;
    });
  }

  Future<void> _handleRelocate() async {
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Sélectionner le nouveau dossier pour la bibliothèque',
    );

    if (selectedDirectory == null || !mounted) return;

    if (selectedDirectory == _currentDirectory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le dossier sélectionné est déjà l\'emplacement actuel.',
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le déplacement'),
        content: Text(
          'Voulez-vous déplacer la base de données et les images de couverture vers :\n\n'
          '$selectedDirectory\n\n'
          'Les fichiers existants seront transférés et les liens d\'images mis à jour.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Déplacer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isRelocating = true);

    try {
      await _storageService.relocateDataDirectory(
        targetDirectoryPath: selectedDirectory,
      );
      await widget.bookNotifier.loadBooks();
      await _loadDirectoryInfo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La bibliothèque a été déplacée avec succès !'),
        ),
      );
    } catch (e, stack) {
      developer.log(
        'Erreur déplacement données: $e',
        error: e,
        stackTrace: stack,
        name: 'SettingsDialog',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du déplacement : $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRelocating = false);
      }
    }
  }

  Future<void> _handleResetDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rétablir l\'emplacement par défaut'),
        content: Text(
          'Voulez-vous replacer la base de données et les images de couverture dans l\'emplacement par défaut ?\n\n'
          '$_defaultDirectory',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rétablir'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isRelocating = true);

    try {
      await _storageService.resetToDefaultDirectory();
      await widget.bookNotifier.loadBooks();
      await _loadDirectoryInfo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emplacement par défaut rétabli !')),
      );
    } catch (e, stack) {
      developer.log(
        'Erreur rétablissement emplacement par défaut: $e',
        error: e,
        stackTrace: stack,
        name: 'SettingsDialog',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du rétablissement : $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRelocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_outlined),
          SizedBox(width: 10),
          Text('Paramètres'),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCsvSection(theme),
              const Divider(height: 32),
              _buildStorageSection(theme),
              const Divider(height: 32),
              _buildWebDavSection(theme),
              const Divider(height: 32),
              _buildThemeSection(theme),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildCsvSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Import / Export CSV',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sauvegardez vos données ou transférez vos listes de livres depuis ou vers un fichier CSV.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onImportCsv();
              },
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Importer un fichier CSV...'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onExportCsv();
              },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Exporter la bibliothèque en CSV...'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emplacement des données (Base de données & Couvertures)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Déplacez la base de données SQLite (bibliod.db) et toutes les images de couverture vers le répertoire de votre choix.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _buildDirectoryCard(theme),
        const SizedBox(height: 12),
        _buildStorageButtons(),
      ],
    );
  }

  Widget _buildDirectoryCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCustom ? Icons.folder_special_rounded : Icons.folder_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isLoading ? 'Chargement...' : _currentDirectory,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _isCustom
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isCustom ? 'Personnalisé' : 'Par défaut',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _isCustom
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageButtons() {
    if (_isRelocating) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Déplacement des données en cours, veuillez patienter...'),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: _handleRelocate,
          icon: const Icon(Icons.drive_file_move_outlined, size: 18),
          label: const Text('Déplacer la bibliothèque...'),
        ),
        if (_isCustom)
          OutlinedButton.icon(
            onPressed: _handleResetDefault,
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Rétablir l\'emplacement par défaut'),
          ),
      ],
    );
  }

  Widget _buildThemeSection(ThemeData theme) {
    final currentMode = widget.settingsNotifier.themeMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Affichage & Thème',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Système'),
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Clair'),
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Sombre'),
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                ),
              ],
              selected: {currentMode},
              onSelectionChanged: (newSelection) {
                widget.settingsNotifier.setThemeMode(newSelection.first);
              },
            ),
            const Spacer(),
            if (widget.onShowColumns != null)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onShowColumns?.call();
                },
                icon: const Icon(Icons.view_column_rounded, size: 18),
                label: const Text('Colonnes visibles...'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _refreshPendingChanges() async {
    final counter = await widget.bookNotifier.repository.getChangeCounter();
    final synced = await widget.bookNotifier.repository.getLastSyncedCounter();
    if (!mounted) return;
    setState(() {
      _pendingChangesCount = (counter - synced).clamp(0, 999999);
    });
  }

  Future<void> _saveWebDavConfig() async {
    await widget.settingsNotifier.setWebDavConfig(
      url: _webdavUrlController.text.trim(),
      username: _webdavUsernameController.text.trim(),
      password: _webdavPasswordController.text,
    );
  }

  Future<void> _handleTestConnection() async {
    await _saveWebDavConfig();
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
    });
    final ok = await _webDavService.testConnection(
      url: _webdavUrlController.text,
      username: _webdavUsernameController.text,
      password: _webdavPasswordController.text,
    );
    if (!mounted) return;
    setState(() {
      _isTestingConnection = false;
      _connectionTestResult = ok;
    });
  }

  Future<void> _handleManualSync() async {
    await _saveWebDavConfig();
    setState(() => _isSyncing = true);
    final result = await _webDavService.performSync(
      url: _webdavUrlController.text,
      username: _webdavUsernameController.text,
      password: _webdavPasswordController.text,
      repository: widget.bookNotifier.repository,
    );
    if (!mounted) return;
    if (result.status == SyncStatus.downloadedRemote) {
      await widget.bookNotifier.loadBooks();
    }
    if (result.status == SyncStatus.conflict && result.remoteManifest != null) {
      setState(() => _isSyncing = false);
      await _handleConflictResolution(result);
      return;
    }
    await _afterSyncComplete(result);
  }

  Future<void> _handleConflictResolution(SyncResult result) async {
    final choice = await _showConflictChoiceDialog(result);
    final manifest = result.remoteManifest;
    if (choice == null || choice == 'cancel' || manifest == null || !mounted) {
      return;
    }

    setState(() => _isSyncing = true);
    final finalResult = choice == 'upload'
        ? await _webDavService.resolveConflictForceUpload(
            url: _webdavUrlController.text,
            username: _webdavUsernameController.text,
            password: _webdavPasswordController.text,
            repository: widget.bookNotifier.repository,
            remoteManifest: manifest,
          )
        : await _webDavService.resolveConflictForceDownload(
            url: _webdavUrlController.text,
            username: _webdavUsernameController.text,
            password: _webdavPasswordController.text,
            repository: widget.bookNotifier.repository,
            remoteManifest: manifest,
          );

    if (choice != 'upload') {
      await widget.bookNotifier.loadBooks();
    }
    await _afterSyncComplete(finalResult);
  }

  Future<String?> _showConflictChoiceDialog(SyncResult result) {
    final theme = Theme.of(context);
    final rev = result.remoteManifest?.revision ?? 0;
    final count = result.remoteManifest?.booksCount ?? 0;
    final client = result.remoteManifest?.clientName ?? 'inconnu';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conflit de synchronisation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Des modifications ont eu lieu à la fois localement et sur le serveur.',
            ),
            const SizedBox(height: 8),
            Text(
              'Version serveur : Rév. $rev, $count livres ($client).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Quelle version conserver ? (Une copie de sécurité sera conservée).',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('download'),
            child: const Text('Garder la version distante'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('upload'),
            child: const Text('Garder ma version locale'),
          ),
        ],
      ),
    );
  }

  Future<void> _afterSyncComplete(SyncResult result) async {
    await widget.settingsNotifier.setWebDavLastSync(
      status: result.status.name,
      message: result.message,
    );
    await _refreshPendingChanges();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isSuccess
            ? Colors.green.shade700
            : Colors.red.shade700,
      ),
    );
  }

  Widget _buildWebDavSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Sauvegarde & Synchronisation en ligne (WebDAV)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: widget.settingsNotifier.webdavEnabled,
              onChanged: (val) {
                widget.settingsNotifier.setWebDavEnabled(val);
                _saveWebDavConfig();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Synchronisez automatiquement votre bibliothèque avec un serveur WebDAV (Nextcloud, ownCloud, NAS...) à chaque fermeture de l\'application.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _buildWebDavInputs(theme),
        const SizedBox(height: 12),
        _buildWebDavActions(theme),
        const SizedBox(height: 12),
        _buildWebDavStatus(theme),
      ],
    );
  }

  Widget _buildWebDavInputs(ThemeData theme) {
    return Column(
      children: [
        TextField(
          controller: _webdavUrlController,
          decoration: const InputDecoration(
            labelText: 'URL du dossier WebDAV',
            hintText:
                'https://cloud.exemple.com/remote.php/dav/files/user/BiblioD',
            isDense: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.cloud_queue_rounded, size: 20),
          ),
          onChanged: (_) => _saveWebDavConfig(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _webdavUsernameController,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                onChanged: (_) => _saveWebDavConfig(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _webdavPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe ou jeton d\'application',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onChanged: (_) => _saveWebDavConfig(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebDavActions(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _isTestingConnection || _isSyncing
              ? null
              : _handleTestConnection,
          icon: _isTestingConnection
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_check_rounded, size: 18),
          label: const Text('Tester la connexion'),
        ),
        FilledButton.icon(
          onPressed: _isSyncing || _isTestingConnection
              ? null
              : _handleManualSync,
          icon: _isSyncing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync_rounded, size: 18),
          label: const Text('Synchroniser maintenant'),
        ),
        _buildConnectionStatusBadge(theme),
      ],
    );
  }

  Widget _buildConnectionStatusBadge(ThemeData theme) {
    final res = _connectionTestResult;
    if (res == null) return const SizedBox.shrink();
    final isOk = res == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOk
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isOk ? Colors.green : Colors.red),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: isOk ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            isOk ? 'Connexion réussie' : 'Échec de connexion',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isOk ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDavStatus(ThemeData theme) {
    final lastTime = widget.settingsNotifier.webdavLastSyncTime;
    final lastMsg = widget.settingsNotifier.webdavLastSyncMessage;
    final formattedDate = lastTime.isNotEmpty
        ? DateFormat(
            'dd/MM/yyyy HH:mm',
          ).format(DateTime.parse(lastTime).toLocal())
        : 'Jamais';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dernière synchronisation : $formattedDate${lastMsg.isNotEmpty ? ' ($lastMsg)' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _pendingChangesCount > 0
                ? '$_pendingChangesCount modification(s) locale(s) en attente de sauvegarde.'
                : 'Toutes les modifications locales sont synchronisées.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _pendingChangesCount > 0
                  ? Colors.orange.shade800
                  : Colors.green.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
