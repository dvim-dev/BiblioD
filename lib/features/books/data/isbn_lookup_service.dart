import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'cover_storage_service.dart';

class IsbnLookupResult {
  final String title;
  final String authorLastName;
  final String authorFirstName;
  final String? publisher;
  final int? publicationYear;
  final String? series;
  final double? seriesNumber;
  final String? genre;
  final String? remarks;
  final String? coverImagePath;

  const IsbnLookupResult({
    required this.title,
    required this.authorLastName,
    required this.authorFirstName,
    this.publisher,
    this.publicationYear,
    this.series,
    this.seriesNumber,
    this.genre,
    this.remarks,
    this.coverImagePath,
  });

  IsbnLookupResult copyWith({
    String? title,
    String? authorLastName,
    String? authorFirstName,
    String? publisher,
    int? publicationYear,
    String? series,
    double? seriesNumber,
    String? genre,
    String? remarks,
    String? coverImagePath,
  }) {
    return IsbnLookupResult(
      title: title ?? this.title,
      authorLastName: authorLastName ?? this.authorLastName,
      authorFirstName: authorFirstName ?? this.authorFirstName,
      publisher: publisher ?? this.publisher,
      publicationYear: publicationYear ?? this.publicationYear,
      series: series ?? this.series,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      genre: genre ?? this.genre,
      remarks: remarks ?? this.remarks,
      coverImagePath: coverImagePath ?? this.coverImagePath,
    );
  }
}

class IsbnLookupService {
  final http.Client _client;
  final CoverStorageService _coverStorage;

  IsbnLookupService({http.Client? client, CoverStorageService? coverStorage})
    : _client = client ?? http.Client(),
      _coverStorage = coverStorage ?? CoverStorageService.instance;

  Future<IsbnLookupResult?> lookup(String rawIsbn) async {
    final cleanIsbn = rawIsbn
        .replaceAll(RegExp(r'[^0-9X]', caseSensitive: false), '')
        .trim();
    if (cleanIsbn.isEmpty) return null;

    developer.log(
      'Searching book metadata for ISBN: $cleanIsbn',
      name: 'IsbnLookupService',
    );

    IsbnLookupResult? result;

    // 1. Interroger la Bibliothèque nationale de France (BnF) - Référence absolue pour les livres francophones
    try {
      result = await _lookupBnf(cleanIsbn);
      if (result != null) {
        developer.log(
          'Book found on BnF: "${result.title}" by ${result.authorLastName}',
          name: 'IsbnLookupService',
        );
      }
    } catch (e) {
      developer.log('BnF lookup error: $e', name: 'IsbnLookupService');
    }

    // 2. Interroger Open Library (Search API avec User-Agent) si non trouvé
    if (result == null || result.title.isEmpty) {
      try {
        result = await _lookupOpenLibrarySearch(cleanIsbn);
        if (result != null) {
          developer.log(
            'Book found on Open Library: "${result.title}"',
            name: 'IsbnLookupService',
          );
        }
      } catch (e) {
        developer.log(
          'OpenLibrary lookup error: $e',
          name: 'IsbnLookupService',
        );
      }
    }

    // 3. Google Books en complément si quota disponible
    if (result == null || result.title.isEmpty) {
      try {
        final googleResult = await _lookupGoogleBooks(cleanIsbn);
        if (googleResult != null) {
          result = googleResult;
          developer.log(
            'Book found on Google Books: "${result.title}"',
            name: 'IsbnLookupService',
          );
        }
      } catch (e) {
        developer.log(
          'Google Books lookup error: $e',
          name: 'IsbnLookupService',
        );
      }
    }

    if (result == null) {
      return null;
    }

    // 4. Si la couverture n'est pas encore trouvée, tenter OpenLibrary Covers
    if (result.coverImagePath == null) {
      final coverPath = await _fetchOpenLibraryCover(cleanIsbn);
      if (coverPath != null) {
        result = result.copyWith(coverImagePath: coverPath);
      }
    }

    return result;
  }

  /// Recherche sur l'API SRU de la Bibliothèque nationale de France (BnF)
  Future<IsbnLookupResult?> _lookupBnf(String isbn) async {
    final uri = Uri.parse(
      'https://catalogue.bnf.fr/api/SRU?version=1.2&operation=searchRetrieve&query=bib.isbn%20all%20%22$isbn%22&recordSchema=dublincore',
    );

    final response = await _client
        .get(uri, headers: {'User-Agent': 'BiblioD/1.0 (bibliod@app.local)'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final document = XmlDocument.parse(response.body);
    final records = document.findAllElements('srw:record');
    if (records.isEmpty) return null;

    final record = records.first;
    final dcElements = record.findAllElements('oai_dc:dc');
    if (dcElements.isEmpty) return null;

    final dc = dcElements.first;

    // Titre
    final rawTitle =
        dc.findElements('dc:title').firstOrNull?.innerText.trim() ?? '';
    final title = rawTitle.contains(' / ')
        ? rawTitle.split(' / ').first.trim()
        : rawTitle;

    // Auteur
    final rawCreator =
        dc.findElements('dc:creator').firstOrNull?.innerText.trim() ?? '';
    final parsedAuthor = _cleanAndSplitBnfCreator(rawCreator);

    // Éditeur
    final rawPublisher = dc
        .findElements('dc:publisher')
        .firstOrNull
        ?.innerText
        .trim();
    String? publisher;
    if (rawPublisher != null && rawPublisher.isNotEmpty) {
      publisher = rawPublisher.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    }

    // Année de parution
    final rawDate = dc.findElements('dc:date').firstOrNull?.innerText.trim();
    int? year;
    if (rawDate != null) {
      final match = RegExp(r'\b(1[89]\d\d|20\d\d)\b').firstMatch(rawDate);
      if (match != null) {
        year = int.tryParse(match.group(0) ?? '');
      }
    }

    // Collection / Série
    String? series;
    double? seriesNumber;
    for (final desc in dc.findElements('dc:description')) {
      final text = desc.innerText;
      if (text.startsWith('Collection :') || text.startsWith('Collection:')) {
        final collectionName = text
            .replaceFirst(RegExp(r'Collection\s*:\s*'), '')
            .trim();
        if (collectionName.contains(';')) {
          final parts = collectionName.split(';');
          series = parts.first.trim();
          final numPart = parts.sublist(1).join(' ').trim();
          seriesNumber = double.tryParse(numPart);
        } else {
          series = collectionName;
        }
        break;
      }
    }

    return IsbnLookupResult(
      title: title,
      authorLastName: parsedAuthor.lastName,
      authorFirstName: parsedAuthor.firstName,
      publisher: publisher,
      publicationYear: year,
      series: series,
      seriesNumber: seriesNumber,
    );
  }

  /// Recherche via OpenLibrary Search API (requiert User-Agent)
  Future<IsbnLookupResult?> _lookupOpenLibrarySearch(String isbn) async {
    final uri = Uri.parse('https://openlibrary.org/search.json?isbn=$isbn');
    final response = await _client
        .get(uri, headers: {'User-Agent': 'BiblioD/1.0 (bibliod@app.local)'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final docs = data?['docs'] as List<dynamic>?;
    if (docs == null || docs.isEmpty) return null;

    final firstDoc = docs.first as Map<String, dynamic>?;
    if (firstDoc == null) return null;

    final title = (firstDoc['title'] as String?) ?? '';
    final authorNames =
        (firstDoc['author_name'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    var lastName = '';
    var firstName = '';
    if (authorNames.isNotEmpty) {
      final split = _splitAuthorName(authorNames.first);
      lastName = split.lastName;
      firstName = split.firstName;
    }

    final year = firstDoc['first_publish_year'] as int?;
    final publishers = (firstDoc['publisher'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final publisher = publishers != null && publishers.isNotEmpty
        ? publishers.first
        : null;

    return IsbnLookupResult(
      title: title,
      authorLastName: lastName,
      authorFirstName: firstName,
      publisher: publisher,
      publicationYear: year,
    );
  }

  /// Google Books API (traitement avec gestion des erreurs 429 quota)
  Future<IsbnLookupResult?> _lookupGoogleBooks(String isbn) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn',
    );
    final response = await _client
        .get(uri, headers: {'User-Agent': 'BiblioD/1.0'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      developer.log(
        'Google Books returned status ${response.statusCode}',
        name: 'IsbnLookupService',
      );
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) return null;

    final volumeInfo =
        (items.first as Map<String, dynamic>?)?['volumeInfo']
            as Map<String, dynamic>?;
    if (volumeInfo == null) return null;

    final title = (volumeInfo['title'] as String?) ?? '';
    final authorsList =
        (volumeInfo['authors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    var lastName = '';
    var firstName = '';
    if (authorsList.isNotEmpty) {
      final parsed = _splitAuthorName(authorsList.first);
      lastName = parsed.lastName;
      firstName = parsed.firstName;
    }

    final publisher = volumeInfo['publisher'] as String?;
    final publishedDate = volumeInfo['publishedDate'] as String?;
    int? year;
    if (publishedDate != null && publishedDate.length >= 4) {
      year = int.tryParse(publishedDate.substring(0, 4));
    }

    final categories =
        (volumeInfo['categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final genre = categories.isNotEmpty ? categories.first : null;
    final description = volumeInfo['description'] as String?;

    return IsbnLookupResult(
      title: title,
      authorLastName: lastName,
      authorFirstName: firstName,
      publisher: publisher,
      publicationYear: year,
      genre: genre,
      remarks: description,
    );
  }

  /// Télécharge la couverture depuis OpenLibrary Covers
  Future<String?> _fetchOpenLibraryCover(String isbn) async {
    try {
      final coverUrl =
          'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg?default=false';
      final response = await _client
          .get(
            Uri.parse(coverUrl),
            headers: {'User-Agent': 'BiblioD/1.0 (bibliod@app.local)'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.length > 500) {
        return await _coverStorage.saveCoverBytes(response.bodyBytes);
      }
    } catch (e) {
      developer.log(
        'Could not fetch OpenLibrary cover: $e',
        name: 'IsbnLookupService',
      );
    }
    return null;
  }

  /// Nettoie les chaînes d'auteurs de la BnF du type "Arnaud, André (1923-2015). Auteur du texte"
  ({String lastName, String firstName}) _cleanAndSplitBnfCreator(
    String rawCreator,
  ) {
    if (rawCreator.isEmpty) return (lastName: '', firstName: '');

    var cleaned = rawCreator
        .replaceAll(RegExp(r'\([^)]*\)'), '') // Supprime les dates (1923-2015)
        .replaceAll(
          RegExp(r'\.\s*Auteur.*', caseSensitive: false),
          '',
        ) // Supprime ". Auteur du texte"
        .trim();

    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      return (
        lastName: parts.first.trim(),
        firstName: parts.sublist(1).join(' ').trim(),
      );
    }

    return _splitAuthorName(cleaned);
  }

  ({String lastName, String firstName}) _splitAuthorName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return (lastName: '', firstName: '');

    if (trimmed.contains(',')) {
      final parts = trimmed.split(',');
      final last = parts.first.trim();
      final first = parts.sublist(1).join(' ').trim();
      return (lastName: last, firstName: first);
    }

    final tokens = trimmed.split(RegExp(r'\s+'));
    if (tokens.length == 1) {
      return (lastName: tokens.first, firstName: '');
    }

    final lastName = tokens.last;
    final firstName = tokens.sublist(0, tokens.length - 1).join(' ');
    return (lastName: lastName, firstName: firstName);
  }
}
