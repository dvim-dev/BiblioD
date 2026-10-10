import 'package:flutter/material.dart';
import 'package:bibliod/features/books/data/author_works_service.dart';
import 'package:bibliod/features/books/domain/book.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';
import 'package:bibliod/features/books/presentation/widgets/book_form_dialog.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';

enum BibliographyFilter { all, missing, owned }

class BibliographyLanguage {
  final String code;
  final String label;
  final String flag;

  const BibliographyLanguage({
    required this.code,
    required this.label,
    required this.flag,
  });
}

const availableLanguages = [
  BibliographyLanguage(code: 'fre', label: 'Français', flag: '🇫🇷'),
  BibliographyLanguage(code: 'eng', label: 'Anglais', flag: '🇬🇧'),
  BibliographyLanguage(code: 'spa', label: 'Espagnol', flag: '🇪🇸'),
  BibliographyLanguage(code: 'all', label: 'Toutes les langues', flag: '🌐'),
];

class AuthorBibliographyDialog extends StatefulWidget {
  final String authorName;
  final BookNotifier bookNotifier;
  final SettingsNotifier? settingsNotifier;
  final AuthorWorksService? worksService;

  const AuthorBibliographyDialog({
    super.key,
    required this.authorName,
    required this.bookNotifier,
    this.settingsNotifier,
    this.worksService,
  });

  static Future<void> show(
    BuildContext context, {
    required String authorName,
    required BookNotifier bookNotifier,
    SettingsNotifier? settingsNotifier,
    AuthorWorksService? worksService,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AuthorBibliographyDialog(
        authorName: authorName,
        bookNotifier: bookNotifier,
        settingsNotifier: settingsNotifier,
        worksService: worksService,
      ),
    );
  }

  @override
  State<AuthorBibliographyDialog> createState() =>
      _AuthorBibliographyDialogState();
}

class _AuthorBibliographyDialogState extends State<AuthorBibliographyDialog> {
  late final AuthorWorksService _service;
  late String _selectedLanguage;
  bool _isLoading = true;
  bool _isTranslating = false;
  int _translationProgress = 0;
  int _translationTotal = 0;
  int _fetchGeneration = 0;
  String? _errorMessage;
  List<AuthorWork> _works = [];
  BibliographyFilter _filter = BibliographyFilter.all;
  String _searchQuery = '';
  bool _sortByYear = false;

  @override
  void initState() {
    super.initState();
    _service = widget.worksService ?? AuthorWorksService();
    _selectedLanguage = widget.settingsNotifier?.bibliographyLanguage ?? 'fre';
    _fetchWorks();
  }

  Future<void> _fetchWorks() async {
    final gen = ++_fetchGeneration;
    setState(() {
      _isLoading = true;
      _isTranslating = false;
      _errorMessage = null;
    });

    final books = widget.bookNotifier.books;
    final results = await _service.fetchAuthorWorks(
      widget.authorName,
      language: _selectedLanguage,
      existingBooks: books,
    );

    if (!mounted || gen != _fetchGeneration) return;

    setState(() {
      _isLoading = false;
      if (results.isEmpty) {
        _errorMessage = _getNoWorksMessage();
      } else {
        _works = results;
        _isTranslating = _selectedLanguage != 'all';
        _translationProgress = 0;
        _translationTotal = results.length;
      }
    });

    if (results.isNotEmpty && _selectedLanguage != 'all') {
      _service.resolveTranslations(
        works: results,
        language: _selectedLanguage,
        existingBooks: books,
        targetAuthorName: widget.authorName,
        isCancelled: () => !mounted || gen != _fetchGeneration,
        onProgress: (completed, total) {
          if (!mounted || gen != _fetchGeneration) return;
          setState(() {
            _translationProgress = completed;
            _translationTotal = total;
            if (completed >= total) _isTranslating = false;
          });
        },
        onWorkUpdated: (updated) {
          if (!mounted || gen != _fetchGeneration) return;
          _handleWorkUpdated(updated);
        },
      );
    }
  }

  void _handleWorkUpdated(AuthorWork updated) {
    setState(() {
      final normUpdated = AuthorWorksService.normalizeTitle(updated.title);
      final dupIndex = _works.indexWhere(
        (w) =>
            w.workKey != updated.workKey &&
            AuthorWorksService.normalizeTitle(w.title) == normUpdated,
      );
      if (dupIndex != -1) {
        _works.removeWhere((w) => w.workKey == updated.workKey);
        return;
      }

      final index = _works.indexWhere((w) => w.workKey == updated.workKey);
      if (index != -1) {
        _works[index] = updated;
      }
    });
  }

  String _getNoWorksMessage() {
    final lang = availableLanguages.firstWhere(
      (l) => l.code == _selectedLanguage,
      orElse: () => availableLanguages.first,
    );
    if (_selectedLanguage == 'all') {
      return 'Aucune œuvre trouvée pour cet auteur.';
    }
    return 'Aucune œuvre répertoriée en ${lang.label.toLowerCase()} pour cet auteur.';
  }

  void _onLanguageChanged(String newLang) {
    if (_selectedLanguage == newLang) return;
    setState(() {
      _selectedLanguage = newLang;
    });
    widget.settingsNotifier?.setBibliographyLanguage(newLang);
    _fetchWorks();
  }

  void _onBookAdded(AuthorWork work) {
    setState(() {
      final index = _works.indexWhere((w) => w.title == work.title);
      if (index != -1) {
        _works[index] = _works[index].copyWith(isOwned: true);
      }
    });
  }

  Future<void> _handleQuickAdd(AuthorWork work) async {
    final names = _splitAuthorName(widget.authorName);
    final now = DateTime.now();

    var isbn = work.isbn;
    final workKey = work.workKey;
    if (isbn == null && workKey != null) {
      isbn = await _service.fetchWorkIsbn(workKey, _selectedLanguage);
    }

    final templateBook = Book(
      id: null,
      title: work.title,
      authorLastName: names.$1,
      authorFirstName: names.$2,
      publicationYear: work.firstPublishYear,
      format: widget.bookNotifier.lastRegisteredFormat,
      isbn: isbn,
      rating: 0,
      createdAt: now,
      updatedAt: now,
    );

    if (!mounted) return;

    final result = await BookFormDialog.show(
      context,
      book: templateBook,
      bookNotifier: widget.bookNotifier,
      settingsNotifier: widget.settingsNotifier,
    );

    if (result == true && mounted) {
      _onBookAdded(work);
    }
  }

  (String, String) _splitAuthorName(String fullName) {
    final clean = fullName.trim();
    if (clean.contains(',')) {
      final parts = clean.split(',');
      final last = parts.first.trim();
      final first = parts.length > 1 ? parts[1].trim() : '';
      return (last, first);
    }
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return (parts.first, '');
    }
    final last = parts.last;
    final first = parts.sublist(0, parts.length - 1).join(' ');
    return (last, first);
  }

  List<AuthorWork> _getFilteredWorks() {
    var list = _works.where((w) {
      if (_filter == BibliographyFilter.missing && w.isOwned) return false;
      if (_filter == BibliographyFilter.owned && !w.isOwned) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = w.title.toLowerCase().contains(q);
        final matchYear = w.firstPublishYear?.toString().contains(q) ?? false;
        if (!matchTitle && !matchYear) return false;
      }
      return true;
    }).toList();

    if (_sortByYear) {
      list.sort((a, b) {
        final ya = a.firstPublishYear ?? 9999;
        final yb = b.firstPublishYear ?? 9999;
        return ya.compareTo(yb);
      });
    } else {
      list.sort((a, b) => b.editionCount.compareTo(a.editionCount));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ownedCount = _works.where((w) => w.isOwned).length;
    final missingCount = _works.length - ownedCount;
    final filtered = _getFilteredWorks();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: _DialogHeader(
        authorName: widget.authorName,
        totalCount: _works.length,
        ownedCount: ownedCount,
        missingCount: missingCount,
        selectedLanguage: _selectedLanguage,
        onLanguageChanged: _onLanguageChanged,
        isTranslating: _isTranslating,
        translationProgress: _translationProgress,
        translationTotal: _translationTotal,
      ),
      content: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            if (_works.isNotEmpty) ...[
              _FilterAndSearchBar(
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                searchQuery: _searchQuery,
                onSearchChanged: (q) => setState(() => _searchQuery = q),
                sortByYear: _sortByYear,
                onToggleSort: () => setState(() => _sortByYear = !_sortByYear),
                totalCount: _works.length,
                missingCount: missingCount,
                ownedCount: ownedCount,
              ),
              const SizedBox(height: 12),
            ],
            Expanded(child: _buildBody(theme, filtered)),
          ],
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

  Widget _buildBody(ThemeData theme, List<AuthorWork> filtered) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _works.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(_errorMessage ?? '', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (_selectedLanguage != 'fre')
                  OutlinedButton(
                    onPressed: () => _onLanguageChanged('fre'),
                    child: const Text('🇫🇷 Français'),
                  ),
                if (_selectedLanguage != 'eng')
                  OutlinedButton(
                    onPressed: () => _onLanguageChanged('eng'),
                    child: const Text('🇬🇧 Anglais'),
                  ),
                if (_selectedLanguage != 'spa')
                  OutlinedButton(
                    onPressed: () => _onLanguageChanged('spa'),
                    child: const Text('🇪🇸 Espagnol'),
                  ),
                if (_selectedLanguage != 'all')
                  OutlinedButton(
                    onPressed: () => _onLanguageChanged('all'),
                    child: const Text('🌐 Toutes'),
                  ),
                FilledButton.icon(
                  onPressed: _fetchWorks,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (filtered.isEmpty) {
      return const Center(
        child: Text('Aucun livre ne correspond aux filtres appliqués.'),
      );
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final work = filtered[index];
        return _AuthorWorkTile(
          work: work,
          onQuickAdd: () => _handleQuickAdd(work),
        );
      },
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final String authorName;
  final int totalCount;
  final int ownedCount;
  final int missingCount;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isTranslating;
  final int translationProgress;
  final int translationTotal;

  const _DialogHeader({
    required this.authorName,
    required this.totalCount,
    required this.ownedCount,
    required this.missingCount,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.isTranslating = false,
    this.translationProgress = 0,
    this.translationTotal = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ratio = totalCount > 0
        ? (ownedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;
    final percent = (ratio * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bibliographie de $authorName',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Catalogue Open Library & Comparatif de votre collection',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _LanguageSelector(
              selectedLanguage: selectedLanguage,
              onLanguageChanged: onLanguageChanged,
            ),
          ],
        ),
        if (totalCount > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderBadge(
                icon: Icons.library_books_rounded,
                label: '$totalCount œuvres',
                color: Colors.blue.shade700,
                bgColor: isDark
                    ? Colors.blue.shade900.withValues(alpha: 0.3)
                    : Colors.blue.shade50,
              ),
              const SizedBox(width: 8),
              _HeaderBadge(
                icon: Icons.check_circle_rounded,
                label: '$ownedCount possédées ($percent%)',
                color: Colors.green.shade700,
                bgColor: isDark
                    ? Colors.green.shade900.withValues(alpha: 0.3)
                    : Colors.green.shade50,
              ),
              const SizedBox(width: 8),
              _HeaderBadge(
                icon: Icons.bookmark_add_outlined,
                label: '$missingCount manquantes',
                color: Colors.orange.shade800,
                bgColor: isDark
                    ? Colors.orange.shade900.withValues(alpha: 0.3)
                    : Colors.orange.shade50,
              ),
              if (isTranslating && selectedLanguage != 'all') ...[
                const SizedBox(width: 8),
                _HeaderBadge(
                  icon: Icons.translate_rounded,
                  label: 'Traduction $translationProgress/$translationTotal',
                  color: Colors.purple.shade700,
                  bgColor: isDark
                      ? Colors.purple.shade900.withValues(alpha: 0.3)
                      : Colors.purple.shade50,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
          ),
        ],
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  const _LanguageSelector({
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = availableLanguages.firstWhere(
      (l) => l.code == selectedLanguage,
      orElse: () => availableLanguages.first,
    );

    return PopupMenuButton<String>(
      initialValue: selectedLanguage,
      onSelected: onLanguageChanged,
      tooltip: 'Sélectionner la langue des œuvres',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              current.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => availableLanguages.map((l) {
        return PopupMenuItem<String>(
          value: l.code,
          child: Row(
            children: [
              Text(l.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(l.label, overflow: TextOverflow.ellipsis)),
              if (l.code == selectedLanguage) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_rounded, size: 16, color: Colors.green),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterAndSearchBar extends StatelessWidget {
  final BibliographyFilter filter;
  final ValueChanged<BibliographyFilter> onFilterChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool sortByYear;
  final VoidCallback onToggleSort;
  final int totalCount;
  final int missingCount;
  final int ownedCount;

  const _FilterAndSearchBar({
    required this.filter,
    required this.onFilterChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.sortByYear,
    required this.onToggleSort,
    required this.totalCount,
    required this.missingCount,
    required this.ownedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SegmentedButton<BibliographyFilter>(
          segments: [
            ButtonSegment(
              value: BibliographyFilter.all,
              label: Text('Tous ($totalCount)'),
            ),
            ButtonSegment(
              value: BibliographyFilter.missing,
              label: Text('Manquants ($missingCount)'),
            ),
            ButtonSegment(
              value: BibliographyFilter.owned,
              label: Text('Possédés ($ownedCount)'),
            ),
          ],
          selected: {filter},
          onSelectionChanged: (set) => onFilterChanged(set.first),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Filtrer par titre ou année...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => onSearchChanged(''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: sortByYear
              ? 'Tri : Année (cliquer pour popularité)'
              : 'Tri : Popularité (cliquer pour année)',
          icon: Icon(
            sortByYear
                ? Icons.calendar_month_rounded
                : Icons.trending_up_rounded,
            size: 18,
          ),
          onPressed: onToggleSort,
        ),
      ],
    );
  }
}

class _AuthorWorkTile extends StatelessWidget {
  final AuthorWork work;
  final VoidCallback onQuickAdd;

  const _AuthorWorkTile({required this.work, required this.onQuickAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOwned = work.isOwned;

    final bgColor = isOwned
        ? (isDark
              ? Colors.green.shade900.withValues(alpha: 0.3)
              : Colors.green.shade50.withValues(alpha: 0.7))
        : (isDark ? Colors.grey.shade900 : Colors.white);

    final borderColor = isOwned
        ? Colors.green.shade600.withValues(alpha: 0.4)
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade300);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _CoverThumbnail(coverUrl: work.coverUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (work.originalTitle != null &&
                    work.originalTitle != work.title) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Titre original : ${work.originalTitle}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (work.firstPublishYear != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '1re parution : ${work.firstPublishYear}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${work.editionCount} éditions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusAction(work: work, onQuickAdd: onQuickAdd),
        ],
      ),
    );
  }
}

class _CoverThumbnail extends StatelessWidget {
  final String? coverUrl;

  const _CoverThumbnail({this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 56,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallbackCover(),
          ),
        ),
      );
    }
    return _fallbackCover();
  }

  Widget _fallbackCover() {
    return Container(
      width: 40,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.book_outlined, color: Colors.grey.shade500, size: 20),
    );
  }
}

class _StatusAction extends StatelessWidget {
  final AuthorWork work;
  final VoidCallback onQuickAdd;

  const _StatusAction({required this.work, required this.onQuickAdd});

  @override
  Widget build(BuildContext context) {
    final isOwned = work.isOwned;
    final matched = work.matchedBook;

    if (isOwned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              matched != null && matched.rating > 0
                  ? 'Dans la bibliothèque (${matched.rating}★)'
                  : 'Dans votre bibliothèque',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onQuickAdd,
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('Ajouter'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
