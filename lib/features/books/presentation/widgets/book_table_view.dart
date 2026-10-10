import 'package:flutter/material.dart';
import 'package:bibliod/core/constants/app_constants.dart';
import 'package:bibliod/features/books/domain/book.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';

class BookTableView extends StatefulWidget {
  final BookNotifier bookNotifier;
  final SettingsNotifier settingsNotifier;
  final ValueChanged<Book> onBookDoubleTap;

  const BookTableView({
    super.key,
    required this.bookNotifier,
    required this.settingsNotifier,
    required this.onBookDoubleTap,
  });

  static double getColumnWidth(String colKey, [double fontSizeDelta = 0.0]) {
    final base = switch (colKey) {
      AppConstants.colAuthorLastName => 150.0,
      AppConstants.colAuthorFirstName => 130.0,
      AppConstants.colTitle => 280.0,
      AppConstants.colRating => 125.0,
      AppConstants.colSeries => 170.0,
      AppConstants.colSeriesNumber => 85.0,
      AppConstants.colGenre => 140.0,
      AppConstants.colIsbn => 145.0,
      AppConstants.colFormat => 115.0,
      AppConstants.colRemarks => 280.0,
      _ => 130.0,
    };
    return base + (fontSizeDelta * 8.0);
  }

  @override
  State<BookTableView> createState() => _BookTableViewState();
}

class _BookTableViewState extends State<BookTableView> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_syncFromRows);
    _headerScrollController.addListener(_syncFromHeader);
  }

  void _syncFromRows() {
    if (_isSyncingScroll) return;
    if (_headerScrollController.hasClients &&
        _headerScrollController.offset != _horizontalController.offset) {
      _isSyncingScroll = true;
      _headerScrollController.jumpTo(_horizontalController.offset);
      _isSyncingScroll = false;
    }
  }

  void _syncFromHeader() {
    if (_isSyncingScroll) return;
    if (_horizontalController.hasClients &&
        _horizontalController.offset != _headerScrollController.offset) {
      _isSyncingScroll = true;
      _horizontalController.jumpTo(_headerScrollController.offset);
      _isSyncingScroll = false;
    }
  }

  @override
  void dispose() {
    _horizontalController.removeListener(_syncFromRows);
    _headerScrollController.removeListener(_syncFromHeader);
    _horizontalController.dispose();
    _headerScrollController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final books = widget.bookNotifier.books;
    final visibleCols = widget.settingsNotifier.visibleColumns;
    final fontSizeDelta = widget.settingsNotifier.listFontSizeDelta;
    final rowHeight = (40.0 + fontSizeDelta * 2.5).clamp(32.0, 70.0);
    final headerHeight = (42.0 + fontSizeDelta * 2.0).clamp(34.0, 72.0);

    if (widget.bookNotifier.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              widget.bookNotifier.searchQuery.isNotEmpty
                  ? 'Aucun livre ne correspond à votre recherche.'
                  : 'Aucun livre dans votre bibliothèque.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez un livre ou importez un fichier CSV pour commencer.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final totalWidth = visibleCols.fold<double>(
      0.0,
      (sum, colKey) =>
          sum + BookTableView.getColumnWidth(colKey, fontSizeDelta),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = totalWidth > constraints.maxWidth
            ? totalWidth
            : constraints.maxWidth;

        return Column(
          children: [
            _buildHeaderScrollView(
              tableWidth,
              constraints.maxWidth,
              headerHeight,
              fontSizeDelta,
              visibleCols,
              theme,
              isDark,
            ),
            Expanded(
              child: _buildRowsView(
                tableWidth,
                rowHeight,
                fontSizeDelta,
                visibleCols,
                books,
                theme,
                isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderScrollView(
    double tableWidth,
    double maxWidth,
    double headerHeight,
    double fontSizeDelta,
    List<String> visibleCols,
    ThemeData theme,
    bool isDark,
  ) {
    return SizedBox(
      height: headerHeight,
      width: maxWidth,
      child: SingleChildScrollView(
        controller: _headerScrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: tableWidth,
          child: _buildHeaderRow(
            visibleCols,
            theme,
            isDark,
            headerHeight,
            fontSizeDelta,
          ),
        ),
      ),
    );
  }

  Widget _buildRowsView(
    double tableWidth,
    double rowHeight,
    double fontSizeDelta,
    List<String> visibleCols,
    List<Book> books,
    ThemeData theme,
    bool isDark,
  ) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.vertical,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView.builder(
                controller: _verticalController,
                itemCount: books.length,
                itemExtent: rowHeight,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final isEven = index % 2 == 0;
                  return _BookTableRow(
                    book: book,
                    visibleCols: visibleCols,
                    isEven: isEven,
                    isDark: isDark,
                    theme: theme,
                    fontSizeDelta: fontSizeDelta,
                    rowHeight: rowHeight,
                    onDoubleTap: () => widget.onBookDoubleTap(book),
                    onRatingChanged: (newRating) {
                      widget.bookNotifier.updateBookRating(book, newRating);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    List<String> visibleCols,
    ThemeData theme,
    bool isDark,
    double headerHeight,
    double fontSizeDelta,
  ) {
    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232B) : const Color(0xFFEAECEF),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2B323E) : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: visibleCols.map((colKey) {
          final width = BookTableView.getColumnWidth(colKey, fontSizeDelta);
          final label = AppConstants.columnLabels[colKey] ?? colKey;
          final isSorted = widget.bookNotifier.sortColumn == colKey;
          final isAscending = widget.bookNotifier.sortAscending;

          return SizedBox(
            width: width,
            child: InkWell(
              onTap: () => widget.bookNotifier.sortBy(colKey),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: isSorted
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSorted ? theme.colorScheme.primary : null,
                          fontSize: (12.0 + fontSizeDelta).clamp(9.0, 20.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (isSorted)
                      Icon(
                        isAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: (14.0 + fontSizeDelta * 0.6).clamp(11.0, 20.0),
                        color: theme.colorScheme.primary,
                      )
                    else
                      Icon(
                        Icons.unfold_more_rounded,
                        size: (14.0 + fontSizeDelta * 0.6).clamp(11.0, 20.0),
                        color: Colors.grey,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BookTableRow extends StatelessWidget {
  final Book book;
  final List<String> visibleCols;
  final bool isEven;
  final bool isDark;
  final ThemeData theme;
  final double fontSizeDelta;
  final double rowHeight;
  final VoidCallback onDoubleTap;
  final ValueChanged<int> onRatingChanged;

  const _BookTableRow({
    required this.book,
    required this.visibleCols,
    required this.isEven,
    required this.isDark,
    required this.theme,
    required this.fontSizeDelta,
    required this.rowHeight,
    required this.onDoubleTap,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBg = isEven
        ? (isDark ? const Color(0xFF161A22) : Colors.white)
        : (isDark ? const Color(0xFF1A1F28) : const Color(0xFFF9FAFB));

    return Material(
      color: defaultBg,
      child: InkWell(
        onTap: () {},
        onDoubleTap: onDoubleTap,
        hoverColor: isDark ? const Color(0xFF2C3442) : Colors.blue.shade50,
        child: Container(
          height: rowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF222934) : Colors.grey.shade200,
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: visibleCols.map((colKey) {
              final width = BookTableView.getColumnWidth(colKey, fontSizeDelta);
              return SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildCellContent(colKey),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(String colKey) {
    final base13 = (13.0 + fontSizeDelta).clamp(9.0, 22.0);
    final base12 = (12.0 + fontSizeDelta).clamp(8.0, 20.0);
    final base11 = (11.0 + fontSizeDelta).clamp(8.0, 18.0);

    switch (colKey) {
      case AppConstants.colAuthorLastName:
        return Text(
          book.authorLastName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: base13),
        );
      case AppConstants.colAuthorFirstName:
        return Text(
          book.authorFirstName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: base13),
        );
      case AppConstants.colTitle:
        return Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: base13,
            color: theme.colorScheme.onSurface,
          ),
        );
      case AppConstants.colRating:
        return _buildRatingWidget(book.rating);
      case AppConstants.colSeries:
        return Text(
          book.series ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: base12),
        );
      case AppConstants.colSeriesNumber:
        final num = book.seriesNumber;
        return Text(
          num != null
              ? (num % 1 == 0 ? num.toInt().toString() : num.toString())
              : '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: base12),
        );
      case AppConstants.colGenre:
        return Text(
          book.genre ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: base12),
        );
      case AppConstants.colIsbn:
        return Text(
          book.isbn ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'monospace', fontSize: base11),
        );
      case AppConstants.colFormat:
        return _buildFormatBadge(book.format);
      case AppConstants.colRemarks:
        return Text(
          book.remarks ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: base12, color: Colors.grey.shade600),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildRatingWidget(int rating) {
    final starSize = (16.0 + fontSizeDelta * 0.8).clamp(13.0, 22.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = starValue <= rating;
        final isCurrentRating = starValue == rating;

        return Tooltip(
          message: isCurrentRating
              ? 'Retirer la note'
              : 'Attribuer $starValue étoile${starValue > 1 ? 's' : ''}',
          waitDuration: const Duration(milliseconds: 300),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final newRating = isCurrentRating ? 0 : starValue;
              onRatingChanged(newRating);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 1.0,
                vertical: 4.0,
              ),
              child: Icon(
                isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                size: starSize,
                color: isFilled
                    ? const Color(0xFFD49B35)
                    : Colors.grey.shade400,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFormatBadge(String format) {
    final isDigital = format == AppConstants.formatDigital;
    final color = isDigital ? Colors.teal : Colors.indigo;
    final iconSize = (12.0 + fontSizeDelta * 0.6).clamp(10.0, 18.0);
    final badgeFontSize = (10.5 + fontSizeDelta * 0.6).clamp(8.0, 16.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDigital ? Icons.tablet_mac_rounded : Icons.menu_book_rounded,
            size: iconSize,
            color: color,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              format,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: badgeFontSize,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
