import 'dart:developer' as developer;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bibliod/core/database/database_helper.dart';
import 'package:bibliod/features/books/domain/book.dart';

class BookRepository {
  final DatabaseHelper _dbHelper;

  BookRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Book>> getAllBooks() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'books',
        orderBy: 'author_last_name ASC, author_first_name ASC, title ASC',
      );
      return maps.map((m) => Book.fromMap(m)).toList();
    } catch (e, stack) {
      developer.log(
        'Error fetching books: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
      return [];
    }
  }

  Future<Book?> getLastRegisteredBook() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('books', orderBy: 'id DESC', limit: 1);
      if (maps.isNotEmpty) {
        return Book.fromMap(maps.first);
      }
      return null;
    } catch (e, stack) {
      developer.log(
        'Error fetching last registered book: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
      return null;
    }
  }

  Future<int?> insertBook(Book book) async {
    try {
      final db = await _dbHelper.database;
      final map = book.toMap();
      map.remove('id');
      final id = await db.insert('books', map);
      if (id > 0) {
        await _bumpChangeCounter();
      }
      return id;
    } catch (e, stack) {
      developer.log(
        'Error inserting book: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
      return null;
    }
  }

  Future<bool> updateBook(Book book) async {
    try {
      final bookId = book.id;
      if (bookId == null) return false;

      final db = await _dbHelper.database;
      final count = await db.update(
        'books',
        book.toMap(),
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (count > 0) {
        await _bumpChangeCounter();
      }
      return count > 0;
    } catch (e, stack) {
      developer.log(
        'Error updating book: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
      return false;
    }
  }

  Future<bool> deleteBook(int id) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete('books', where: 'id = ?', whereArgs: [id]);
      if (count > 0) {
        await _bumpChangeCounter();
      }
      return count > 0;
    } catch (e, stack) {
      developer.log(
        'Error deleting book: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
      return false;
    }
  }

  Future<int> batchInsertBooks(List<Book> books) async {
    if (books.isEmpty) return 0;
    try {
      final db = await _dbHelper.database;
      var insertedCount = 0;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final book in books) {
          final map = book.toMap();
          map.remove('id');
          batch.insert('books', map);
        }
        final results = await batch.commit(noResult: false);
        insertedCount = results.length;
      });
      if (insertedCount > 0) {
        await _bumpChangeCounter();
      }
      return insertedCount;
    } catch (e, stack) {
      developer.log(
        'Error batch inserting books: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
      return 0;
    }
  }

  Future<void> _bumpChangeCounter() async {
    try {
      final current = await getChangeCounter();
      await setSetting('local_change_counter', (current + 1).toString());
      await setSetting(
        'local_last_modified_timestamp',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e, stack) {
      developer.log(
        'Error bumping change counter: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
    }
  }

  Future<int> getChangeCounter() async {
    final val = await getSetting('local_change_counter');
    if (val != null) {
      return int.tryParse(val) ?? 0;
    }
    return 0;
  }

  Future<int> getLastSyncedCounter() async {
    final val = await getSetting('last_synced_counter');
    if (val != null) {
      return int.tryParse(val) ?? 0;
    }
    return 0;
  }

  Future<int> getLastSyncedRemoteRevision() async {
    final val = await getSetting('last_synced_remote_revision');
    if (val != null) {
      return int.tryParse(val) ?? 0;
    }
    return 0;
  }

  Future<String> getClientId() async {
    var id = await getSetting('client_id');
    if (id == null || id.isEmpty) {
      final now = DateTime.now();
      id = 'client_${now.millisecondsSinceEpoch}_${now.microsecond}';
      await setSetting('client_id', id);
    }
    return id;
  }

  Future<bool> hasUnsyncedChanges() async {
    final current = await getChangeCounter();
    final synced = await getLastSyncedCounter();
    return current > synced;
  }

  Future<void> recordSuccessfulSync({
    required int syncedRevision,
    required int syncedCounter,
  }) async {
    await setSetting('last_synced_counter', syncedCounter.toString());
    await setSetting('last_synced_remote_revision', syncedRevision.toString());
  }

  Future<String?> getSetting(String key) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return results.first['value'] as String?;
      }
      return null;
    } catch (e, stack) {
      developer.log(
        'Error getting setting $key: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
      return null;
    }
  }

  Future<void> setSetting(String key, String value) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, stack) {
      developer.log(
        'Error saving setting $key: $e',
        error: e,
        stackTrace: stack,
        name: 'BookRepository',
      );
    }
  }
}
