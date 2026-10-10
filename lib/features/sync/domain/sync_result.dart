import 'sync_manifest.dart';

enum SyncStatus {
  success,
  upToDate,
  downloadedRemote,
  conflict,
  offline,
  authError,
  error,
}

class SyncResult {
  final SyncStatus status;
  final String message;
  final SyncManifest? remoteManifest;
  final int? localRevision;
  final String? conflictArchiveFile;
  final DateTime timestamp;

  SyncResult({
    required this.status,
    required this.message,
    this.remoteManifest,
    this.localRevision,
    this.conflictArchiveFile,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isSuccess =>
      status == SyncStatus.success ||
      status == SyncStatus.upToDate ||
      status == SyncStatus.downloadedRemote;
}
