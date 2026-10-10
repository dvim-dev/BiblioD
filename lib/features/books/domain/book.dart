import 'package:bibliod/core/constants/app_constants.dart';

class Book {
  final int? id;
  final String title;
  final String authorLastName;
  final String authorFirstName;
  final int rating;
  final String? series;
  final double? seriesNumber;
  final String? genre;
  final String? isbn;
  final String format;
  final String? remarks;
  final String? publisher;
  final int? publicationYear;
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  late final String _searchIndex = _buildSearchIndex();

  Book({
    this.id,
    required this.title,
    required this.authorLastName,
    this.authorFirstName = '',
    this.rating = 0,
    this.series,
    this.seriesNumber,
    this.genre,
    this.isbn,
    this.format = AppConstants.formatPhysical,
    this.remarks,
    this.publisher,
    this.publicationYear,
    this.coverImagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  String _buildSearchIndex() {
    final cleanIsbn = isbn?.replaceAll('-', '') ?? '';
    return '$title $authorLastName $authorFirstName $format ${series ?? ""} ${genre ?? ""} $cleanIsbn ${remarks ?? ""} ${publisher ?? ""}'
        .toLowerCase();
  }

  String get authorFullName {
    final first = authorFirstName.trim();
    final last = authorLastName.trim();
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$last $first';
  }

  String get authorDisplayNatural {
    final first = authorFirstName.trim();
    final last = authorLastName.trim();
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  String get seriesDisplay {
    final s = series;
    if (s == null || s.trim().isEmpty) return '';
    final num = seriesNumber;
    if (num == null) return s;
    final numString = num % 1 == 0 ? num.toInt().toString() : num.toString();
    return '$s (T.$numString)';
  }

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    final cleanQuery = query.toLowerCase().trim().replaceAll('-', '');
    return _searchIndex.contains(cleanQuery);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author_last_name': authorLastName,
      'author_first_name': authorFirstName,
      'rating': rating,
      'series': series,
      'series_number': seriesNumber,
      'genre': genre,
      'isbn': isbn,
      'format': format,
      'remarks': remarks,
      'publisher': publisher,
      'publication_year': publicationYear,
      'cover_image_path': coverImagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      authorLastName: (map['author_last_name'] as String?) ?? '',
      authorFirstName: (map['author_first_name'] as String?) ?? '',
      rating: (map['rating'] as int?) ?? 0,
      series: map['series'] as String?,
      seriesNumber: (map['series_number'] as num?)?.toDouble(),
      genre: map['genre'] as String?,
      isbn: map['isbn'] as String?,
      format: (map['format'] as String?) ?? AppConstants.formatPhysical,
      remarks: map['remarks'] as String?,
      publisher: map['publisher'] as String?,
      publicationYear: map['publication_year'] as int?,
      coverImagePath: map['cover_image_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Book copyWith({
    int? id,
    String? title,
    String? authorLastName,
    String? authorFirstName,
    int? rating,
    String? series,
    double? seriesNumber,
    String? genre,
    String? isbn,
    String? format,
    String? remarks,
    String? publisher,
    int? publicationYear,
    String? coverImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      authorLastName: authorLastName ?? this.authorLastName,
      authorFirstName: authorFirstName ?? this.authorFirstName,
      rating: rating ?? this.rating,
      series: series ?? this.series,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      genre: genre ?? this.genre,
      isbn: isbn ?? this.isbn,
      format: format ?? this.format,
      remarks: remarks ?? this.remarks,
      publisher: publisher ?? this.publisher,
      publicationYear: publicationYear ?? this.publicationYear,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
