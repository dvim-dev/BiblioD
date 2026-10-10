import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';

class StoragePathService {
  static final StoragePathService instance = StoragePathService._init();
  static const String _configFileName = 'storage_config.json';
  static const String _configKeyCustomDir = 'custom_data_directory';

  StoragePathService._init();

  Future<File> _getConfigFile() async {
    final appDir = await getApplicationSupportDirectory();
    return File(p.join(appDir.path, _configFileName));
  }

  Future<String> getDefaultDataDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'bibliod');
  }

  Future<String> getCurrentDataDirectory() async {
    try {
      final configFile = await _getConfigFile();
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>?;
        final customDir = json?[_configKeyCustomDir] as String?;
        if (customDir != null && customDir.trim().isNotEmpty) {
          final dir = Directory(customDir.trim());
          if (await dir.exists()) {
            return dir.path;
          }
        }
      }
    } catch (e, stack) {
      developer.log(
        'Erreur lecture configuration stockage: $e',
        error: e,
        stackTrace: stack,
        name: 'StoragePathService',
      );
    }
    return getDefaultDataDirectory();
  }

  Future<bool> isCustomDirectory() async {
    final current = await getCurrentDataDirectory();
    final defaultDir = await getDefaultDataDirectory();
    return current != defaultDir;
  }

  Future<String> getDatabasePath() async {
    final dataDir = await getCurrentDataDirectory();
    final dir = Directory(dataDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(dataDir, AppConstants.dbName);
  }

  Future<String> getCoversDirectoryPath() async {
    final dataDir = await getCurrentDataDirectory();
    final coversDir = Directory(p.join(dataDir, AppConstants.coversFolder));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir.path;
  }

  Future<void> _saveCustomDirectory(String? path) async {
    final configFile = await _getConfigFile();
    if (path == null || path.trim().isEmpty) {
      if (await configFile.exists()) {
        await configFile.delete();
      }
      return;
    }
    final content = jsonEncode({_configKeyCustomDir: path.trim()});
    await configFile.writeAsString(content);
  }

  Future<void> relocateDataDirectory({
    required String targetDirectoryPath,
  }) async {
    final targetDir = Directory(targetDirectoryPath.trim());
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final currentDataDir = await getCurrentDataDirectory();
    if (p.canonicalize(currentDataDir) == p.canonicalize(targetDir.path)) {
      return;
    }

    // 1. Fermer la base SQLite courante
    await DatabaseHelper.instance.close();

    final currentDbFile = File(p.join(currentDataDir, AppConstants.dbName));
    final newDbFile = File(p.join(targetDir.path, AppConstants.dbName));

    // 2. Copier le fichier de base de données principal
    if (await currentDbFile.exists()) {
      await currentDbFile.copy(newDbFile.path);
    }

    // 3. Copier d'éventuels fichiers SQLite associés (-wal, -shm)
    await _copyAuxiliaryDbFiles(currentDataDir, targetDir.path);

    // 4. Copier les couvertures existantes
    final oldCoversDir = Directory(
      p.join(currentDataDir, AppConstants.coversFolder),
    );
    final newCoversDir = Directory(
      p.join(targetDir.path, AppConstants.coversFolder),
    );
    if (!await newCoversDir.exists()) {
      await newCoversDir.create(recursive: true);
    }
    await _copyDirectoryFiles(oldCoversDir, newCoversDir);

    // 5. Mettre à jour les chemins des couvertures dans la nouvelle base SQLite
    await _updateCoverPathsInTargetDb(
      newDbPath: newDbFile.path,
      oldCoversPath: oldCoversDir.path,
      newCoversPath: newCoversDir.path,
    );

    // 6. Sauvegarder le nouvel emplacement dans storage_config.json
    final defaultDir = await getDefaultDataDirectory();
    if (p.canonicalize(targetDir.path) == p.canonicalize(defaultDir)) {
      await _saveCustomDirectory(null);
    } else {
      await _saveCustomDirectory(targetDir.path);
    }

    // 7. Nettoyer les anciens fichiers une fois la copie validée
    await _cleanOldStorageFiles(currentDbFile, oldCoversDir);

    // 8. Rouvrir la base de données à son nouvel emplacement
    await DatabaseHelper.instance.database;
  }

  Future<void> resetToDefaultDirectory() async {
    final defaultDir = await getDefaultDataDirectory();
    await relocateDataDirectory(targetDirectoryPath: defaultDir);
  }

  Future<void> _copyAuxiliaryDbFiles(String sourceDir, String targetDir) async {
    for (final ext in ['-wal', '-shm']) {
      final auxFile = File(p.join(sourceDir, '${AppConstants.dbName}$ext'));
      if (await auxFile.exists()) {
        await auxFile.copy(p.join(targetDir, '${AppConstants.dbName}$ext'));
      }
    }
  }

  Future<void> _copyDirectoryFiles(
    Directory sourceDir,
    Directory targetDir,
  ) async {
    if (!await sourceDir.exists()) return;
    final entities = await sourceDir.list(recursive: false).toList();
    for (final entity in entities) {
      if (entity is File) {
        final filename = p.basename(entity.path);
        final dest = File(p.join(targetDir.path, filename));
        await entity.copy(dest.path);
      }
    }
  }

  Future<void> _updateCoverPathsInTargetDb({
    required String newDbPath,
    required String oldCoversPath,
    required String newCoversPath,
  }) async {
    if (!await File(newDbPath).exists()) return;
    try {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(newDbPath);
      await db.execute(
        'UPDATE books SET cover_image_path = replace(cover_image_path, ?, ?) '
        'WHERE cover_image_path IS NOT NULL',
        [oldCoversPath, newCoversPath],
      );
      await db.close();
    } catch (e, stack) {
      developer.log(
        'Erreur mise à jour chemins couvertures: $e',
        error: e,
        stackTrace: stack,
        name: 'StoragePathService',
      );
    }
  }

  Future<void> _cleanOldStorageFiles(
    File oldDbFile,
    Directory oldCoversDir,
  ) async {
    try {
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
      }
      for (final ext in ['-wal', '-shm']) {
        final aux = File('${oldDbFile.path}$ext');
        if (await aux.exists()) {
          await aux.delete();
        }
      }
      if (await oldCoversDir.exists()) {
        await oldCoversDir.delete(recursive: true);
      }
    } catch (e, stack) {
      developer.log(
        'Avertissement nettoyage ancien répertoire: $e',
        error: e,
        stackTrace: stack,
        name: 'StoragePathService',
      );
    }
  }
}
