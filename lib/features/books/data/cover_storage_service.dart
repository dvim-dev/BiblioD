import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:bibliod/core/storage/storage_path_service.dart';

class CoverStorageService {
  static final CoverStorageService instance = CoverStorageService._init();

  CoverStorageService._init();

  Future<Directory> _getCoversDirectory() async {
    final coversDirPath = await StoragePathService.instance
        .getCoversDirectoryPath();
    final coversDir = Directory(coversDirPath);
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir;
  }

  Future<String?> resolveCoverFilePath(String? storedPath) async {
    if (storedPath == null || storedPath.trim().isEmpty) return null;
    final file = File(storedPath);
    if (await file.exists()) {
      return storedPath;
    }
    final coversDirPath = await StoragePathService.instance
        .getCoversDirectoryPath();
    final fallback = File(p.join(coversDirPath, p.basename(storedPath)));
    if (await fallback.exists()) {
      return fallback.path;
    }
    return storedPath;
  }

  Future<String?> saveCoverBytes(
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    try {
      final dir = await _getCoversDirectory();
      final filename =
          'cover_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final file = File(p.join(dir.path, filename));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e, stack) {
      developer.log(
        'Error saving cover bytes: $e',
        error: e,
        stackTrace: stack,
        name: 'CoverStorageService',
      );
      return null;
    }
  }

  Future<String?> saveCoverFile(String sourceFilePath) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) return null;

      final dir = await _getCoversDirectory();
      final ext = p.extension(sourceFilePath).replaceAll('.', '');
      final filename =
          'cover_${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
      final targetFile = File(p.join(dir.path, filename));
      await sourceFile.copy(targetFile.path);
      return targetFile.path;
    } catch (e, stack) {
      developer.log(
        'Error saving cover file: $e',
        error: e,
        stackTrace: stack,
        name: 'CoverStorageService',
      );
      return null;
    }
  }

  Future<void> deleteCover(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, stack) {
      developer.log(
        'Error deleting cover: $e',
        error: e,
        stackTrace: stack,
        name: 'CoverStorageService',
      );
    }
  }
}
