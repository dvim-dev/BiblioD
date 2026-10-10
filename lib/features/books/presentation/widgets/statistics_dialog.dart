import 'package:flutter/material.dart';
import '../../domain/book_statistics.dart';

class StatisticsDialog extends StatelessWidget {
  final BookStatistics stats;

  const StatisticsDialog({super.key, required this.stats});

  static void show(BuildContext context, BookStatistics stats) {
    showDialog(
      context: context,
      builder: (context) => StatisticsDialog(stats: stats),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: const Row(
        children: [
          Icon(Icons.query_stats_rounded),
          SizedBox(width: 10),
          Text('Statistiques de la bibliothèque'),
        ],
      ),
      content: SizedBox(
        width: 680,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(theme, isDark),
              const SizedBox(height: 20),
              _buildFormatDistribution(theme, isDark),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTopGenres(theme)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildTopAuthors(theme)),
                ],
              ),
              const SizedBox(height: 20),
              _buildRatingsDistribution(theme),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(ThemeData theme, bool isDark) {
    return Row(
      children: [
        _buildStatCard(
          'Total Livres',
          '${stats.totalBooks}',
          Icons.menu_book_rounded,
          theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          'Physiques',
          '${stats.physicalBooks}',
          Icons.book_rounded,
          Colors.indigo,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          'Numériques',
          '${stats.digitalBooks}',
          Icons.tablet_mac_rounded,
          Colors.teal,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          'Séries',
          '${stats.seriesCount}',
          Icons.collections_bookmark_rounded,
          Colors.deepOrange,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          'Note Moyenne',
          stats.averageRating > 0
              ? stats.averageRating.toStringAsFixed(1)
              : '-',
          Icons.star_rounded,
          const Color(0xFFD49B35),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatDistribution(ThemeData theme, bool isDark) {
    final total = stats.totalBooks;
    final physicalRatio = total > 0 ? stats.physicalBooks / total : 0.0;
    final digitalRatio = total > 0 ? stats.digitalBooks / total : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition Physique / Numérique',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    if (physicalRatio > 0)
                      Expanded(
                        flex: (physicalRatio * 1000).toInt(),
                        child: Container(color: Colors.indigo),
                      ),
                    if (digitalRatio > 0)
                      Expanded(
                        flex: (digitalRatio * 1000).toInt(),
                        child: Container(color: Colors.teal),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, color: Colors.indigo),
                    const SizedBox(width: 6),
                    Text(
                      'Physique : ${stats.physicalBooks} (${(physicalRatio * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 10, height: 10, color: Colors.teal),
                    const SizedBox(width: 6),
                    Text(
                      'Numérique : ${stats.digitalBooks} (${(digitalRatio * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopGenres(ThemeData theme) {
    final sortedGenres = stats.genreDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topGenres = sortedGenres.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genres fréquents',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (topGenres.isEmpty)
              const Text(
                'Aucun genre renseigné',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              )
            else
              ...topGenres.map((g) {
                final ratio = stats.totalBooks > 0
                    ? g.value / stats.totalBooks
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              g.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${g.value}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAuthors(ThemeData theme) {
    final sortedAuthors = stats.topAuthors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topAuthors = sortedAuthors.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Auteurs les plus présents',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (topAuthors.isEmpty)
              const Text(
                'Aucun auteur renseigné',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              )
            else
              ...topAuthors.map((a) {
                final ratio = stats.totalBooks > 0
                    ? a.value / stats.totalBooks
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              a.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${a.value}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsDistribution(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribution des appréciations',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            ...[5, 4, 3, 2, 1].map((star) {
              final count = stats.ratingDistribution[star] ?? 0;
              final ratio = stats.totalBooks > 0
                  ? count / stats.totalBooks
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 75,
                      child: Row(
                        children: [
                          Text(
                            '$star',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFD49B35),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: const Color(0xFFD49B35),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 35,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
