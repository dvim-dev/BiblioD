import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../data/settings_repository.dart';

class SettingsNotifier extends ChangeNotifier {
  final SettingsRepository _repository;

  ThemeMode _themeMode = ThemeMode.system;
  List<String> _visibleColumns = List.from(AppConstants.defaultVisibleColumns);
  double _listFontSizeDelta = 0.0;
  String _bibliographyLanguage = 'fre';
  bool _webdavEnabled = false;
  String _webdavUrl = '';
  String _webdavUsername = '';
  String _webdavPassword = '';
  String _webdavLastSyncTime = '';
  String _webdavLastSyncStatus = '';
  String _webdavLastSyncMessage = '';
  String _webdavPendingConflict = '';
  bool _isLoaded = false;

  SettingsNotifier({required SettingsRepository repository})
    : _repository = repository;

  ThemeMode get themeMode => _themeMode;
  List<String> get visibleColumns => List.unmodifiable(_visibleColumns);
  double get listFontSizeDelta => _listFontSizeDelta;
  String get bibliographyLanguage => _bibliographyLanguage;
  bool get webdavEnabled => _webdavEnabled;
  String get webdavUrl => _webdavUrl;
  String get webdavUsername => _webdavUsername;
  String get webdavPassword => _webdavPassword;
  String get webdavLastSyncTime => _webdavLastSyncTime;
  String get webdavLastSyncStatus => _webdavLastSyncStatus;
  String get webdavLastSyncMessage => _webdavLastSyncMessage;
  String get webdavPendingConflict => _webdavPendingConflict;
  bool get isLoaded => _isLoaded;

  bool isColumnVisible(String columnKey) => _visibleColumns.contains(columnKey);

  Future<void> loadSettings() async {
    final savedTheme = await _repository.getSetting('theme_mode');
    if (savedTheme != null) {
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    }

    final savedCols = await _repository.getSetting('visible_columns');
    if (savedCols != null) {
      try {
        final decoded = jsonDecode(savedCols) as List<dynamic>?;
        if (decoded != null && decoded.isNotEmpty) {
          _visibleColumns = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    final savedFontSizeDelta = await _repository.getSetting(
      'list_font_size_delta',
    );
    if (savedFontSizeDelta != null) {
      final parsed = double.tryParse(savedFontSizeDelta);
      if (parsed != null) {
        _listFontSizeDelta = parsed.clamp(-2.0, 6.0);
      }
    }

    final savedLang = await _repository.getSetting('bibliography_language');
    if (savedLang != null && savedLang.isNotEmpty) {
      _bibliographyLanguage = savedLang;
    }

    await _loadWebDavSettings();

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _repository.setSetting('theme_mode', value);
  }

  Future<void> toggleColumn(String columnKey) async {
    if (_visibleColumns.contains(columnKey)) {
      if (_visibleColumns.length > 1) {
        _visibleColumns.remove(columnKey);
      }
    } else {
      _visibleColumns.add(columnKey);
    }
    notifyListeners();
    await _saveVisibleColumns();
  }

  Future<void> setVisibleColumns(List<String> columns) async {
    if (columns.isEmpty) return;
    _visibleColumns = List.from(columns);
    notifyListeners();
    await _saveVisibleColumns();
  }

  Future<void> resetColumnsToDefault() async {
    _visibleColumns = List.from(AppConstants.defaultVisibleColumns);
    notifyListeners();
    await _saveVisibleColumns();
  }

  Future<void> _saveVisibleColumns() async {
    await _repository.setSetting(
      'visible_columns',
      jsonEncode(_visibleColumns),
    );
  }

  Future<void> setListFontSizeDelta(double delta) async {
    final clamped = delta.clamp(-2.0, 6.0);
    if (_listFontSizeDelta == clamped) return;
    _listFontSizeDelta = clamped;
    notifyListeners();
    await _repository.setSetting('list_font_size_delta', clamped.toString());
  }

  Future<void> increaseListFontSize() async {
    if (_listFontSizeDelta < 6.0) {
      await setListFontSizeDelta(_listFontSizeDelta + 1.0);
    }
  }

  Future<void> decreaseListFontSize() async {
    if (_listFontSizeDelta > -2.0) {
      await setListFontSizeDelta(_listFontSizeDelta - 1.0);
    }
  }

  Future<void> resetListFontSize() async {
    await setListFontSizeDelta(0.0);
  }

  Future<void> setBibliographyLanguage(String language) async {
    if (_bibliographyLanguage == language) return;
    _bibliographyLanguage = language;
    notifyListeners();
    await _repository.setSetting('bibliography_language', language);
  }

  Future<void> _loadWebDavSettings() async {
    final enabled = await _repository.getSetting('webdav_enabled');
    _webdavEnabled = enabled == 'true';
    _webdavUrl = await _repository.getSetting('webdav_url') ?? '';
    _webdavUsername = await _repository.getSetting('webdav_username') ?? '';
    _webdavPassword = await _repository.getSetting('webdav_password') ?? '';
    _webdavLastSyncTime =
        await _repository.getSetting('webdav_last_sync_time') ?? '';
    _webdavLastSyncStatus =
        await _repository.getSetting('webdav_last_sync_status') ?? '';
    _webdavLastSyncMessage =
        await _repository.getSetting('webdav_last_sync_message') ?? '';
    _webdavPendingConflict =
        await _repository.getSetting('webdav_pending_conflict') ?? '';
  }

  Future<void> setWebDavEnabled(bool enabled) async {
    _webdavEnabled = enabled;
    notifyListeners();
    await _repository.setSetting('webdav_enabled', enabled ? 'true' : 'false');
  }

  Future<void> setWebDavConfig({
    required String url,
    required String username,
    required String password,
  }) async {
    _webdavUrl = url;
    _webdavUsername = username;
    _webdavPassword = password;
    notifyListeners();
    await _repository.setSetting('webdav_url', url);
    await _repository.setSetting('webdav_username', username);
    await _repository.setSetting('webdav_password', password);
  }

  Future<void> setWebDavLastSync({
    required String status,
    required String message,
    DateTime? time,
  }) async {
    final nowStr = (time ?? DateTime.now()).toIso8601String();
    _webdavLastSyncStatus = status;
    _webdavLastSyncMessage = message;
    _webdavLastSyncTime = nowStr;
    notifyListeners();
    await _repository.setSetting('webdav_last_sync_status', status);
    await _repository.setSetting('webdav_last_sync_message', message);
    await _repository.setSetting('webdav_last_sync_time', nowStr);
  }

  Future<void> setWebDavPendingConflict(String conflict) async {
    _webdavPendingConflict = conflict;
    notifyListeners();
    await _repository.setSetting('webdav_pending_conflict', conflict);
  }
}
