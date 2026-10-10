import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';

class ToolbarWidget extends StatefulWidget {
  final BookNotifier bookNotifier;
  final SettingsNotifier settingsNotifier;
  final VoidCallback onAddBook;
  final VoidCallback onShowColumns;
  final VoidCallback onShowStatistics;
  final VoidCallback onOpenSettings;

  const ToolbarWidget({
    super.key,
    required this.bookNotifier,
    required this.settingsNotifier,
    required this.onAddBook,
    required this.onShowColumns,
    required this.onShowStatistics,
    required this.onOpenSettings,
  });

  @override
  State<ToolbarWidget> createState() => _ToolbarWidgetState();
}

class _ToolbarWidgetState extends State<ToolbarWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.bookNotifier.searchQuery;
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      widget.bookNotifier.setSearchQuery(value);
    });
    setState(() {});
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2B323E) : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildAppLogo(theme),
            const SizedBox(width: 16),
            _buildOmnibox(context),
            const SizedBox(width: 16),
            _buildActions(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLogo(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'BiblioD',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOmnibox(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 500),
      child: SizedBox(
        width: 350,
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText:
                'Recherche omnibox (titre, auteur, série, ISBN, genre, remarques)...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _debounceTimer?.cancel();
                      _searchController.clear();
                      widget.bookNotifier.clearSearch();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: widget.onAddBook,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Nouveau livre'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: widget.onShowColumns,
          icon: const Icon(Icons.view_column_rounded, size: 18),
          label: const Text('Colonnes'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: widget.onShowStatistics,
          icon: const Icon(Icons.bar_chart_rounded, size: 18),
          label: const Text('Statistiques'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: widget.onOpenSettings,
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: const Text('Paramètres'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 8),
        _buildFontSizeControls(theme),
        const SizedBox(width: 8),
        _buildThemeToggle(theme),
      ],
    );
  }

  Widget _buildFontSizeControls(ThemeData theme) {
    final delta = widget.settingsNotifier.listFontSizeDelta;
    final percent = (100 + (delta * 10)).round();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.text_decrease_rounded, size: 18),
            tooltip: 'Diminuer la taille du texte',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: delta > -2.0
                ? () => widget.settingsNotifier.decreaseListFontSize()
                : null,
          ),
          Tooltip(
            message: 'Réinitialiser la taille du texte (100%)',
            child: InkWell(
              onTap: delta != 0.0
                  ? () => widget.settingsNotifier.resetListFontSize()
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '$percent%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase_rounded, size: 18),
            tooltip: 'Augmenter la taille du texte',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: delta < 6.0
                ? () => widget.settingsNotifier.increaseListFontSize()
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(ThemeData theme) {
    final currentMode = widget.settingsNotifier.themeMode;
    return Tooltip(
      message: 'Basculer le thème',
      child: IconButton(
        icon: Icon(
          currentMode == ThemeMode.dark
              ? Icons.dark_mode_rounded
              : currentMode == ThemeMode.light
              ? Icons.light_mode_rounded
              : Icons.brightness_auto_rounded,
        ),
        onPressed: () {
          final nextMode = switch (currentMode) {
            ThemeMode.light => ThemeMode.dark,
            ThemeMode.dark => ThemeMode.system,
            ThemeMode.system => ThemeMode.light,
          };
          widget.settingsNotifier.setThemeMode(nextMode);
        },
      ),
    );
  }
}
