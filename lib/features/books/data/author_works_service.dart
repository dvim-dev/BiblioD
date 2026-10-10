import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:bibliod/features/books/domain/book.dart';

class AuthorWork {
  final String title;
  final String? originalTitle;
  final int? firstPublishYear;
  final String? coverUrl;
  final String? workKey;
  final int editionCount;
  final bool isOwned;
  final Book? matchedBook;
  final String? isbn;

  const AuthorWork({
    required this.title,
    this.originalTitle,
    this.firstPublishYear,
    this.coverUrl,
    this.workKey,
    this.editionCount = 1,
    this.isOwned = false,
    this.matchedBook,
    this.isbn,
  });

  AuthorWork copyWith({
    String? title,
    String? originalTitle,
    int? firstPublishYear,
    String? coverUrl,
    String? workKey,
    int? editionCount,
    bool? isOwned,
    Book? matchedBook,
    String? isbn,
  }) {
    return AuthorWork(
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      firstPublishYear: firstPublishYear ?? this.firstPublishYear,
      coverUrl: coverUrl ?? this.coverUrl,
      workKey: workKey ?? this.workKey,
      editionCount: editionCount ?? this.editionCount,
      isOwned: isOwned ?? this.isOwned,
      matchedBook: matchedBook ?? this.matchedBook,
      isbn: isbn ?? this.isbn,
    );
  }
}

class _EditionTranslation {
  final String title;
  final String? coverUrl;
  final String? isbn;
  const _EditionTranslation({required this.title, this.coverUrl, this.isbn});
}

class AuthorWorksService {
  final http.Client _client;
  static final Map<String, _EditionTranslation> _cache = {};

  AuthorWorksService({http.Client? client}) : _client = client ?? http.Client();

  static final RegExp _combiningMarksRegex = RegExp(r'[\u0300-\u036f]');
  static final RegExp _apostrophesRegex = RegExp(r"[’'‘ʻ`´]");
  static final RegExp _separatorsRegex = RegExp(r"[-–—‑_]");
  static final RegExp _nonAlphaNumRegex = RegExp(r'[^a-z0-9 ]');
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');
  static final RegExp _bracketsRegex = RegExp(r'\[.*?\]');
  static final RegExp _parenthesizedFormatsRegex = RegExp(
    r'\((?:roman|poche|grand format|tome \d+|vol\.? \d+|texte intégral)\)',
    caseSensitive: false,
  );

  static const _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ă': 'a',
    'ą': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ĕ': 'e',
    'ė': 'e',
    'ę': 'e',
    'ě': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ĭ': 'i',
    'į': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ŏ': 'o',
    'ő': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ũ': 'u',
    'ū': 'u',
    'ŭ': 'u',
    'ů': 'u',
    'ű': 'u',
    'ų': 'u',
    'ç': 'c',
    'ć': 'c',
    'ĉ': 'c',
    'ċ': 'c',
    'č': 'c',
    'ñ': 'n',
    'ń': 'n',
    'ņ': 'n',
    'ň': 'n',
    'ý': 'y',
    'ÿ': 'y',
    'ŷ': 'y',
    'œ': 'oe',
    'æ': 'ae',
    'ß': 'ss',
  };

  static const _prefixes = [
    'le ',
    'la ',
    'les ',
    'l ',
    'un ',
    'une ',
    'des ',
    'du ',
    'the ',
    'a ',
    'an ',
    'el ',
    'los ',
    'las ',
    'una ',
  ];

  static String normalizeTitle(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(_combiningMarksRegex, '');
    _accents.forEach((key, val) => s = s.replaceAll(key, val));
    s = s.replaceAll(_apostrophesRegex, ' ');
    s = s.replaceAll(_separatorsRegex, ' ');
    s = s.replaceAll(_nonAlphaNumRegex, ' ');
    s = s.replaceAll(_multiSpaceRegex, ' ').trim();

    for (final prefix in _prefixes) {
      if (s.startsWith(prefix)) {
        s = s.substring(prefix.length).trim();
        break;
      }
    }
    return s;
  }

  static String extractBaseTitle(String input) {
    var clean = input.replaceAll(_bracketsRegex, '');
    clean = clean.replaceAll(_parenthesizedFormatsRegex, '');
    clean = clean.split(':').first.split(' - ').first.split(' / ').first.trim();
    return clean.isNotEmpty ? clean : input;
  }

  static bool isTitleMatch(String title1, String title2) {
    final n1 = normalizeTitle(title1);
    final n2 = normalizeTitle(title2);
    if (n1.isEmpty || n2.isEmpty) return false;
    if (n1 == n2) return true;

    final b1 = normalizeTitle(extractBaseTitle(title1));
    final b2 = normalizeTitle(extractBaseTitle(title2));
    return b1.isNotEmpty && b2.isNotEmpty && b1 == b2;
  }

  static String normalizeAuthorName(String author) {
    var s = author.trim().toLowerCase();
    s = s.replaceAll(_combiningMarksRegex, '');
    _accents.forEach((key, val) => s = s.replaceAll(key, val));
    s = s.replaceAll(_apostrophesRegex, ' ');
    s = s.replaceAll(_separatorsRegex, ' ');
    s = s.replaceAll(_nonAlphaNumRegex, ' ');
    return s.replaceAll(_multiSpaceRegex, ' ').trim();
  }

  static bool isAuthorMatch(Book book, String? targetAuthor) {
    if (targetAuthor == null || targetAuthor.trim().isEmpty) return true;
    final bNorm = normalizeAuthorName(book.authorFullName);
    final tNorm = normalizeAuthorName(targetAuthor);
    if (tNorm.isEmpty || bNorm.isEmpty) return true;
    if (bNorm == tNorm) return true;

    final bWords = bNorm.split(' ').where((w) => w.isNotEmpty).toSet();
    final tWords = tNorm.split(' ').where((w) => w.isNotEmpty).toSet();
    return bWords.containsAll(tWords) || tWords.containsAll(bWords);
  }

  static Book? findMatchingBook(
    String workTitle,
    String? originalTitle,
    List<Book> existingBooks, {
    String? targetAuthorName,
  }) {
    for (final book in existingBooks) {
      if (!isAuthorMatch(book, targetAuthorName)) continue;
      if (isTitleMatch(book.title, workTitle)) return book;
      if (originalTitle != null && isTitleMatch(book.title, originalTitle)) {
        return book;
      }
    }
    return null;
  }

  Future<List<AuthorWork>> fetchAuthorWorks(
    String authorName, {
    String? language,
    List<Book> existingBooks = const [],
  }) async {
    final cleanName = authorName.trim();
    if (cleanName.isEmpty) return [];

    try {
      final uri = _buildSearchUri(cleanName, language);
      final response = await _client
          .get(
            uri,
            headers: {'User-Agent': 'BiblioD/1.0 (bibliod-app@example.com)'},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        developer.log('Open Library query failed: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final docs = data?['docs'] as List<dynamic>?;
      if (docs == null) return [];

      return _processDocs(docs, existingBooks, cleanName);
    } catch (e, stack) {
      developer.log('Error fetching works: $e', error: e, stackTrace: stack);
      return [];
    }
  }

  Uri _buildSearchUri(String authorName, String? language) {
    final queryParams = <String, String>{
      'author': authorName,
      'fields':
          'title,first_publish_year,key,cover_i,edition_count,language,isbn',
      'limit': '100',
      'sort': 'editions',
    };
    if (language != null && language.isNotEmpty && language != 'all') {
      queryParams['language'] = language;
    }
    return Uri.https('openlibrary.org', '/search.json', queryParams);
  }

  List<AuthorWork> _processDocs(
    List<dynamic> docs,
    List<Book> existingBooks, [
    String? authorName,
  ]) {
    final seenTitles = <String>{};
    final works = <AuthorWork>[];

    for (final item in docs) {
      if (item is! Map<String, dynamic>) continue;
      final title = item['title'] as String?;
      if (title == null || title.trim().isEmpty) continue;

      final normalized = normalizeTitle(title);
      if (seenTitles.contains(normalized)) continue;
      seenTitles.add(normalized);

      final matchedBook = findMatchingBook(
        title,
        null,
        existingBooks,
        targetAuthorName: authorName,
      );
      works.add(_createAuthorWorkFromDoc(item, title, matchedBook));
    }
    return works;
  }

  String? _extractBestIsbn(Map<String, dynamic> item) {
    final isbns = item['isbn'];
    if (isbns is! List || isbns.isEmpty) return null;
    String? fallback;
    for (final raw in isbns) {
      final s = raw?.toString().replaceAll(RegExp(r'[^0-9X]'), '') ?? '';
      if (s.length == 13 && (s.startsWith('978') || s.startsWith('979'))) {
        return s;
      }
      if (fallback == null && (s.length == 10 || s.length == 13)) {
        fallback = s;
      }
    }
    return fallback;
  }

  AuthorWork _createAuthorWorkFromDoc(
    Map<String, dynamic> item,
    String title,
    Book? matchedBook,
  ) {
    final coverI = item['cover_i'] as int?;
    final coverUrl = coverI != null
        ? 'https://covers.openlibrary.org/b/id/$coverI-M.jpg'
        : null;

    return AuthorWork(
      title: title.trim(),
      firstPublishYear: item['first_publish_year'] as int?,
      coverUrl: coverUrl,
      workKey: item['key'] as String?,
      editionCount: (item['edition_count'] as int?) ?? 1,
      isOwned: matchedBook != null,
      matchedBook: matchedBook,
      isbn: _extractBestIsbn(item),
    );
  }

  Future<void> resolveTranslations({
    required List<AuthorWork> works,
    required String language,
    required List<Book> existingBooks,
    String? targetAuthorName,
    void Function(AuthorWork updatedWork)? onWorkUpdated,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (language == 'all' || language.isEmpty) return;
    int nextIndex = 0;
    int completed = 0;
    final total = works.length;

    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() == true) return;
        if (nextIndex >= works.length) return;
        final index = nextIndex++;
        final work = works[index];
        final updated = await _translateWork(
          work,
          language,
          existingBooks,
          targetAuthorName: targetAuthorName,
        );
        completed++;
        onProgress?.call(completed, total);
        if (updated != null && isCancelled?.call() != true) {
          onWorkUpdated?.call(updated);
        }
      }
    }

    const concurrency = 6;
    final workers = List.generate(concurrency, (_) => worker());
    await Future.wait(workers);
  }

  Future<AuthorWork?> _translateWork(
    AuthorWork work,
    String language,
    List<Book> existingBooks, {
    String? targetAuthorName,
  }) async {
    final key = work.workKey;
    if (key == null || key.isEmpty) return null;

    final translation = await _fetchSingleTranslation(key, language);
    if (translation == null) return null;

    final orig = work.originalTitle ?? work.title;
    final matched = findMatchingBook(
      translation.title,
      orig,
      existingBooks,
      targetAuthorName: targetAuthorName,
    );
    return work.copyWith(
      title: translation.title,
      originalTitle: orig,
      coverUrl: translation.coverUrl ?? work.coverUrl,
      isbn: translation.isbn ?? work.isbn,
      isOwned: matched != null,
      matchedBook: matched,
    );
  }

  Future<_EditionTranslation?> _fetchSingleTranslation(
    String workKey,
    String language,
  ) async {
    final cacheKey = '${workKey}_$language';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final cleanKey = workKey.startsWith('/') ? workKey : '/$workKey';
      final uri = Uri.https('openlibrary.org', '$cleanKey/editions.json', {
        'limit': '30',
      });
      final res = await _client
          .get(
            uri,
            headers: {'User-Agent': 'BiblioD/1.0 (bibliod-app@example.com)'},
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      final translation = _parseEditionTranslation(data, language);
      if (translation != null) _cache[cacheKey] = translation;
      return translation;
    } catch (_) {
      return null;
    }
  }

  _EditionTranslation? _parseEditionTranslation(
    Map<String, dynamic>? data,
    String language,
  ) {
    final entries = data?['entries'] as List<dynamic>?;
    if (entries == null) return null;

    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      if (!_hasLanguage(entry, language)) continue;

      final title = entry['title'] as String?;
      if (title == null || title.trim().isEmpty) continue;

      final cleanTitle = title.trim().replaceAll(RegExp(r'[\.\s]+$'), '');
      return _EditionTranslation(
        title: cleanTitle,
        coverUrl: _extractCoverUrl(entry),
        isbn: _extractIsbnFromEntry(entry),
      );
    }
    return null;
  }

  String? _extractIsbnFromEntry(Map<String, dynamic> entry) {
    final isbn13List = entry['isbn_13'];
    if (isbn13List is List && isbn13List.isNotEmpty) {
      final first = isbn13List.first?.toString().trim();
      if (first != null && first.isNotEmpty) return first;
    }
    final isbn10List = entry['isbn_10'];
    if (isbn10List is List && isbn10List.isNotEmpty) {
      final first = isbn10List.first?.toString().trim();
      if (first != null && first.isNotEmpty) return first;
    }
    return null;
  }

  bool _hasLanguage(Map<String, dynamic> entry, String language) {
    final languages = entry['languages'];
    if (languages is! List) return false;
    final target = '/languages/$language';
    for (final l in languages) {
      if (l is Map && l['key'] == target) return true;
      if (l is String && (l == target || l == language)) return true;
    }
    return false;
  }

  String? _extractCoverUrl(Map<String, dynamic> entry) {
    final covers = entry['covers'];
    if (covers is List && covers.isNotEmpty) {
      final id = covers.first;
      if (id is int && id > 0) {
        return 'https://covers.openlibrary.org/b/id/$id-M.jpg';
      }
    }
    return null;
  }

  Future<String?> fetchWorkIsbn(String workKey, String language) async {
    final translation = await _fetchSingleTranslation(workKey, language);
    if (translation?.isbn != null) return translation?.isbn;
    return null;
  }
}
