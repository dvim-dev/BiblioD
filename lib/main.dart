import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'features/books/data/book_repository.dart';
import 'features/books/domain/book.dart';
import 'features/books/presentation/book_notifier.dart';
import 'features/books/presentation/screens/home_screen.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/presentation/settings_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation SQLite FFI pour Linux Desktop
  sqfliteFfiInit();

  final dbHelper = DatabaseHelper.instance;
  final bookRepo = BookRepository(dbHelper: dbHelper);
  final settingsRepo = SettingsRepository(bookRepository: bookRepo);

  final bookNotifier = BookNotifier(repository: bookRepo);
  final settingsNotifier = SettingsNotifier(repository: settingsRepo);

  try {
    await settingsNotifier.loadSettings();
    await bookNotifier.loadBooks();

    // Si la base est vierge au tout premier lancement, on injecte quelques exemples
    if (bookNotifier.totalCount == 0) {
      await _insertInitialSampleBooks(bookRepo, bookNotifier);
    }
  } catch (e, stack) {
    developer.log(
      'Erreur lors du démarrage de BiblioD: $e',
      error: e,
      stackTrace: stack,
      name: 'Main',
    );
  }

  runApp(
    BiblioDApp(bookNotifier: bookNotifier, settingsNotifier: settingsNotifier),
  );
}

Future<void> _insertInitialSampleBooks(
  BookRepository repo,
  BookNotifier notifier,
) async {
  final now = DateTime.now();
  final sampleBooks = [
    Book(
      title: 'Les Misérables',
      authorLastName: 'Hugo',
      authorFirstName: 'Victor',
      rating: 5,
      genre: 'Roman classique',
      isbn: '9782070409228',
      format: AppConstants.formatPhysical,
      publisher: 'Gallimard',
      publicationYear: 1862,
      remarks: 'Chef-d\'œuvre de la littérature française.',
      createdAt: now,
      updatedAt: now,
    ),
    Book(
      title: 'Vingt Mille Lieues sous les mers',
      authorLastName: 'Verne',
      authorFirstName: 'Jules',
      rating: 4,
      series: 'Voyages extraordinaires',
      seriesNumber: 6,
      genre: 'Aventure / Science-Fiction',
      isbn: '9782253006329',
      format: AppConstants.formatPhysical,
      publisher: 'Hetzel',
      publicationYear: 1870,
      remarks: 'Aventures du Capitaine Nemo à bord du Nautilus.',
      createdAt: now,
      updatedAt: now,
    ),
    Book(
      title: 'Fondation',
      authorLastName: 'Asimov',
      authorFirstName: 'Isaac',
      rating: 5,
      series: 'Cycle de Fondation',
      seriesNumber: 1,
      genre: 'Science-Fiction',
      isbn: '9782070415700',
      format: AppConstants.formatDigital,
      publisher: 'Denoël',
      publicationYear: 1951,
      remarks: 'L\'histoire de Hari Seldon et de la psychohistoire.',
      createdAt: now,
      updatedAt: now,
    ),
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
      remarks: 'Paul Atréides sur la planète désertique Arrakis.',
      createdAt: now,
      updatedAt: now,
    ),
    Book(
      title: 'L\'Étranger',
      authorLastName: 'Camus',
      authorFirstName: 'Albert',
      rating: 4,
      genre: 'Philosophie / Roman',
      isbn: '9782070360024',
      format: AppConstants.formatDigital,
      publisher: 'Gallimard',
      publicationYear: 1942,
      remarks:
          'Aujourd\'hui, maman est morte. Ou peut-être hier, je ne sais pas.',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  await notifier.importBooks(sampleBooks);
}

class BiblioDApp extends StatelessWidget {
  final BookNotifier bookNotifier;
  final SettingsNotifier settingsNotifier;

  const BiblioDApp({
    super.key,
    required this.bookNotifier,
    required this.settingsNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: settingsNotifier.themeMode,
          home: HomeScreen(
            bookNotifier: bookNotifier,
            settingsNotifier: settingsNotifier,
          ),
        );
      },
    );
  }
}
