import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bibliod/core/constants/app_constants.dart';
import 'package:bibliod/features/books/data/author_works_service.dart';
import 'package:bibliod/features/books/data/csv_export_service.dart';
import 'package:bibliod/features/books/data/csv_service.dart';
import 'package:bibliod/features/books/data/book_repository.dart';
import 'package:bibliod/features/books/data/isbn_lookup_service.dart';
import 'package:bibliod/features/books/domain/author_item.dart';
import 'package:bibliod/features/books/domain/book.dart';
import 'package:bibliod/features/books/domain/book_statistics.dart';
import 'package:bibliod/core/storage/storage_path_service.dart';
import 'package:bibliod/features/settings/data/settings_repository.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';
import 'package:bibliod/features/sync/domain/sync_manifest.dart';
import 'package:bibliod/features/sync/data/webdav_service.dart';

void main() {
  group('Book Entity Tests', () {
    test('matchesQuery checks title, authors, isbn, and series', () {
      final now = DateTime.now();
      final book = Book(
        title: 'Les Misérables',
        authorLastName: 'Hugo',
        authorFirstName: 'Victor',
        isbn: '9782070409228',
        genre: 'Classique',
        series: 'Œuvres Complètes',
        seriesNumber: 1,
        createdAt: now,
        updatedAt: now,
      );

      expect(book.matchesQuery('Hugo'), isTrue);
      expect(book.matchesQuery('victor'), isTrue);
      expect(book.matchesQuery('misérables'), isTrue);
      expect(book.matchesQuery('978-2070409228'), isTrue);
      expect(book.matchesQuery('oeuvres'), isFalse);
      expect(book.matchesQuery('Inconnu'), isFalse);
    });

    test('authorFullName formats correctly', () {
      final now = DateTime.now();
      final book1 = Book(
        title: 'Dune',
        authorLastName: 'Herbert',
        authorFirstName: 'Frank',
        createdAt: now,
        updatedAt: now,
      );
      expect(book1.authorFullName, 'Herbert Frank');
      expect(book1.authorDisplayNatural, 'Frank Herbert');

      final book2 = Book(
        title: 'Anonyme',
        authorLastName: 'Homère',
        authorFirstName: '',
        createdAt: now,
        updatedAt: now,
      );
      expect(book2.authorFullName, 'Homère');
    });

    test('toMap and fromMap preserves fields accurately', () {
      final now = DateTime.now();
      final original = Book(
        id: 42,
        title: 'Fondation',
        authorLastName: 'Asimov',
        authorFirstName: 'Isaac',
        rating: 5,
        series: 'Fondation',
        seriesNumber: 1.0,
        genre: 'Science-Fiction',
        isbn: '9782070415700',
        format: AppConstants.formatDigital,
        publisher: 'Denoël',
        publicationYear: 1951,
        remarks: 'Cycle majeur',
        createdAt: now,
        updatedAt: now,
      );

      final map = original.toMap();
      final parsed = Book.fromMap(map);

      expect(parsed.id, 42);
      expect(parsed.title, 'Fondation');
      expect(parsed.authorLastName, 'Asimov');
      expect(parsed.authorFirstName, 'Isaac');
      expect(parsed.rating, 5);
      expect(parsed.format, AppConstants.formatDigital);
      expect(parsed.seriesNumber, 1.0);
    });
  });

  group('BookStatistics Tests', () {
    test('Calculates aggregated values properly', () {
      final now = DateTime.now();
      final books = [
        Book(
          title: 'Book 1',
          authorLastName: 'Hugo',
          authorFirstName: 'Victor',
          rating: 4,
          genre: 'Roman',
          format: AppConstants.formatPhysical,
          createdAt: now,
          updatedAt: now,
        ),
        Book(
          title: 'Book 2',
          authorLastName: 'Hugo',
          authorFirstName: 'Victor',
          rating: 5,
          genre: 'Roman',
          format: AppConstants.formatPhysical,
          createdAt: now,
          updatedAt: now,
        ),
        Book(
          title: 'Book 3',
          authorLastName: 'Asimov',
          authorFirstName: 'Isaac',
          rating: 3,
          genre: 'SF',
          format: AppConstants.formatDigital,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final stats = BookStatistics.fromBooks(books);

      expect(stats.totalBooks, 3);
      expect(stats.physicalBooks, 2);
      expect(stats.digitalBooks, 1);
      expect(stats.genreDistribution['Roman'], 2);
      expect(stats.genreDistribution['SF'], 1);
      expect(stats.topAuthors['Hugo Victor'], 2);
      expect(stats.averageRating, 4.0);
    });
  });

  group('AppConstants Tests', () {
    test('defaultVisibleColumns excludes genre, series and series number', () {
      expect(
        AppConstants.defaultVisibleColumns.contains(AppConstants.colSeries),
        isFalse,
      );
      expect(
        AppConstants.defaultVisibleColumns.contains(
          AppConstants.colSeriesNumber,
        ),
        isFalse,
      );
      expect(
        AppConstants.defaultVisibleColumns.contains(AppConstants.colGenre),
        isFalse,
      );
      expect(
        AppConstants.defaultVisibleColumns.contains(AppConstants.colRating),
        isTrue,
      );
      expect(
        AppConstants.defaultVisibleColumns.contains(AppConstants.colFormat),
        isTrue,
      );
    });
  });

  group('CsvService Tests', () {
    test('Parses semicolon CSV with accented headers', () {
      const csvData =
          '''Titre;Nom de l'auteur;Prénom de l'auteur;Appréciation;Genre;Support
L'Étranger;Camus;Albert;4;Philosophie;Numérique
Le Petit Prince;Saint-Exupéry;Antoine de;5;Conte;Physique
''';

      final service = CsvService();
      final result = service.parseCsvString(csvData);

      expect(result.books.length, 2);
      expect(result.books[0].title, "L'Étranger");
      expect(result.books[0].authorLastName, 'Camus');
      expect(result.books[0].authorFirstName, 'Albert');
      expect(result.books[0].rating, 4);
      expect(result.books[0].format, AppConstants.formatDigital);

      expect(result.books[1].title, 'Le Petit Prince');
      expect(result.books[1].authorLastName, 'Saint-Exupéry');
      expect(result.books[1].authorFirstName, 'Antoine de');
      expect(result.books[1].rating, 5);
      expect(result.books[1].format, AppConstants.formatPhysical);
    });

    test('Defaults format to Physique when unspecified or empty', () {
      const csvData = '''Titre;Nom auteur;Support
Livre Sans Format;Auteur Test;
Livre Format Inconnu;Auteur Test 2;Autre Chose
''';

      final service = CsvService();
      final result = service.parseCsvString(csvData);

      expect(result.books.length, 2);
      expect(result.books[0].format, AppConstants.formatPhysical);
      expect(result.books[1].format, AppConstants.formatPhysical);
    });
  });

  group('CsvExportService Tests', () {
    test('Generates CSV string with headers, BOM and semicolon delimiters', () {
      final now = DateTime.now();
      final books = [
        Book(
          title: 'Dune',
          authorLastName: 'Herbert',
          authorFirstName: 'Frank',
          rating: 5,
          series: 'Cycle de Dune',
          seriesNumber: 1,
          genre: 'Science-Fiction',
          isbn: '9782266320481',
          format: AppConstants.formatPhysical,
          publisher: 'Pocket',
          publicationYear: 1965,
          remarks: 'Planète Arrakis',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final exportService = CsvExportService();
      final csv = exportService.generateCsvString(books);

      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(
        csv.contains('Titre;Nom de l\'auteur;Prénom de l\'auteur'),
        isTrue,
      );
      expect(
        csv.contains(
          'Dune;Herbert;Frank;5;Cycle de Dune;1;Science-Fiction;9782266320481;Physique;Pocket;1965;Planète Arrakis',
        ),
        isTrue,
      );
    });
  });

  group('AuthorItem Tests', () {
    test('displayName and equality work as expected', () {
      final a1 = const AuthorItem(lastName: 'Hugo', firstName: 'Victor');
      final a2 = const AuthorItem(lastName: 'hugo', firstName: 'victor');
      final a3 = const AuthorItem(lastName: 'Verne', firstName: 'Jules');

      expect(a1.displayName, 'Hugo Victor');
      expect(a1 == a2, isTrue);
      expect(a1 == a3, isFalse);
    });
  });

  group('IsbnLookupService Tests', () {
    test('Finds Pierres de sang for 2213604053', () async {
      final service = IsbnLookupService();
      final result = await service.lookup('2213604053');
      expect(result != null, isTrue);
      if (result != null) {
        expect(result.title.toLowerCase(), contains('pierres de sang'));
        expect(result.authorLastName.toLowerCase(), contains('arnaud'));
      }
    });

    test('Finds Transparences for 2253101125', () async {
      final service = IsbnLookupService();
      final result = await service.lookup('2253101125');
      expect(result != null, isTrue);
      if (result != null) {
        expect(result.title.toLowerCase(), contains('transparences'));
        expect(result.authorLastName.toLowerCase(), contains('ayerdhal'));
      }
    });
  });

  group('StoragePathService Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getApplicationSupportDirectory') {
                return '/tmp/mock_app_support';
              }
              return null;
            },
          );
    });

    test('Default paths and custom directory flag work as expected', () async {
      final service = StoragePathService.instance;
      final defaultDir = await service.getDefaultDataDirectory();
      expect(defaultDir.isNotEmpty, isTrue);
      expect(defaultDir, contains('bibliod'));

      final dbPath = await service.getDatabasePath();
      expect(dbPath.endsWith(AppConstants.dbName), isTrue);

      final coversPath = await service.getCoversDirectoryPath();
      expect(coversPath.endsWith(AppConstants.coversFolder), isTrue);

      final isCustom = await service.isCustomDirectory();
      expect(isCustom, isFalse);
    });
  });

  group('AuthorWorksService Tests', () {
    test(
      'normalizeTitle strips accents, articles, punctuation and lowercases',
      () {
        expect(AuthorWorksService.normalizeTitle("L'Étranger"), 'etranger');
        expect(
          AuthorWorksService.normalizeTitle('Les Misérables'),
          'miserables',
        );
        expect(
          AuthorWorksService.normalizeTitle('The Foundation Trilogy'),
          'foundation trilogy',
        );
        expect(
          AuthorWorksService.normalizeTitle('Brave New World!'),
          'brave new world',
        );
        // NFD decomposed Unicode (e + combining circumflex \u0302)
        expect(
          AuthorWorksService.normalizeTitle('Tempe\u0302te rouge'),
          'tempete rouge',
        );
        // NFC composed Unicode
        expect(
          AuthorWorksService.normalizeTitle('Tempête rouge'),
          'tempete rouge',
        );
        // Ligatures
        expect(AuthorWorksService.normalizeTitle("L'Œuvre"), 'oeuvre');
        // Curved apostrophes and Spanish accents
        expect(
          AuthorWorksService.normalizeTitle('Cien años de soledad'),
          'cien anos de soledad',
        );
      },
    );

    test('isTitleMatch matches identical or base titles', () {
      expect(AuthorWorksService.isTitleMatch("L'Étranger", 'Étranger'), isTrue);
      expect(
        AuthorWorksService.isTitleMatch("L’Étranger", "L'Etranger"),
        isTrue,
      );
      expect(
        AuthorWorksService.isTitleMatch(
          'Dune : Volume 1',
          'Dune - Les Chroniques',
        ),
        isTrue,
      );
      expect(
        AuthorWorksService.isTitleMatch('Fondation', 'Les Robots'),
        isFalse,
      );
      // NFD (Open Library) vs NFC (Local database)
      expect(
        AuthorWorksService.isTitleMatch('Tempe\u0302te rouge', 'Tempête rouge'),
        isTrue,
      );
      // Ligatures oe vs œ
      expect(AuthorWorksService.isTitleMatch("L'Œuvre", "L'Oeuvre"), isTrue);
      // BNF bracketed metadata tags and format parentheses
      expect(
        AuthorWorksService.isTitleMatch(
          'La Somme de toutes les peurs [Texte imprimé]',
          'La Somme de toutes les Peurs',
        ),
        isTrue,
      );
      expect(
        AuthorWorksService.isTitleMatch(
          'La Somme de toutes les peurs (roman)',
          'La Somme de toutes les Peurs',
        ),
        isTrue,
      );
      // Hyphens
      expect(
        AuthorWorksService.isTitleMatch(
          'Vingt-mille lieues sous les mers',
          'Vingt mille lieues sous les mers',
        ),
        isTrue,
      );
    });

    test(
      'fetchAuthorWorks parses Open Library response and identifies owned books',
      () async {
        final mockJson = jsonEncode({
          'docs': [
            {
              'title': 'Brave New World',
              'first_publish_year': 1932,
              'key': '/works/OL1',
              'edition_count': 100,
              'cover_i': 12345,
            },
            {
              'title': 'Island',
              'first_publish_year': 1962,
              'key': '/works/OL2',
              'edition_count': 50,
            },
            {
              'title': 'The Doors of Perception',
              'first_publish_year': 1954,
              'key': '/works/OL3',
              'edition_count': 40,
            },
          ],
        });

        final mockClient = MockClient((request) async {
          return http.Response(mockJson, 200);
        });

        final service = AuthorWorksService(client: mockClient);
        final now = DateTime.now();
        final existingBooks = [
          Book(
            id: 1,
            title: 'Brave New World',
            authorLastName: 'Huxley',
            authorFirstName: 'Aldous',
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final works = await service.fetchAuthorWorks(
          'Aldous Huxley',
          existingBooks: existingBooks,
        );

        expect(works.length, 3);
        expect(works[0].title, 'Brave New World');
        expect(works[0].isOwned, isTrue);
        expect(works[0].matchedBook != null, isTrue);
        expect(works[0].coverUrl, contains('12345'));

        expect(works[1].title, 'Island');
        expect(works[1].isOwned, isFalse);
        expect(works[1].matchedBook, isNull);

        expect(works[2].title, 'The Doors of Perception');
        expect(works[2].isOwned, isFalse);
      },
    );

    test('findMatchingBook matches by workTitle or originalTitle', () {
      final now = DateTime.now();
      final frenchBook = Book(
        id: 1,
        title: 'La Somme de toutes les Peurs',
        authorLastName: 'Clancy',
        authorFirstName: 'Tom',
        createdAt: now,
        updatedAt: now,
      );
      final englishBook = Book(
        id: 2,
        title: 'The Hunt for Red October',
        authorLastName: 'Clancy',
        authorFirstName: 'Tom',
        createdAt: now,
        updatedAt: now,
      );
      final books = [frenchBook, englishBook];

      // Matching with translated title
      final match1 = AuthorWorksService.findMatchingBook(
        'La somme de toutes les peurs',
        'The Sum of All Fears',
        books,
      );
      expect(match1 != null, isTrue);
      expect(match1?.title, 'La Somme de toutes les Peurs');

      // Matching when user owns English title but translated is French
      final match2 = AuthorWorksService.findMatchingBook(
        'Octobre Rouge',
        'The Hunt for Red October',
        books,
      );
      expect(match2 != null, isTrue);
      expect(match2?.title, 'The Hunt for Red October');

      // Non-matching
      final match3 = AuthorWorksService.findMatchingBook(
        'Danger immédiat',
        'Clear and Present Danger',
        books,
      );
      expect(match3, isNull);
    });

    test('findMatchingBook respects targetAuthorName and author accents', () {
      final now = DateTime.now();
      final clancyBook = Book(
        id: 1,
        title: 'Tempête rouge',
        authorLastName: 'Clancy',
        authorFirstName: 'Tom',
        createdAt: now,
        updatedAt: now,
      );
      final marquezBook = Book(
        id: 2,
        title: 'Cien anos de soledad',
        authorLastName: 'García Márquez',
        authorFirstName: 'Gabriel',
        createdAt: now,
        updatedAt: now,
      );
      final books = [clancyBook, marquezBook];

      // Target author matches with NFD title and composed author
      final match1 = AuthorWorksService.findMatchingBook(
        'Tempe\u0302te rouge',
        'Red Storm Rising',
        books,
        targetAuthorName: 'Tom Clancy',
      );
      expect(match1 != null, isTrue);
      expect(match1?.title, 'Tempête rouge');

      // Accented target author matching book with/without accents
      final match2 = AuthorWorksService.findMatchingBook(
        'Cien años de soledad',
        null,
        books,
        targetAuthorName: 'Gabriel Garcia Marquez',
      );
      expect(match2 != null, isTrue);
      expect(match2?.title, 'Cien anos de soledad');

      // Target author differs: prevents false positive match
      final match3 = AuthorWorksService.findMatchingBook(
        'Tempête rouge',
        null,
        books,
        targetAuthorName: 'Stephen King',
      );
      expect(match3, isNull);
    });

    test(
      'resolveTranslations translates work title and updates owned status',
      () async {
        final editionsJson = jsonEncode({
          'entries': [
            {
              'title': 'The Sum of All Fears',
              'languages': [
                {'key': '/languages/eng'},
              ],
            },
            {
              'title': 'La somme de toutes les peurs.',
              'languages': [
                {'key': '/languages/fre'},
              ],
              'covers': [99999],
              'isbn_13': ['9782226056153'],
            },
          ],
        });

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/works/OL448878W/editions.json')) {
            return http.Response(editionsJson, 200);
          }
          return http.Response('{"entries":[]}', 200);
        });

        final service = AuthorWorksService(client: mockClient);
        final now = DateTime.now();
        final existingBooks = [
          Book(
            id: 1,
            title: 'La Somme de toutes les Peurs',
            authorLastName: 'Clancy',
            authorFirstName: 'Tom',
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final works = [
          const AuthorWork(
            title: 'The Sum of All Fears',
            workKey: '/works/OL448878W',
            firstPublishYear: 1991,
            editionCount: 47,
            isOwned: false,
          ),
        ];

        AuthorWork? updatedWork;
        int? progressCompleted;
        int? progressTotal;

        await service.resolveTranslations(
          works: works,
          language: 'fre',
          existingBooks: existingBooks,
          onWorkUpdated: (w) => updatedWork = w,
          onProgress: (c, t) {
            progressCompleted = c;
            progressTotal = t;
          },
        );

        expect(updatedWork != null, isTrue);
        expect(updatedWork?.title, 'La somme de toutes les peurs');
        expect(updatedWork?.originalTitle, 'The Sum of All Fears');
        expect(updatedWork?.coverUrl, contains('99999'));
        expect(updatedWork?.isbn, '9782226056153');
        expect(updatedWork?.isOwned, isTrue);
        expect(updatedWork?.matchedBook?.title, 'La Somme de toutes les Peurs');
        expect(progressCompleted, 1);
        expect(progressTotal, 1);
      },
    );

    test('fetchWorkIsbn retrieves ISBN from edition', () async {
      final editionsJson = jsonEncode({
        'entries': [
          {
            'title': 'Octobre Rouge',
            'languages': [
              {'key': '/languages/fre'},
            ],
            'isbn_13': ['9782253051206'],
          },
        ],
      });
      final mockClient = MockClient((request) async {
        return http.Response(editionsJson, 200);
      });
      final service = AuthorWorksService(client: mockClient);
      final isbn = await service.fetchWorkIsbn('/works/OL159452W', 'fre');
      expect(isbn, '9782253051206');
    });

    test('fetchAuthorWorks passes language parameter in request URL', () async {
      String? requestedLanguage;
      final mockClient = MockClient((request) async {
        requestedLanguage = request.url.queryParameters['language'];
        return http.Response(jsonEncode({'docs': []}), 200);
      });

      final service = AuthorWorksService(client: mockClient);
      await service.fetchAuthorWorks('Cervantes', language: 'spa');

      expect(requestedLanguage, 'spa');
    });
  });

  group('SettingsNotifier Bibliography Language Tests', () {
    test('defaults to fre and persists updates across reloads', () async {
      final repo = _FakeSettingsBookRepo();
      final settingsRepo = SettingsRepository(bookRepository: repo);
      final notifier = SettingsNotifier(repository: settingsRepo);

      expect(notifier.bibliographyLanguage, 'fre');

      await notifier.setBibliographyLanguage('spa');
      expect(notifier.bibliographyLanguage, 'spa');

      final reloadedNotifier = SettingsNotifier(repository: settingsRepo);
      await reloadedNotifier.loadSettings();
      expect(reloadedNotifier.bibliographyLanguage, 'spa');
    });
  });

  group('SyncManifest Domain Tests', () {
    test('toMap, toJson, fromMap, and fromJson preserve data correctly', () {
      const manifest = SyncManifest(
        clientId: 'client-123',
        clientName: 'test-device',
        revision: 7,
        lastModified: '2026-10-05T09:00:00.000Z',
        booksCount: 42,
        dbSha256: 'abc123sha',
      );

      final jsonStr = manifest.toJson();
      final parsed = SyncManifest.fromJson(jsonStr);

      expect(parsed.clientId, 'client-123');
      expect(parsed.clientName, 'test-device');
      expect(parsed.revision, 7);
      expect(parsed.lastModified, '2026-10-05T09:00:00.000Z');
      expect(parsed.booksCount, 42);
      expect(parsed.dbSha256, 'abc123sha');
    });
  });

  group('WebDavService HTTP Tests', () {
    test('testConnection returns true for 207 Multi-Status or 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PROPFIND');
        expect(request.headers['Depth'], '0');
        expect(request.headers['Authorization'], contains('Basic '));
        return http.Response('', 207);
      });

      final service = WebDavService(client: mockClient);
      final ok = await service.testConnection(
        url: 'https://cloud.exemple.com/remote.php/dav/files/user/BiblioD',
        username: 'user',
        password: 'password123',
      );
      expect(ok, isTrue);
    });

    test('testConnection returns false for 401 Unauthorized', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final service = WebDavService(client: mockClient);
      final ok = await service.testConnection(
        url: 'https://cloud.exemple.com/dav',
        username: 'bad',
        password: 'wrong',
      );
      expect(ok, isFalse);
    });

    test(
      'getRemoteManifest returns parsed manifest on 200 and null on 404',
      () async {
        final expectedAuth = 'Basic ${base64Encode(utf8.encode('test:pwd'))}';
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('bibliod_sync.json')) {
            if (request.headers['Authorization'] == expectedAuth) {
              return http.Response(
                jsonEncode({
                  'client_id': 'c1',
                  'client_name': 'pc1',
                  'revision': 3,
                  'last_modified': '2026-10-05T00:00:00Z',
                  'books_count': 10,
                  'db_sha256': 'sha_hash',
                }),
                200,
              );
            }
            return http.Response('Not Found', 404);
          }
          return http.Response('', 400);
        });

        final service = WebDavService(client: mockClient);
        final manifestFound = await service.getRemoteManifest(
          url: 'https://cloud.test/dav',
          username: 'test',
          password: 'pwd',
        );
        expect(manifestFound, isNotNull);
        expect(manifestFound?.revision, 3);
        expect(manifestFound?.booksCount, 10);

        final manifestNotFound = await service.getRemoteManifest(
          url: 'https://cloud.test/dav',
          username: 'other',
          password: 'pwd',
        );
        expect(manifestNotFound, isNull);
      },
    );

    test(
      'uploadFile and downloadFile perform PUT and GET requests correctly',
      () async {
        List<int>? uploadedBytes;
        final mockClient = MockClient((request) async {
          if (request.method == 'PUT') {
            uploadedBytes = request.bodyBytes;
            return http.Response('', 201);
          } else if (request.method == 'GET') {
            return http.Response.bytes([1, 2, 3, 4], 200);
          }
          return http.Response('', 400);
        });

        final service = WebDavService(client: mockClient);
        final putOk = await service.uploadFile(
          targetUrl: 'https://cloud.test/dav/file.bin',
          username: 'user',
          password: 'pwd',
          bytes: [10, 20, 30],
        );
        expect(putOk, isTrue);
        expect(uploadedBytes, [10, 20, 30]);

        final downloaded = await service.downloadFile(
          sourceUrl: 'https://cloud.test/dav/file.bin',
          username: 'user',
          password: 'pwd',
        );
        expect(downloaded, [1, 2, 3, 4]);
      },
    );
  });

  group('SettingsNotifier WebDAV State Tests', () {
    test('updates WebDAV fields and persists them across reload', () async {
      final repo = _FakeSettingsBookRepo();
      final settingsRepo = SettingsRepository(bookRepository: repo);
      final notifier = SettingsNotifier(repository: settingsRepo);

      expect(notifier.webdavEnabled, isFalse);
      expect(notifier.webdavUrl, isEmpty);

      await notifier.setWebDavEnabled(true);
      await notifier.setWebDavConfig(
        url: 'https://mon-nas.lan/webdav/books',
        username: 'davy',
        password: 'supersecrettoken',
      );
      await notifier.setWebDavLastSync(
        status: 'success',
        message: 'Sauvegarde réussie',
        time: DateTime.utc(2026, 10, 5, 10, 0),
      );
      await notifier.setWebDavPendingConflict('conflict_file.db');

      expect(notifier.webdavEnabled, isTrue);
      expect(notifier.webdavUrl, 'https://mon-nas.lan/webdav/books');
      expect(notifier.webdavUsername, 'davy');
      expect(notifier.webdavPassword, 'supersecrettoken');
      expect(notifier.webdavLastSyncStatus, 'success');
      expect(notifier.webdavLastSyncMessage, 'Sauvegarde réussie');
      expect(notifier.webdavPendingConflict, 'conflict_file.db');

      final reloaded = SettingsNotifier(repository: settingsRepo);
      await reloaded.loadSettings();

      expect(reloaded.webdavEnabled, isTrue);
      expect(reloaded.webdavUrl, 'https://mon-nas.lan/webdav/books');
      expect(reloaded.webdavUsername, 'davy');
      expect(reloaded.webdavPassword, 'supersecrettoken');
      expect(reloaded.webdavLastSyncStatus, 'success');
      expect(reloaded.webdavLastSyncMessage, 'Sauvegarde réussie');
      expect(reloaded.webdavPendingConflict, 'conflict_file.db');
    });
  });
}

class _FakeSettingsBookRepo implements BookRepository {
  final Map<String, String> _settings = {};

  @override
  Future<List<Book>> getAllBooks() async => [];
  @override
  Future<Book?> getLastRegisteredBook() async => null;
  @override
  Future<int?> insertBook(Book book) async => 1;
  @override
  Future<bool> updateBook(Book book) async => true;
  @override
  Future<bool> deleteBook(int id) async => true;
  @override
  Future<int> batchInsertBooks(List<Book> books) async => 0;
  @override
  Future<String?> getSetting(String key) async => _settings[key];
  @override
  Future<void> setSetting(String key, String value) async =>
      _settings[key] = value;
  @override
  Future<int> getChangeCounter() async =>
      int.tryParse(_settings['local_change_counter'] ?? '0') ?? 0;
  @override
  Future<String> getClientId() async =>
      _settings['client_id'] ?? 'fake_client_id';
  @override
  Future<int> getLastSyncedCounter() async =>
      int.tryParse(_settings['last_synced_counter'] ?? '0') ?? 0;
  @override
  Future<int> getLastSyncedRemoteRevision() async =>
      int.tryParse(_settings['last_synced_remote_revision'] ?? '0') ?? 0;
  @override
  Future<bool> hasUnsyncedChanges() async =>
      (await getChangeCounter()) > (await getLastSyncedCounter());
  @override
  Future<void> recordSuccessfulSync({
    required int syncedRevision,
    required int syncedCounter,
  }) async {
    _settings['last_synced_counter'] = syncedCounter.toString();
    _settings['last_synced_remote_revision'] = syncedRevision.toString();
  }
}
