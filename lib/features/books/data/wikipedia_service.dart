import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class AuthorWikiInfo {
  final String authorName;
  final String pageTitle;
  final String extract;
  final String? thumbnailUrl;
  final String pageUrl;

  const AuthorWikiInfo({
    required this.authorName,
    required this.pageTitle,
    required this.extract,
    this.thumbnailUrl,
    required this.pageUrl,
  });
}

class WikipediaService {
  final http.Client _client;

  WikipediaService({http.Client? client}) : _client = client ?? http.Client();

  Future<AuthorWikiInfo?> fetchAuthorInfo(String authorName) async {
    final cleanName = authorName.trim();
    if (cleanName.isEmpty) return null;

    try {
      // 1. Recherche du titre de page le plus pertinent
      final searchUri = Uri.https('fr.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'list': 'search',
        'srsearch': cleanName,
        'utf8': '1',
        'format': 'json',
        'srlimit': '1',
      });

      final searchResponse = await _client
          .get(
            searchUri,
            headers: {'User-Agent': 'BiblioD/1.0 (bibliod-app@example.com)'},
          )
          .timeout(const Duration(seconds: 8));

      if (searchResponse.statusCode != 200) return null;

      final searchData =
          jsonDecode(searchResponse.body) as Map<String, dynamic>?;
      if (searchData == null) return null;

      final queryObj = searchData['query'] as Map<String, dynamic>?;
      final searchResults = queryObj?['search'] as List<dynamic>?;
      if (searchResults == null || searchResults.isEmpty) return null;

      final firstMatch = searchResults.first as Map<String, dynamic>?;
      final pageTitle = firstMatch?['title'] as String?;
      if (pageTitle == null || pageTitle.isEmpty) return null;

      // 2. Récupération de l'extrait introductif et de l'image
      final detailUri = Uri.https('fr.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'prop': 'extracts|pageimages',
        'exintro': '1',
        'explaintext': '1',
        'piprop': 'thumbnail',
        'pithumbsize': '400',
        'titles': pageTitle,
        'format': 'json',
      });

      final detailResponse = await _client
          .get(
            detailUri,
            headers: {'User-Agent': 'BiblioD/1.0 (bibliod-app@example.com)'},
          )
          .timeout(const Duration(seconds: 8));

      if (detailResponse.statusCode != 200) return null;

      final detailData =
          jsonDecode(detailResponse.body) as Map<String, dynamic>?;
      final detailQuery = detailData?['query'] as Map<String, dynamic>?;
      final pages = detailQuery?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return null;

      final pageData = pages.values.first as Map<String, dynamic>?;
      if (pageData == null) return null;

      final extract =
          (pageData['extract'] as String?) ?? 'Aucun résumé disponible.';
      final thumbnailObj = pageData['thumbnail'] as Map<String, dynamic>?;
      final thumbnailUrl = thumbnailObj?['source'] as String?;
      final encodedTitle = Uri.encodeComponent(pageTitle.replaceAll(' ', '_'));
      final pageUrl = 'https://fr.wikipedia.org/wiki/$encodedTitle';

      return AuthorWikiInfo(
        authorName: cleanName,
        pageTitle: pageTitle,
        extract: extract,
        thumbnailUrl: thumbnailUrl,
        pageUrl: pageUrl,
      );
    } catch (e, stack) {
      developer.log(
        'Error querying French Wikipedia: $e',
        error: e,
        stackTrace: stack,
        name: 'WikipediaService',
      );
      return null;
    }
  }
}
