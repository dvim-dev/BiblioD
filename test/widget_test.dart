import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bibliod/core/constants/app_constants.dart';
import 'package:bibliod/features/books/data/book_repository.dart';
import 'package:bibliod/features/books/domain/book.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';
import 'package:bibliod/features/books/presentation/widgets/book_form_dialog.dart';
import 'package:bibliod/features/books/presentation/widgets/book_table_view.dart';
import 'package:bibliod/features/books/presentation/widgets/toolbar_widget.dart';
import 'package:bibliod/features/books/data/author_works_service.dart';
import 'package:bibliod/features/books/data/wikipedia_service.dart';
import 'package:bibliod/features/books/presentation/widgets/author_wiki_dialog.dart';
import 'package:bibliod/features/books/presentation/widgets/author_bibliography_dialog.dart';
import 'package:bibliod/features/settings/data/settings_repository.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';
import 'package:bibliod/features/settings/presentation/widgets/settings_dialog.dart';

class FakeBookRepository implements BookRepository {
  final List<Book> _books = [];
  final Map<String, String> _settings = {};

  @override
  Future<List<Book>> getAllBooks() async => List.from(_books);

  @override
  Future<Book?> getLastRegisteredBook() async => _books.lastOrNull;

  @override
  Future<int?> insertBook(Book book) async {
    final id = _books.length + 1;
    _books.add(book.copyWith(id: id));
    return id;
  }

  @override
  Future<bool> updateBook(Book book) async {
    final idx = _books.indexWhere((b) => b.id == book.id);
    if (idx != -1) {
      _books[idx] = book;
      return true;
    }
    return false;
  }

  @override
  Future<bool> deleteBook(int id) async {
    _books.removeWhere((b) => b.id == id);
    return true;
  }

  @override
  Future<int> batchInsertBooks(List<Book> books) async {
    for (final b in books) {
      await insertBook(b);
    }
    return books.length;
  }

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

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

void main() {
  testWidgets(
    'BookTableView renders 5 empty stars when rating is 0 and updates on tap',
    (tester) async {
      final repo = FakeBookRepository();
      final bookNotifier = BookNotifier(repository: repo);
      final settingsRepo = SettingsRepository(bookRepository: repo);
      final settingsNotifier = SettingsNotifier(repository: settingsRepo);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      await bookNotifier.addBook(
        Book(
          id: 1,
          title: 'Le Meilleur des mondes',
          authorLastName: 'Huxley',
          authorFirstName: 'Aldous',
          rating: 0,
          format: AppConstants.formatPhysical,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(bookNotifier.lastRegisteredFormat, AppConstants.formatPhysical);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: bookNotifier,
              builder: (context, _) => BookTableView(
                bookNotifier: bookNotifier,
                settingsNotifier: settingsNotifier,
                onBookDoubleTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 5 étoiles vides affichées quand note = 0
      final emptyStarFinder = find.byIcon(Icons.star_border_rounded);
      expect(emptyStarFinder, findsNWidgets(5));
      expect(find.byIcon(Icons.star_rounded), findsNothing);

      // Clic direct sur la 4ème étoile (index 3)
      await tester.tap(emptyStarFinder.at(3));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // La note doit être mise à jour à 4 directement dans la liste
      expect(bookNotifier.books.first.rating, 4);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(1));

      // Re-clic sur la 4ème étoile -> réinitialisation à 0
      await tester.tap(find.byIcon(Icons.star_rounded).at(3));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(bookNotifier.books.first.rating, 0);
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));
    },
  );

  testWidgets(
    'SettingsNotifier font size controls adjust list font size delta',
    (tester) async {
      final repo = FakeBookRepository();
      final settingsRepo = SettingsRepository(bookRepository: repo);
      final settingsNotifier = SettingsNotifier(repository: settingsRepo);

      expect(settingsNotifier.listFontSizeDelta, 0.0);

      await settingsNotifier.increaseListFontSize();
      expect(settingsNotifier.listFontSizeDelta, 1.0);

      await settingsNotifier.decreaseListFontSize();
      expect(settingsNotifier.listFontSizeDelta, 0.0);

      await settingsNotifier.decreaseListFontSize();
      expect(settingsNotifier.listFontSizeDelta, -1.0);

      await settingsNotifier.resetListFontSize();
      expect(settingsNotifier.listFontSizeDelta, 0.0);
    },
  );

  testWidgets('BookFormDialog renders correctly in edit mode', (tester) async {
    final repo = FakeBookRepository();
    final bookNotifier = BookNotifier(repository: repo);
    final now = DateTime.now();
    final book = Book(
      id: 1,
      title: 'Dune',
      authorLastName: 'Herbert',
      authorFirstName: 'Frank',
      rating: 4,
      series: 'Cycle de Dune',
      seriesNumber: 1,
      genre: 'SF',
      isbn: '9782266320481',
      format: 'Physique',
      remarks: 'Chef d\'œuvre',
      publisher: 'Pocket',
      publicationYear: 1965,
      coverImagePath: null,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => BookFormDialog.show(
                context,
                book: book,
                bookNotifier: bookNotifier,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le livre'), findsOneWidget);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Herbert'), findsOneWidget);
  });

  testWidgets(
    'BookFormDialog renders safely with non-standard format and invalid cover path',
    (tester) async {
      final repo = FakeBookRepository();
      final bookNotifier = BookNotifier(repository: repo);
      final now = DateTime.now();
      final book = Book(
        id: 2,
        title: 'Neuromancien',
        authorLastName: 'Gibson',
        authorFirstName: 'William',
        rating: 0,
        series: 'Sprawl',
        seriesNumber: 1,
        genre: 'Cyberpunk',
        isbn: '9782290006245',
        format: 'ebook_format_inconnu',
        remarks: 'Test format edge case',
        publisher: 'J\'ai Lu',
        publicationYear: 1984,
        coverImagePath: '/non/existent/path/cover.jpg',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BookFormDialog.show(
                  context,
                  book: book,
                  bookNotifier: bookNotifier,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le livre'), findsOneWidget);
      expect(find.text('Neuromancien'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ToolbarWidget displays Paramètres button and enforces minimum width for omnibox (>= 8 chars)',
    (tester) async {
      final repo = FakeBookRepository();
      final bookNotifier = BookNotifier(repository: repo);
      final settingsRepo = SettingsRepository(bookRepository: repo);
      final settingsNotifier = SettingsNotifier(repository: settingsRepo);

      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool settingsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolbarWidget(
              bookNotifier: bookNotifier,
              settingsNotifier: settingsNotifier,
              onAddBook: () {},
              onShowColumns: () {},
              onShowStatistics: () {},
              onOpenSettings: () {
                settingsOpened = true;
              },
            ),
          ),
        ),
      );

      // Verify Paramètres button is present
      expect(find.text('Paramètres'), findsOneWidget);
      // Verify Importer CSV and Exporter CSV buttons are no longer on the main toolbar
      expect(find.text('Importer CSV'), findsNothing);
      expect(find.text('Exporter CSV'), findsNothing);

      // Verify omnibox textfield is rendered with enough width
      final omniboxFinder = find.byType(TextField);
      expect(omniboxFinder, findsOneWidget);

      final Size omniboxSize = tester.getSize(omniboxFinder);
      // Min width must be >= 200, which is plenty for 8+ characters plus search/clear icons
      expect(omniboxSize.width >= 200, isTrue);

      // Verify tapping Paramètres calls callback
      await tester.tap(find.text('Paramètres'));
      await tester.pump();
      expect(settingsOpened, isTrue);
    },
  );

  testWidgets(
    'SettingsDialog renders CSV options and data location correctly',
    (tester) async {
      final repo = FakeBookRepository();
      final bookNotifier = BookNotifier(repository: repo);
      final settingsRepo = SettingsRepository(bookRepository: repo);
      final settingsNotifier = SettingsNotifier(repository: settingsRepo);

      bool importTapped = false;
      bool exportTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SettingsDialog.show(
                  context,
                  bookNotifier: bookNotifier,
                  settingsNotifier: settingsNotifier,
                  onImportCsv: () {
                    importTapped = true;
                  },
                  onExportCsv: () {
                    exportTapped = true;
                  },
                ),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Import / Export CSV'), findsOneWidget);
      expect(find.text('Importer un fichier CSV...'), findsOneWidget);
      expect(find.text('Exporter la bibliothèque en CSV...'), findsOneWidget);
      expect(
        find.text('Emplacement des données (Base de données & Couvertures)'),
        findsOneWidget,
      );
      expect(find.text('Déplacer la bibliothèque...'), findsOneWidget);

      // Tap Importer CSV inside dialog
      await tester.tap(find.text('Importer un fichier CSV...'));
      await tester.pumpAndSettle();
      expect(importTapped, isTrue);
      expect(exportTapped, isFalse);
    },
  );

  testWidgets('SettingsDialog displays WebDAV configuration and controls', (
    tester,
  ) async {
    final repo = FakeBookRepository();
    final bookNotifier = BookNotifier(repository: repo);
    final settingsRepo = SettingsRepository(bookRepository: repo);
    final settingsNotifier = SettingsNotifier(repository: settingsRepo);

    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SettingsDialog.show(
                context,
                bookNotifier: bookNotifier,
                settingsNotifier: settingsNotifier,
                onImportCsv: () {},
                onExportCsv: () {},
              ),
              child: const Text('Open Settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sauvegarde & Synchronisation en ligne (WebDAV)'),
      findsOneWidget,
    );
    expect(find.text('Tester la connexion'), findsOneWidget);
    expect(find.text('Synchroniser maintenant'), findsOneWidget);
    expect(find.text('URL du dossier WebDAV'), findsOneWidget);
    expect(find.text('Nom d\'utilisateur'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(settingsNotifier.webdavEnabled, isTrue);
  });

  testWidgets(
    'AuthorWikiDialog displays Tous les livres de l\'auteur button when bookNotifier provided',
    (tester) async {
      final repo = FakeBookRepository();
      final bookNotifier = BookNotifier(repository: repo);
      const wikiInfo = AuthorWikiInfo(
        authorName: 'Aldous Huxley',
        pageTitle: 'Aldous Huxley',
        extract: 'Écrivain britannique...',
        pageUrl: 'https://fr.wikipedia.org/wiki/Aldous_Huxley',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthorWikiDialog.show(
                  context,
                  wikiInfo,
                  bookNotifier: bookNotifier,
                ),
                child: const Text('Open Wiki'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wiki'));
      await tester.pumpAndSettle();

      expect(find.text('Aldous Huxley'), findsOneWidget);
      expect(find.text('Tous les livres de l\'auteur'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthorBibliographyDialog displays works, stats badges, and comparative owned/missing state',
    (tester) async {
      final repo = FakeBookRepository();
      final bookNotifier = BookNotifier(repository: repo);
      final now = DateTime.now();

      await bookNotifier.addBook(
        Book(
          id: 1,
          title: 'Brave New World',
          authorLastName: 'Huxley',
          authorFirstName: 'Aldous',
          rating: 5,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final fakeWorksService = FakeAuthorWorksService([
        const AuthorWork(
          title: 'Brave New World',
          firstPublishYear: 1932,
          editionCount: 120,
        ),
        const AuthorWork(
          title: 'Island',
          firstPublishYear: 1962,
          editionCount: 45,
        ),
        const AuthorWork(
          title: 'Point Counter Point',
          firstPublishYear: 1928,
          editionCount: 30,
        ),
      ]);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthorBibliographyDialog.show(
                  context,
                  authorName: 'Aldous Huxley',
                  bookNotifier: bookNotifier,
                  worksService: fakeWorksService,
                ),
                child: const Text('Open Biblio'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Biblio'));
      await tester.pumpAndSettle();

      // Verify Header stats
      expect(find.text('Bibliographie de Aldous Huxley'), findsOneWidget);
      expect(find.text('3 œuvres'), findsOneWidget);
      expect(find.text('1 possédées (33%)'), findsOneWidget);
      expect(find.text('2 manquantes'), findsOneWidget);

      // Verify filter segments
      expect(find.text('Tous (3)'), findsOneWidget);
      expect(find.text('Manquants (2)'), findsOneWidget);
      expect(find.text('Possédés (1)'), findsOneWidget);

      // Verify books displayed
      expect(find.text('Brave New World'), findsOneWidget);
      expect(find.text('Dans votre bibliothèque'), findsOneWidget);
      expect(find.text('Island'), findsOneWidget);
      expect(find.text('Point Counter Point'), findsOneWidget);
      expect(find.text('Ajouter'), findsNWidgets(2));

      // Filter by "Manquants"
      await tester.tap(find.text('Manquants (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Brave New World'), findsNothing);
      expect(find.text('Island'), findsOneWidget);
      expect(find.text('Point Counter Point'), findsOneWidget);

      // Filter by "Possédés"
      await tester.tap(find.text('Possédés (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Brave New World'), findsOneWidget);
      expect(find.text('Island'), findsNothing);
      expect(find.text('Point Counter Point'), findsNothing);

      // Verify language selector is present with French default
      expect(find.text('Français'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthorBibliographyDialog changes language, persists to SettingsNotifier and reloads',
    (tester) async {
      final repo = FakeBookRepository();
      final bookNotifier = BookNotifier(repository: repo);
      final settingsRepo = SettingsRepository(bookRepository: repo);
      final settingsNotifier = SettingsNotifier(repository: settingsRepo);

      final fakeWorksService = FakeAuthorWorksService([
        const AuthorWork(
          title: 'Don Quijote',
          firstPublishYear: 1605,
          editionCount: 500,
        ),
      ]);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthorBibliographyDialog.show(
                  context,
                  authorName: 'Cervantes',
                  bookNotifier: bookNotifier,
                  settingsNotifier: settingsNotifier,
                  worksService: fakeWorksService,
                ),
                child: const Text('Open Biblio'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Biblio'));
      await tester.pumpAndSettle();

      // Initial language should be French by default
      expect(settingsNotifier.bibliographyLanguage, 'fre');
      expect(fakeWorksService.lastRequestedLanguage, 'fre');
      expect(find.text('Français'), findsOneWidget);

      // Tap on language selector
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();

      // Popup menu with available languages
      expect(find.text('Anglais'), findsOneWidget);
      expect(find.text('Espagnol'), findsOneWidget);
      expect(find.text('Toutes les langues'), findsOneWidget);

      // Select Spanish (🇪🇸 Espagnol)
      await tester.tap(find.text('Espagnol'));
      await tester.pumpAndSettle();

      expect(settingsNotifier.bibliographyLanguage, 'spa');
      expect(fakeWorksService.lastRequestedLanguage, 'spa');
      expect(find.text('Espagnol'), findsOneWidget);

      // Select English (🇬🇧 Anglais)
      await tester.tap(find.text('Espagnol'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anglais'));
      await tester.pumpAndSettle();

      expect(settingsNotifier.bibliographyLanguage, 'eng');
      expect(fakeWorksService.lastRequestedLanguage, 'eng');
      expect(find.text('Anglais'), findsOneWidget);
    },
  );

  testWidgets(
    'BookTableView positions single vertical scrollbar below header in narrow and wide viewports',
    (tester) async {
      final repo = FakeBookRepository();
      final bookNotifier = BookNotifier(repository: repo);
      final settingsRepo = SettingsRepository(bookRepository: repo);
      final settingsNotifier = SettingsNotifier(repository: settingsRepo);

      final now = DateTime.now();
      for (int i = 0; i < 20; i++) {
        await repo.insertBook(
          Book(
            id: i + 1,
            title: 'Book $i',
            authorLastName: 'Author $i',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await bookNotifier.loadBooks();

      // Test 1: Wide window (1600px > total columns width) on Linux Desktop
      tester.view.physicalSize = const Size(1600, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: Scaffold(
            body: BookTableView(
              bookNotifier: bookNotifier,
              settingsNotifier: settingsNotifier,
              onBookDoubleTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly 2 Scrollbars in total (1 vertical, 1 horizontal), no duplicate on desktop
      final scrollbarsWide = find.byType(Scrollbar);
      expect(scrollbarsWide, findsNWidgets(2));

      // The vertical scrollbar starts below the header (y > 0) and has width = 1600
      final verticalWide = scrollbarsWide.first;
      final Size sizeWide = tester.getSize(verticalWide);
      final Offset offsetWide = tester.getTopLeft(verticalWide);
      expect(sizeWide.width, 1600.0);
      expect(offsetWide.dy > 0, isTrue); // Starts below header!

      // Test 2: Narrow window (700px < total columns width)
      tester.view.physicalSize = const Size(700, 500);
      await tester.pumpAndSettle();

      final scrollbarsNarrow = find.byType(Scrollbar);
      expect(scrollbarsNarrow, findsNWidgets(2));

      final verticalNarrow = scrollbarsNarrow.first;
      final Size sizeNarrow = tester.getSize(verticalNarrow);
      final Offset offsetNarrow = tester.getTopLeft(verticalNarrow);
      expect(sizeNarrow.width, 700.0);
      expect(offsetNarrow.dy > 0, isTrue);
    },
  );
}

class FakeAuthorWorksService extends AuthorWorksService {
  final List<AuthorWork> stubWorks;
  String? lastRequestedLanguage;

  FakeAuthorWorksService(this.stubWorks);

  @override
  Future<List<AuthorWork>> fetchAuthorWorks(
    String authorName, {
    String? language,
    List<Book> existingBooks = const [],
  }) async {
    lastRequestedLanguage = language;
    return stubWorks.map((w) {
      final isOwned = existingBooks.any((b) => b.title == w.title);
      return w.copyWith(isOwned: isOwned);
    }).toList();
  }
}
