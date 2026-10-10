import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:bibliod/core/constants/app_constants.dart';
import 'package:bibliod/features/books/domain/book.dart';

class CsvImportResult {
  final List<Book> books;
  final int totalRows;
  final List<String> warnings;

  const CsvImportResult({
    required this.books,
    required this.totalRows,
    required this.warnings,
  });
}

class CsvService {
  Future<CsvImportResult> parseCsvFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const CsvImportResult(
          books: [],
          totalRows: 0,
          warnings: ['Fichier introuvable.'],
        );
      }

      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      return parseCsvString(content);
    } catch (e, stack) {
      developer.log(
        'Error reading CSV file: $e',
        error: e,
        stackTrace: stack,
        name: 'CsvService',
      );
      return CsvImportResult(
        books: [],
        totalRows: 0,
        warnings: ['Erreur lors de la lecture du fichier CSV: $e'],
      );
    }
  }

  CsvImportResult parseCsvString(String csvContent) {
    if (csvContent.trim().isEmpty) {
      return const CsvImportResult(
        books: [],
        totalRows: 0,
        warnings: ['Le fichier est vide.'],
      );
    }

    // Détecter le séparateur
    final firstLine = csvContent.split(RegExp(r'\r?\n')).first;
    final commaCount = ','.allMatches(firstLine).length;
    final semicolonCount = ';'.allMatches(firstLine).length;
    final tabCount = '\t'.allMatches(firstLine).length;

    String fieldDelimiter = ',';
    if (semicolonCount > commaCount && semicolonCount > tabCount) {
      fieldDelimiter = ';';
    } else if (tabCount > commaCount && tabCount > semicolonCount) {
      fieldDelimiter = '\t';
    }

    final decoder = CsvDecoder(
      fieldDelimiter: fieldDelimiter,
      dynamicTyping: false,
      skipEmptyLines: true,
    );

    final List<List<dynamic>> rows = decoder.convert(csvContent);
    if (rows.isEmpty) {
      return const CsvImportResult(
        books: [],
        totalRows: 0,
        warnings: ['Aucune donnée trouvée.'],
      );
    }

    final rawHeaders = rows.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList();
    final colMap = _resolveColumnIndices(rawHeaders);

    final books = <Book>[];
    final warnings = <String>[];
    final now = DateTime.now();

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty ||
          (row.length == 1 && row.first.toString().trim().isEmpty)) {
        continue;
      }

      String getColValue(int? index) {
        if (index == null || index < 0 || index >= row.length) return '';
        return row[index].toString().trim();
      }

      final title = getColValue(colMap['title']);
      var lastName = getColValue(colMap['authorLastName']);
      var firstName = getColValue(colMap['authorFirstName']);

      if (lastName.isEmpty && colMap['authorFull'] != null) {
        final full = getColValue(colMap['authorFull']);
        final split = _splitAuthorName(full);
        lastName = split.lastName;
        firstName = split.firstName;
      }

      if (title.isEmpty && lastName.isEmpty) {
        continue;
      }

      final rawRating = getColValue(colMap['rating']);
      final rating = int.tryParse(rawRating) ?? 0;

      final series = getColValue(colMap['series']);
      final rawSeriesNumber = getColValue(colMap['seriesNumber']);
      final seriesNumber = double.tryParse(
        rawSeriesNumber.replaceAll(',', '.'),
      );

      final genre = getColValue(colMap['genre']);
      final isbn = getColValue(colMap['isbn']);
      final rawFormat = getColValue(colMap['format']).toLowerCase();
      final format =
          rawFormat.contains('num') ||
              rawFormat.contains('ebook') ||
              rawFormat.contains('pdf')
          ? AppConstants.formatDigital
          : AppConstants.formatPhysical;

      final remarks = getColValue(colMap['remarks']);
      final publisher = getColValue(colMap['publisher']);
      final rawYear = getColValue(colMap['year']);
      final year = int.tryParse(rawYear);

      books.add(
        Book(
          title: title.isNotEmpty ? title : 'Sans titre',
          authorLastName: lastName.isNotEmpty ? lastName : 'Inconnu',
          authorFirstName: firstName,
          rating: rating.clamp(0, 5),
          series: series.isNotEmpty ? series : null,
          seriesNumber: seriesNumber,
          genre: genre.isNotEmpty ? genre : null,
          isbn: isbn.isNotEmpty ? isbn : null,
          format: format,
          remarks: remarks.isNotEmpty ? remarks : null,
          publisher: publisher.isNotEmpty ? publisher : null,
          publicationYear: year,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return CsvImportResult(
      books: books,
      totalRows: rows.length - 1,
      warnings: warnings,
    );
  }

  Map<String, int?> _resolveColumnIndices(List<String> headers) {
    int? findHeader(List<String> candidates) {
      for (var i = 0; i < headers.length; i++) {
        final h = headers[i];
        for (final candidate in candidates) {
          if (h == candidate || h.contains(candidate)) {
            return i;
          }
        }
      }
      return null;
    }

    return {
      'title': findHeader(['titre', 'title', 'nom du livre', 'livre']),
      'authorLastName': findHeader([
        "nom de l'auteur",
        'nom auteur',
        'nom de famille',
      ]),
      'authorFirstName': findHeader(["prénom de l'auteur", 'prenom', 'prénom']),
      'authorFull': findHeader(['auteur', 'author', 'écrivain', 'ecrivain']),
      'rating': findHeader([
        'appréciation',
        'appreciation',
        'note',
        'rating',
        'avis',
        'score',
        'étoiles',
      ]),
      'series': findHeader([
        'série',
        'serie',
        'series',
        'cycle',
        'saga',
        'collection',
      ]),
      'seriesNumber': findHeader([
        'numéro dans la série',
        'numero dans la serie',
        'tome',
        'vol',
        'volume',
        'n°',
        'num',
      ]),
      'genre': findHeader([
        'genre',
        'catégorie',
        'categorie',
        'thème',
        'theme',
      ]),
      'isbn': findHeader(['isbn', 'ean', 'code barre']),
      'format': findHeader([
        'physique ou numérique',
        'support',
        'format',
        'type',
      ]),
      'remarks': findHeader([
        'remarques',
        'remarque',
        'commentaire',
        'commentaires',
        'notes',
        'description',
      ]),
      'publisher': findHeader(['éditeur', 'editeur', 'publisher', 'édition']),
      'year': findHeader(['année', 'annee', 'year', 'parution', 'date']),
    };
  }

  ({String lastName, String firstName}) _splitAuthorName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return (lastName: '', firstName: '');

    if (trimmed.contains(',')) {
      final parts = trimmed.split(',');
      return (
        lastName: parts.first.trim(),
        firstName: parts.sublist(1).join(' ').trim(),
      );
    }

    final tokens = trimmed.split(RegExp(r'\s+'));
    if (tokens.length == 1) {
      return (lastName: tokens.first, firstName: '');
    }

    return (
      lastName: tokens.last,
      firstName: tokens.sublist(0, tokens.length - 1).join(' '),
    );
  }
}
