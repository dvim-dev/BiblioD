import '../../books/data/book_repository.dart';

class SettingsRepository {
  final BookRepository _bookRepository;

  SettingsRepository({required BookRepository bookRepository})
    : _bookRepository = bookRepository;

  Future<String?> getSetting(String key) {
    return _bookRepository.getSetting(key);
  }

  Future<void> setSetting(String key, String value) {
    return _bookRepository.setSetting(key, value);
  }
}
