import 'dart:developer' as developer;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../storage/storage_path_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    final currentDb = _database;
    if (currentDb != null) {
      return currentDb;
    }
    final newDb = await _initDB();
    _database = newDb;
    return newDb;
  }

  Future<Database> _initDB() async {
    try {
      sqfliteFfiInit();

      final dbPath = await StoragePathService.instance.getDatabasePath();
      developer.log('Database path: $dbPath', name: 'DatabaseHelper');

      return await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 1, onCreate: _createDB),
      );
    } catch (e, stack) {
      developer.log(
        'Error initializing database: $e',
        error: e,
        stackTrace: stack,
        name: 'DatabaseHelper',
      );
      rethrow;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE books (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          author_last_name TEXT NOT NULL,
          author_first_name TEXT,
          rating INTEGER DEFAULT 0,
          series TEXT,
          series_number REAL,
          genre TEXT,
          isbn TEXT,
          format TEXT NOT NULL DEFAULT 'Physique',
          remarks TEXT,
          publisher TEXT,
          publication_year INTEGER,
          cover_image_path TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_books_author_title ON books(author_last_name, author_first_name, title)',
      );
      await db.execute('CREATE INDEX idx_books_isbn ON books(isbn)');
      await db.execute('CREATE INDEX idx_books_series ON books(series)');
    } catch (e, stack) {
      developer.log(
        'Error creating database schema: $e',
        error: e,
        stackTrace: stack,
        name: 'DatabaseHelper',
      );
      rethrow;
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
