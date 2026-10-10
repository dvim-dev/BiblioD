import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:bibliod/features/books/domain/book.dart';

class CsvExportService {
  String generateCsvString(List<Book> books, {String fieldDelimiter = ';'}) {
    final buffer = StringBuffer();

    // UTF-8 BOM pour assurer une ouverture sans faille dans Excel et Calc
    buffer.write('\uFEFF');

    final headers = [
      'Titre',
      "Nom de l'auteur",
      "Prénom de l'auteur",
      'Appréciation',
      'Série',
      'Numéro dans la série',
      'Genre',
      'ISBN',
      'Support',
      'Éditeur',
      'Année de parution',
      'Remarques',
    ];

    buffer.writeln(headers.map(_escapeField).join(fieldDelimiter));

    for (final book in books) {
      final num = book.seriesNumber;
      final seriesNumStr = num != null
          ? (num % 1 == 0 ? num.toInt().toString() : num.toString())
          : '';

      final row = [
        book.title,
        book.authorLastName,
        book.authorFirstName,
        book.rating > 0 ? book.rating.toString() : '',
        book.series ?? '',
        seriesNumStr,
        book.genre ?? '',
        book.isbn ?? '',
        book.format,
        book.publisher ?? '',
        book.publicationYear != null ? book.publicationYear.toString() : '',
        book.remarks ?? '',
      ];

      buffer.writeln(row.map(_escapeField).join(fieldDelimiter));
    }

    return buffer.toString();
  }

  Future<bool> exportToFile(List<Book> books, String targetFilePath) async {
    try {
      final csvData = generateCsvString(books);
      final file = File(targetFilePath);
      await file.writeAsString(csvData, encoding: utf8);
      developer.log(
        'Exported ${books.length} books to $targetFilePath',
        name: 'CsvExportService',
      );
      return true;
    } catch (e, stack) {
      developer.log(
        'Error exporting books to CSV: $e',
        error: e,
        stackTrace: stack,
        name: 'CsvExportService',
      );
      return false;
    }
  }

  String _escapeField(String field) {
    if (field.contains(';') ||
        field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
