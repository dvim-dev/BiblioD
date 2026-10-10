import 'package:flutter/foundation.dart';
import 'package:bibliod/core/constants/app_constants.dart';
import 'package:bibliod/features/books/data/book_repository.dart';
import 'package:bibliod/features/books/domain/author_item.dart';
import 'package:bibliod/features/books/domain/book.dart';
import 'package:bibliod/features/books/domain/book_statistics.dart';

class BookNotifier extends ChangeNotifier {
  final BookRepository _repository;

  List<Book> _allBooks = [];
  List<Book> _filteredBooks = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortColumn = AppConstants.colAuthorLastName;
  bool _sortAscending = true;
  String _lastRegisteredFormat = AppConstants.formatPhysical;

  BookNotifier({required BookRepository repository}) : _repository = repository;

  BookRepository get repository => _repository;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;
  String get lastRegisteredFormat => _lastRegisteredFormat;
  int get totalCount => _allBooks.length;

  List<Book> get books => _filteredBooks;

  BookStatistics get statistics => BookStatistics.fromBooks(_allBooks);

  List<AuthorItem> get distinctAuthors {
    final seen = <String>{};
    final list = <AuthorItem>[];

    for (final book in _allBooks) {
      final last = book.authorLastName.trim();
      final first = book.authorFirstName.trim();
      if (last.isEmpty && first.isEmpty) continue;

      final key = '${last.toLowerCase()}||${first.toLowerCase()}';
      if (seen.add(key)) {
        list.add(AuthorItem(lastName: last, firstName: first));
      }
    }

    list.sort((a, b) {
      final cmp = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
      if (cmp != 0) return cmp;
      return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
    });

    return list;
  }

  Future<void> loadBooks() async {
    _isLoading = true;
    notifyListeners();

    _allBooks = await _repository.getAllBooks();
    final lastBook = await _repository.getLastRegisteredBook();
    if (lastBook != null) {
      _lastRegisteredFormat = lastBook.format;
    }
    _recomputeFilteredBooks();
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _recomputeFilteredBooks();
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _recomputeFilteredBooks();
    notifyListeners();
  }

  void sortBy(String columnKey) {
    if (_sortColumn == columnKey) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = columnKey;
      _sortAscending = true;
    }
    _recomputeFilteredBooks();
    notifyListeners();
  }

  void resetSort() {
    _sortColumn = AppConstants.colAuthorLastName;
    _sortAscending = true;
    _recomputeFilteredBooks();
    notifyListeners();
  }

  Future<bool> addBook(Book book) async {
    final id = await _repository.insertBook(book);
    if (id != null) {
      final newBook = book.copyWith(id: id);
      _allBooks.add(newBook);
      _lastRegisteredFormat = book.format;
      _recomputeFilteredBooks();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> updateBook(Book book) async {
    final success = await _repository.updateBook(book);
    if (success) {
      final index = _allBooks.indexWhere((b) => b.id == book.id);
      if (index != -1) {
        _allBooks[index] = book;
        _recomputeFilteredBooks();
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  Future<bool> updateBookRating(Book book, int newRating) async {
    final clamped = newRating.clamp(0, 5);
    if (book.rating == clamped) return true;
    final updated = book.copyWith(rating: clamped, updatedAt: DateTime.now());
    return updateBook(updated);
  }

  Future<bool> deleteBook(int id) async {
    final success = await _repository.deleteBook(id);
    if (success) {
      _allBooks.removeWhere((b) => b.id == id);
      _recomputeFilteredBooks();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<int> importBooks(List<Book> newBooks) async {
    if (newBooks.isEmpty) return 0;
    _isLoading = true;
    notifyListeners();

    final inserted = await _repository.batchInsertBooks(newBooks);
    _allBooks = await _repository.getAllBooks();
    final last = newBooks.lastOrNull;
    if (last != null) {
      _lastRegisteredFormat = last.format;
    }
    _recomputeFilteredBooks();
    _isLoading = false;
    notifyListeners();
    return inserted;
  }

  void _recomputeFilteredBooks() {
    final query = _searchQuery.trim().toLowerCase();
    final list = query.isEmpty
        ? List<Book>.from(_allBooks)
        : _allBooks.where((b) => b.matchesQuery(query)).toList();

    _sortBooksList(list);
    _filteredBooks = list;
  }

  void _sortBooksList(List<Book> list) {
    list.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case AppConstants.colTitle:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case AppConstants.colAuthorFirstName:
          cmp = a.authorFirstName.toLowerCase().compareTo(
            b.authorFirstName.toLowerCase(),
          );
          if (cmp == 0) {
            cmp = a.authorLastName.toLowerCase().compareTo(
              b.authorLastName.toLowerCase(),
            );
          }
          break;
        case AppConstants.colRating:
          cmp = a.rating.compareTo(b.rating);
          break;
        case AppConstants.colSeries:
          final sa = a.series ?? '';
          final sb = b.series ?? '';
          cmp = sa.toLowerCase().compareTo(sb.toLowerCase());
          if (cmp == 0) {
            final na = a.seriesNumber ?? 0.0;
            final nb = b.seriesNumber ?? 0.0;
            cmp = na.compareTo(nb);
          }
          break;
        case AppConstants.colSeriesNumber:
          final na = a.seriesNumber ?? 0.0;
          final nb = b.seriesNumber ?? 0.0;
          cmp = na.compareTo(nb);
          break;
        case AppConstants.colGenre:
          final ga = a.genre ?? '';
          final gb = b.genre ?? '';
          cmp = ga.toLowerCase().compareTo(gb.toLowerCase());
          break;
        case AppConstants.colIsbn:
          final ia = a.isbn ?? '';
          final ib = b.isbn ?? '';
          cmp = ia.compareTo(ib);
          break;
        case AppConstants.colFormat:
          cmp = a.format.compareTo(b.format);
          break;
        case AppConstants.colRemarks:
          final ra = a.remarks ?? '';
          final rb = b.remarks ?? '';
          cmp = ra.toLowerCase().compareTo(rb.toLowerCase());
          break;
        case AppConstants.colAuthorLastName:
        default:
          cmp = a.authorLastName.toLowerCase().compareTo(
            b.authorLastName.toLowerCase(),
          );
          if (cmp == 0) {
            cmp = a.authorFirstName.toLowerCase().compareTo(
              b.authorFirstName.toLowerCase(),
            );
            if (cmp == 0) {
              cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
            }
          }
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }
}
