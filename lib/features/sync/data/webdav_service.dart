import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:bibliod/core/database/database_helper.dart';
import 'package:bibliod/core/storage/storage_path_service.dart';
import 'package:bibliod/features/books/data/book_repository.dart';
import '../domain/sync_manifest.dart';
import '../domain/sync_result.dart';

class WebDavService {
  final http.Client _client;

  WebDavService({http.Client? client}) : _client = client ?? http.Client();

  String _buildAuthHeader(String username, String password) {
    final credentials = '$username:$password';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  String _resolveUrl(String baseUrl, String filename) {
    final cleanBase = baseUrl.trim();
    if (cleanBase.endsWith('/')) {
      return '$cleanBase$filename';
    }
    return '$cleanBase/$filename';
  }

  Map<String, String> _buildHeaders(
    String username,
    String password, {
    String contentType = 'application/octet-stream',
  }) {
    return {
      'Authorization': _buildAuthHeader(username, password),
      'Content-Type': contentType,
    };
  }

  Future<String> calculateFileSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<bool> testConnection({
    required String url,
    required String username,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(url.trim());
      final req = http.Request('PROPFIND', uri)
        ..headers.addAll({
          'Authorization': _buildAuthHeader(username, password),
          'Depth': '0',
        });
      final res = await _client.send(req).timeout(const Duration(seconds: 4));
      return (res.statusCode >= 200 && res.statusCode < 300) ||
          res.statusCode == 207;
    } catch (e, stack) {
      developer.log(
        'WebDAV connection test failed: $e',
        error: e,
        stackTrace: stack,
        name: 'WebDavService',
      );
      return false;
    }
  }

  Future<bool> ensureRemoteDirectory({
    required String url,
    required String username,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(url.trim());
      final req = http.Request('MKCOL', uri)
        ..headers.addAll({
          'Authorization': _buildAuthHeader(username, password),
        });
      final res = await _client.send(req).timeout(const Duration(seconds: 4));
      return res.statusCode == 201 ||
          res.statusCode == 405 ||
          res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<SyncManifest?> getRemoteManifest({
    required String url,
    required String username,
    required String password,
  }) async {
    try {
      final manifestUri = Uri.parse(_resolveUrl(url, 'bibliod_sync.json'));
      final req = http.Request('GET', manifestUri)
        ..headers.addAll({
          'Authorization': _buildAuthHeader(username, password),
        });
      final streamed = await _client
          .send(req)
          .timeout(const Duration(seconds: 4));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        return SyncManifest.fromJson(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e, stack) {
      developer.log(
        'Error fetching remote manifest: $e',
        error: e,
        stackTrace: stack,
        name: 'WebDavService',
      );
      return null;
    }
  }

  Future<bool> uploadFile({
    required String targetUrl,
    required String username,
    required String password,
    required List<int> bytes,
    String contentType = 'application/octet-stream',
  }) async {
    try {
      final uri = Uri.parse(targetUrl);
      final req = http.Request('PUT', uri)
        ..headers.addAll(
          _buildHeaders(username, password, contentType: contentType),
        )
        ..bodyBytes = bytes;
      final streamed = await _client
          .send(req)
          .timeout(const Duration(seconds: 8));
      return streamed.statusCode >= 200 && streamed.statusCode < 300;
    } catch (e, stack) {
      developer.log(
        'Upload file error: $e',
        error: e,
        stackTrace: stack,
        name: 'WebDavService',
      );
      return false;
    }
  }

  Future<List<int>?> downloadFile({
    required String sourceUrl,
    required String username,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(sourceUrl);
      final req = http.Request('GET', uri)
        ..headers.addAll({
          'Authorization': _buildAuthHeader(username, password),
        });
      final streamed = await _client
          .send(req)
          .timeout(const Duration(seconds: 8));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
      return null;
    } catch (e, stack) {
      developer.log(
        'Download file error: $e',
        error: e,
        stackTrace: stack,
        name: 'WebDavService',
      );
      return null;
    }
  }

  Future<bool> _applyDownloadedDb(List<int> bytes, String dbPath) async {
    try {
      await DatabaseHelper.instance.close();
      final file = File(dbPath);
      await file.writeAsBytes(bytes, flush: true);
      await DatabaseHelper.instance.database;
      return true;
    } catch (e, stack) {
      developer.log(
        'Error applying downloaded DB: $e',
        error: e,
        stackTrace: stack,
        name: 'WebDavService',
      );
      return false;
    }
  }

  Future<SyncResult> performSync({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    bool isAutoSyncOnExit = false,
  }) async {
    try {
      final ok = await testConnection(
        url: url,
        username: username,
        password: password,
      );
      if (!ok) {
        return SyncResult(
          status: SyncStatus.offline,
          message: 'Serveur WebDAV inaccessible ou identifiants invalides.',
        );
      }
      await ensureRemoteDirectory(
        url: url,
        username: username,
        password: password,
      );
      final manifest = await getRemoteManifest(
        url: url,
        username: username,
        password: password,
      );
      return await _dispatchSyncWorkflow(
        url: url,
        username: username,
        password: password,
        repository: repository,
        remoteManifest: manifest,
        isAutoSyncOnExit: isAutoSyncOnExit,
      );
    } catch (e, stack) {
      developer.log(
        'Sync error: $e',
        error: e,
        stackTrace: stack,
        name: 'WebDavService',
      );
      return SyncResult(
        status: SyncStatus.error,
        message: 'Erreur de synchronisation : $e',
      );
    }
  }

  Future<SyncResult> _dispatchSyncWorkflow({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    required SyncManifest? remoteManifest,
    required bool isAutoSyncOnExit,
  }) async {
    final hasUnsynced = await repository.hasUnsyncedChanges();
    final lastSyncedRev = await repository.getLastSyncedRemoteRevision();
    final remoteRev = remoteManifest?.revision ?? 0;

    if (remoteManifest == null) {
      return _uploadLocalVersion(
        url: url,
        username: username,
        password: password,
        repository: repository,
        targetRevision: 1,
      );
    }
    if (!hasUnsynced && remoteRev <= lastSyncedRev) {
      return SyncResult(
        status: SyncStatus.upToDate,
        message: 'La bibliothèque est déjà à jour.',
        remoteManifest: remoteManifest,
        localRevision: remoteRev,
      );
    }
    if (!hasUnsynced && remoteRev > lastSyncedRev) {
      return _downloadRemoteVersion(
        url: url,
        username: username,
        password: password,
        repository: repository,
        remoteManifest: remoteManifest,
      );
    }
    if (hasUnsynced && remoteRev <= lastSyncedRev) {
      return _uploadLocalVersion(
        url: url,
        username: username,
        password: password,
        repository: repository,
        targetRevision: remoteRev + 1,
      );
    }
    return _handleConflictSituation(
      url: url,
      username: username,
      password: password,
      repository: repository,
      remoteManifest: remoteManifest,
      isAutoSyncOnExit: isAutoSyncOnExit,
    );
  }

  Future<SyncResult> _uploadLocalVersion({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    required int targetRevision,
  }) async {
    final dbPath = await StoragePathService.instance.getDatabasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      return SyncResult(
        status: SyncStatus.error,
        message: 'Base locale introuvable.',
      );
    }
    final dbBytes = await dbFile.readAsBytes();
    final okDb = await uploadFile(
      targetUrl: _resolveUrl(url, 'bibliod.db'),
      username: username,
      password: password,
      bytes: dbBytes,
    );
    if (!okDb) {
      return SyncResult(
        status: SyncStatus.error,
        message: 'Échec envoi bibliod.db.',
      );
    }
    return _finalizeManifestUpload(
      url: url,
      username: username,
      password: password,
      repository: repository,
      targetRevision: targetRevision,
      dbSha256: sha256.convert(dbBytes).toString(),
    );
  }

  Future<SyncResult> _finalizeManifestUpload({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    required int targetRevision,
    required String dbSha256,
  }) async {
    final allBooks = await repository.getAllBooks();
    final clientId = await repository.getClientId();
    final manifest = SyncManifest(
      clientId: clientId,
      clientName: Platform.localHostname,
      revision: targetRevision,
      lastModified: DateTime.now().toUtc().toIso8601String(),
      booksCount: allBooks.length,
      dbSha256: dbSha256,
    );
    final okManifest = await uploadFile(
      targetUrl: _resolveUrl(url, 'bibliod_sync.json'),
      username: username,
      password: password,
      bytes: utf8.encode(manifest.toJson()),
      contentType: 'application/json',
    );
    if (!okManifest) {
      return SyncResult(
        status: SyncStatus.error,
        message: 'Échec envoi manifeste.',
      );
    }
    final counter = await repository.getChangeCounter();
    await repository.recordSuccessfulSync(
      syncedRevision: targetRevision,
      syncedCounter: counter,
    );
    return SyncResult(
      status: SyncStatus.success,
      message: 'Sauvegarde réussie (Révision $targetRevision).',
      remoteManifest: manifest,
      localRevision: targetRevision,
    );
  }

  Future<SyncResult> _downloadRemoteVersion({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    required SyncManifest remoteManifest,
  }) async {
    final bytes = await downloadFile(
      sourceUrl: _resolveUrl(url, 'bibliod.db'),
      username: username,
      password: password,
    );
    if (bytes == null) {
      return SyncResult(
        status: SyncStatus.error,
        message: 'Échec du téléchargement de bibliod.db distant.',
      );
    }
    final dbPath = await StoragePathService.instance.getDatabasePath();
    final applied = await _applyDownloadedDb(bytes, dbPath);
    if (!applied) {
      return SyncResult(
        status: SyncStatus.error,
        message: 'Impossible de remplacer la base locale.',
      );
    }
    final currentCounter = await repository.getChangeCounter();
    await repository.recordSuccessfulSync(
      syncedRevision: remoteManifest.revision,
      syncedCounter: currentCounter,
    );
    return SyncResult(
      status: SyncStatus.downloadedRemote,
      message:
          'Base synchronisée avec succès depuis le serveur (Rév. ${remoteManifest.revision}).',
      remoteManifest: remoteManifest,
      localRevision: remoteManifest.revision,
    );
  }

  Future<SyncResult> _handleConflictSituation({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    required SyncManifest remoteManifest,
    required bool isAutoSyncOnExit,
  }) async {
    if (isAutoSyncOnExit) {
      return _archiveConflictOnExit(
        url: url,
        username: username,
        password: password,
        repository: repository,
        remoteManifest: remoteManifest,
      );
    }
    return SyncResult(
      status: SyncStatus.conflict,
      message: 'Conflit de synchronisation détecté.',
      remoteManifest: remoteManifest,
    );
  }

  Future<SyncResult> _archiveConflictOnExit({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    required SyncManifest remoteManifest,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final conflictFileName = 'bibliod_conflict_local_$nowIso.db';
    final dbPath = await StoragePathService.instance.getDatabasePath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final bytes = await dbFile.readAsBytes();
      await uploadFile(
        targetUrl: _resolveUrl(url, conflictFileName),
        username: username,
        password: password,
        bytes: bytes,
      );
    }
    await repository.setSetting('webdav_pending_conflict', conflictFileName);
    return SyncResult(
      status: SyncStatus.conflict,
      message: 'Conflit détecté. Copie locale archivée sous $conflictFileName.',
      remoteManifest: remoteManifest,
      conflictArchiveFile: conflictFileName,
    );
  }

  Future<SyncResult> resolveConflictForceUpload({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    required SyncManifest remoteManifest,
  }) async {
    final remoteBytes = await downloadFile(
      sourceUrl: _resolveUrl(url, 'bibliod.db'),
      username: username,
      password: password,
    );
    if (remoteBytes != null) {
      final nowIso = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
      await uploadFile(
        targetUrl: _resolveUrl(url, 'bibliod_conflict_remote_$nowIso.db'),
        username: username,
        password: password,
        bytes: remoteBytes,
      );
    }
    await repository.setSetting('webdav_pending_conflict', '');
    return _uploadLocalVersion(
      url: url,
      username: username,
      password: password,
      repository: repository,
      targetRevision: remoteManifest.revision + 1,
    );
  }

  Future<SyncResult> resolveConflictForceDownload({
    required String url,
    required String username,
    required String password,
    required BookRepository repository,
    required SyncManifest remoteManifest,
  }) async {
    final dbPath = await StoragePathService.instance.getDatabasePath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final nowIso = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
      await dbFile.copy('${dbPath}_conflict_local_$nowIso.bak');
    }
    await repository.setSetting('webdav_pending_conflict', '');
    return _downloadRemoteVersion(
      url: url,
      username: username,
      password: password,
      repository: repository,
      remoteManifest: remoteManifest,
    );
  }
}
