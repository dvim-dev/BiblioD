class AppConstants {
  static const String appTitle = 'BiblioD';
  static const String dbName = 'bibliod.db';
  static const String coversFolder = 'covers';

  // Support / Format
  static const String formatPhysical = 'Physique';
  static const String formatDigital = 'Numérique';
  static const List<String> bookFormats = [formatPhysical, formatDigital];

  // Colonnes disponibles
  static const String colAuthorLastName = 'author_last_name';
  static const String colAuthorFirstName = 'author_first_name';
  static const String colTitle = 'title';
  static const String colRating = 'rating';
  static const String colSeries = 'series';
  static const String colSeriesNumber = 'series_number';
  static const String colGenre = 'genre';
  static const String colIsbn = 'isbn';
  static const String colFormat = 'format';
  static const String colRemarks = 'remarks';

  static const Map<String, String> columnLabels = {
    colAuthorLastName: 'Nom auteur',
    colAuthorFirstName: 'Prénom auteur',
    colTitle: 'Titre',
    colRating: 'Appréciation',
    colSeries: 'Série',
    colSeriesNumber: 'N° Série',
    colGenre: 'Genre',
    colIsbn: 'ISBN',
    colFormat: 'Support',
    colRemarks: 'Remarques',
  };

  static const List<String> defaultVisibleColumns = [
    colAuthorLastName,
    colAuthorFirstName,
    colTitle,
    colRating,
    colIsbn,
    colFormat,
    colRemarks,
  ];
}
