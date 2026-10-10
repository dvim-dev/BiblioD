import 'package:bibliod/core/constants/app_constants.dart';
import 'book.dart';

class BookStatistics {
  final int totalBooks;
  final int physicalBooks;
  final int digitalBooks;
  final int seriesCount;
  final double averageRating;
  final Map<String, int> genreDistribution;
  final Map<String, int> topAuthors;
  final Map<int, int> ratingDistribution;

  const BookStatistics({
    required this.totalBooks,
    required this.physicalBooks,
    required this.digitalBooks,
    required this.seriesCount,
    required this.averageRating,
    required this.genreDistribution,
    required this.topAuthors,
    required this.ratingDistribution,
  });

  factory BookStatistics.fromBooks(List<Book> books) {
    if (books.isEmpty) {
      return const BookStatistics(
        totalBooks: 0,
        physicalBooks: 0,
        digitalBooks: 0,
        seriesCount: 0,
        averageRating: 0.0,
        genreDistribution: {},
        topAuthors: {},
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }

    int physical = 0;
    int digital = 0;
    int ratedBooksCount = 0;
    int totalRatingScore = 0;
    final seriesSet = <String>{};
    final genres = <String, int>{};
    final authors = <String, int>{};
    final ratings = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (final book in books) {
      if (book.format == AppConstants.formatPhysical) {
        physical++;
      } else {
        digital++;
      }

      final s = book.series?.trim();
      if (s != null && s.isNotEmpty) {
        seriesSet.add(s.toLowerCase());
      }

      final g = book.genre?.trim();
      if (g != null && g.isNotEmpty) {
        genres[g] = (genres[g] ?? 0) + 1;
      }

      final authorName = book.authorFullName.trim();
      if (authorName.isNotEmpty) {
        authors[authorName] = (authors[authorName] ?? 0) + 1;
      }

      if (book.rating > 0 && book.rating <= 5) {
        ratings[book.rating] = (ratings[book.rating] ?? 0) + 1;
        totalRatingScore += book.rating;
        ratedBooksCount++;
      }
    }

    final avgRating = ratedBooksCount > 0
        ? totalRatingScore / ratedBooksCount
        : 0.0;

    return BookStatistics(
      totalBooks: books.length,
      physicalBooks: physical,
      digitalBooks: digital,
      seriesCount: seriesSet.length,
      averageRating: avgRating,
      genreDistribution: genres,
      topAuthors: authors,
      ratingDistribution: ratings,
    );
  }
}
