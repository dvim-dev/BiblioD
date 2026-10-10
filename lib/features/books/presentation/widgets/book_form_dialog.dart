import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:bibliod/core/constants/app_constants.dart';
import 'package:bibliod/features/books/data/cover_storage_service.dart';
import 'package:bibliod/features/books/data/isbn_lookup_service.dart';
import 'package:bibliod/features/books/data/wikipedia_service.dart';
import 'package:bibliod/features/books/domain/author_item.dart';
import 'package:bibliod/features/books/domain/book.dart';
import 'package:bibliod/features/books/presentation/book_notifier.dart';
import 'author_wiki_dialog.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';

class BookFormDialog extends StatefulWidget {
  final Book? book;
  final BookNotifier bookNotifier;
  final SettingsNotifier? settingsNotifier;

  const BookFormDialog({
    super.key,
    this.book,
    required this.bookNotifier,
    this.settingsNotifier,
  });

  static Future<dynamic> show(
    BuildContext context, {
    Book? book,
    required BookNotifier bookNotifier,
    SettingsNotifier? settingsNotifier,
  }) {
    return showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BookFormDialog(
        book: book,
        bookNotifier: bookNotifier,
        settingsNotifier: settingsNotifier,
      ),
    );
  }

  @override
  State<BookFormDialog> createState() => _BookFormDialogState();
}

class _BookFormDialogState extends State<BookFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _lastNameController;
  late TextEditingController _firstNameController;
  late TextEditingController _seriesController;
  late TextEditingController _seriesNumberController;
  late TextEditingController _genreController;
  late TextEditingController _isbnController;
  late TextEditingController _remarksController;
  late TextEditingController _publisherController;
  late TextEditingController _yearController;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();

  late String _format;
  late int _rating;
  String? _coverImagePath;
  bool _isFetchingIsbn = false;
  bool _isFetchingWiki = false;
  bool _isSaving = false;

  final _isbnService = IsbnLookupService();
  final _wikiService = WikipediaService();
  final _coverStorage = CoverStorageService.instance;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    _titleController = TextEditingController(text: b?.title ?? '');
    _lastNameController = TextEditingController(text: b?.authorLastName ?? '');
    _firstNameController = TextEditingController(
      text: b?.authorFirstName ?? '',
    );
    _seriesController = TextEditingController(text: b?.series ?? '');

    final num = b?.seriesNumber;
    _seriesNumberController = TextEditingController(
      text: num != null
          ? (num % 1 == 0 ? num.toInt().toString() : num.toString())
          : '',
    );
    _genreController = TextEditingController(text: b?.genre ?? '');
    _isbnController = TextEditingController(text: b?.isbn ?? '');
    _remarksController = TextEditingController(text: b?.remarks ?? '');
    _publisherController = TextEditingController(text: b?.publisher ?? '');

    final yr = b?.publicationYear;
    _yearController = TextEditingController(
      text: yr != null ? yr.toString() : '',
    );

    final rawFormat = (b?.format ?? widget.bookNotifier.lastRegisteredFormat)
        .trim();
    if (rawFormat.toLowerCase().contains('num') ||
        rawFormat.toLowerCase().contains('ebook') ||
        rawFormat.toLowerCase().contains('pdf')) {
      _format = AppConstants.formatDigital;
    } else {
      _format = AppConstants.formatPhysical;
    }
    _rating = b?.rating ?? 0;
    _coverImagePath = b?.coverImagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _seriesController.dispose();
    _seriesNumberController.dispose();
    _genreController.dispose();
    _isbnController.dispose();
    _remarksController.dispose();
    _publisherController.dispose();
    _yearController.dispose();

    _titleFocusNode.dispose();
    _lastNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchIsbnData() async {
    final isbn = _isbnController.text.trim();
    if (isbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un numéro ISBN d\'abord.'),
        ),
      );
      return;
    }

    setState(() => _isFetchingIsbn = true);
    final result = await _isbnService.lookup(isbn);
    setState(() => _isFetchingIsbn = false);

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun livre trouvé sur Internet pour cet ISBN.'),
        ),
      );
      return;
    }

    if (result.title.isNotEmpty) {
      _titleController.text = result.title;
    }
    if (result.authorLastName.isNotEmpty) {
      _lastNameController.text = result.authorLastName;
    }
    if (result.authorFirstName.isNotEmpty) {
      _firstNameController.text = result.authorFirstName;
    }
    final resGenre = result.genre;
    if (resGenre != null && resGenre.isNotEmpty) {
      _genreController.text = resGenre;
    }
    final resPub = result.publisher;
    if (resPub != null && resPub.isNotEmpty) {
      _publisherController.text = resPub;
    }
    final resYear = result.publicationYear;
    if (resYear != null) {
      _yearController.text = resYear.toString();
    }
    final resRem = result.remarks;
    if (resRem != null && resRem.isNotEmpty) {
      _remarksController.text = resRem;
    }
    final resCover = result.coverImagePath;
    if (resCover != null) {
      setState(() {
        _coverImagePath = resCover;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Données du livre récupérées avec succès !'),
      ),
    );
  }

  Future<void> _fetchWikiAuthorInfo() async {
    final name = '${_firstNameController.text} ${_lastNameController.text}'
        .trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le nom de l\'auteur.'),
        ),
      );
      return;
    }

    setState(() => _isFetchingWiki = true);
    final wikiInfo = await _wikiService.fetchAuthorInfo(name);
    setState(() => _isFetchingWiki = false);

    if (!mounted) return;

    if (wikiInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune page Wikipédia trouvée pour "$name".')),
      );
      return;
    }

    AuthorWikiDialog.show(
      context,
      wikiInfo,
      bookNotifier: widget.bookNotifier,
      settingsNotifier: widget.settingsNotifier,
    );
  }

  Future<void> _pickCoverImage() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    final path = files.firstOrNull?.path;
    if (path != null) {
      final savedPath = await _coverStorage.saveCoverFile(path);
      if (savedPath != null) {
        setState(() {
          _coverImagePath = savedPath;
        });
      }
    }
  }

  Book? _buildBookFromForm() {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return null;

    final title = _titleController.text.trim();
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final series = _seriesController.text.trim();
    final seriesNumber = double.tryParse(
      _seriesNumberController.text.replaceAll(',', '.'),
    );
    final genre = _genreController.text.trim();
    final isbn = _isbnController.text.trim();
    final remarks = _remarksController.text.trim();
    final publisher = _publisherController.text.trim();
    final year = int.tryParse(_yearController.text.trim());

    final now = DateTime.now();

    return Book(
      id: widget.book?.id,
      title: title,
      authorLastName: lastName,
      authorFirstName: firstName,
      rating: _rating,
      series: series.isNotEmpty ? series : null,
      seriesNumber: seriesNumber,
      genre: genre.isNotEmpty ? genre : null,
      isbn: isbn.isNotEmpty ? isbn : null,
      format: _format,
      remarks: remarks.isNotEmpty ? remarks : null,
      publisher: publisher.isNotEmpty ? publisher : null,
      publicationYear: year,
      coverImagePath: _coverImagePath,
      createdAt: widget.book?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _handleSaveAndClose() async {
    final book = _buildBookFromForm();
    if (book == null) return;

    setState(() => _isSaving = true);
    if (widget.book?.id == null) {
      await widget.bookNotifier.addBook(book);
    } else {
      await widget.bookNotifier.updateBook(book);
    }
    setState(() => _isSaving = false);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _handleSaveAndSameAuthor() async {
    final book = _buildBookFromForm();
    if (book == null) return;

    setState(() => _isSaving = true);
    await widget.bookNotifier.addBook(book);
    setState(() => _isSaving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Livre "${book.title}" enregistré ! Prêt pour le suivant.',
        ),
      ),
    );

    // Conserver uniquement l'auteur
    setState(() {
      _titleController.clear();
      _seriesController.clear();
      _seriesNumberController.clear();
      _genreController.clear();
      _isbnController.clear();
      _remarksController.clear();
      _yearController.clear();
      _rating = 0;
      _coverImagePath = null;
    });

    _titleFocusNode.requestFocus();
  }

  Future<void> _handleSaveAndSameSeries() async {
    final book = _buildBookFromForm();
    if (book == null) return;

    setState(() => _isSaving = true);
    await widget.bookNotifier.addBook(book);
    setState(() => _isSaving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Livre "${book.title}" enregistré ! Prêt pour le tome suivant.',
        ),
      ),
    );

    // Conserver auteur, série, genre, éditeur, format, et incrémenter le tome si possible
    final currentTome = book.seriesNumber;
    final nextTomeStr = currentTome != null
        ? (currentTome + 1).toInt().toString()
        : '';

    setState(() {
      _titleController.clear();
      _isbnController.clear();
      _remarksController.clear();
      _seriesNumberController.text = nextTomeStr;
      _rating = 0;
      _coverImagePath = null;
    });

    _titleFocusNode.requestFocus();
  }

  Future<void> _handleSaveAndNewBook() async {
    final book = _buildBookFromForm();
    if (book == null) return;

    setState(() => _isSaving = true);
    await widget.bookNotifier.addBook(book);
    setState(() => _isSaving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Livre "${book.title}" enregistré ! Saisie vierge.'),
      ),
    );

    setState(() {
      _titleController.clear();
      _lastNameController.clear();
      _firstNameController.clear();
      _seriesController.clear();
      _seriesNumberController.clear();
      _genreController.clear();
      _isbnController.clear();
      _remarksController.clear();
      _publisherController.clear();
      _yearController.clear();
      _rating = 0;
      _format = AppConstants.formatPhysical;
      _coverImagePath = null;
    });

    _titleFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.book != null && widget.book?.id != null;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        children: [
          Icon(
            isEditing
                ? Icons.edit_note_rounded
                : Icons.add_circle_outline_rounded,
          ),
          const SizedBox(width: 10),
          Text(isEditing ? 'Modifier le livre' : 'Ajouter un livre'),
        ],
      ),
      content: SizedBox(
        width: 820,
        height: 530,
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverColumn(theme),
              const SizedBox(width: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIsbnBar(theme),
                      const SizedBox(height: 16),
                      _buildGeneralInfoSection(theme),
                      const SizedBox(height: 16),
                      _buildSeriesAndGenreSection(),
                      const SizedBox(height: 16),
                      _buildRatingAndFormatSection(theme),
                      const SizedBox(height: 16),
                      _buildPublisherSection(),
                      const SizedBox(height: 16),
                      _buildRemarksSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: _buildDialogActions(isEditing),
    );
  }

  List<Widget> _buildDialogActions(bool isEditing) {
    if (isEditing) {
      return [
        TextButton.icon(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop('delete'),
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _isSaving ? null : _handleSaveAndClose,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Enregistrer et fermer'),
            ),
          ],
        ),
      ];
    }

    return [
      OutlinedButton(
        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: _isSaving ? null : _handleSaveAndNewBook,
            child: const Text('Enregistrer et nouveau livre'),
          ),
          FilledButton.tonal(
            onPressed: _isSaving ? null : _handleSaveAndSameAuthor,
            child: const Text('Enregistrer et même auteur'),
          ),
          FilledButton.tonal(
            onPressed: _isSaving ? null : _handleSaveAndSameSeries,
            child: const Text('Enregistrer et même série'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _handleSaveAndClose,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Enregistrer et fermer'),
          ),
        ],
      ),
    ];
  }

  Widget _buildCoverColumn(ThemeData theme) {
    final imagePath = _coverImagePath;
    bool hasImage = false;
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        hasImage = File(imagePath).existsSync();
      } catch (_) {
        hasImage = false;
      }
    }

    return SizedBox(
      width: 170,
      child: Column(
        children: [
          Container(
            height: 240,
            width: 170,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage && imagePath != null
                ? Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image introuvable',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aucune couverture',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickCoverImage,
            icon: const Icon(Icons.image_outlined, size: 16),
            label: const Text('Choisir image', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(34),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          if (hasImage) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => setState(() => _coverImagePath = null),
              icon: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.grey,
              ),
              label: const Text(
                'Retirer',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIsbnBar(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _isbnController,
            decoration: const InputDecoration(
              labelText: 'ISBN (10 ou 13 chiffres)',
              hintText: 'ex: 9782070360024',
              prefixIcon: Icon(Icons.qr_code_rounded, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: _isFetchingIsbn ? null : _fetchIsbnData,
          icon: _isFetchingIsbn
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download_outlined, size: 18),
          label: const Text('Remplir via ISBN'),
        ),
      ],
    );
  }

  Widget _buildGeneralInfoSection(ThemeData theme) {
    return Column(
      children: [
        TextFormField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          decoration: const InputDecoration(
            labelText: 'Titre *',
            prefixIcon: Icon(Icons.title_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Le titre est obligatoire'
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildAuthorLastNameAutocomplete(theme)),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom de l\'auteur',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Consulter la biographie Wikipédia France',
              child: IconButton.filledTonal(
                onPressed: _isFetchingWiki ? null : _fetchWikiAuthorInfo,
                icon: _isFetchingWiki
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.info_outline_rounded, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthorLastNameAutocomplete(ThemeData theme) {
    return RawAutocomplete<AuthorItem>(
      textEditingController: _lastNameController,
      focusNode: _lastNameFocusNode,
      displayStringForOption: (option) => option.lastName,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return const Iterable<AuthorItem>.empty();
        }

        return widget.bookNotifier.distinctAuthors.where((author) {
          return author.lastName.toLowerCase().contains(query) ||
              author.displayName.toLowerCase().contains(query);
        });
      },
      onSelected: (AuthorItem selection) {
        _lastNameController.text = selection.lastName;
        if (selection.firstName.isNotEmpty) {
          _firstNameController.text = selection.firstName;
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Nom de l\'auteur *',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
            helperText: 'Aide à la saisie active',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_rounded, size: 16),
                    title: Text(
                      option.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: option.firstName.isNotEmpty
                        ? Text(
                            'Nom: ${option.lastName} • Prénom: ${option.firstName}',
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeriesAndGenreSection() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _seriesController,
            decoration: const InputDecoration(
              labelText: 'Série',
              prefixIcon: Icon(Icons.collections_bookmark_outlined, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: _seriesNumberController,
            decoration: const InputDecoration(
              labelText: 'N° Tome',
              hintText: 'ex: 1',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _genreController,
            decoration: const InputDecoration(
              labelText: 'Genre',
              hintText: 'Roman, SF, Essai...',
              prefixIcon: Icon(Icons.category_outlined, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingAndFormatSection(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Appréciation',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _rating = _rating == starIndex ? 0 : starIndex;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          starIndex <= _rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: starIndex <= _rating
                              ? const Color(0xFFD49B35)
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: AppConstants.bookFormats.contains(_format)
                ? _format
                : AppConstants.formatPhysical,
            decoration: const InputDecoration(
              labelText: 'Support',
              prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
            ),
            items: AppConstants.bookFormats.map((fmt) {
              return DropdownMenuItem(value: fmt, child: Text(fmt));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _format = val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPublisherSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _publisherController,
            decoration: const InputDecoration(
              labelText: 'Éditeur',
              prefixIcon: Icon(Icons.business_outlined, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: _yearController,
            decoration: const InputDecoration(
              labelText: 'Année',
              hintText: 'ex: 2024',
              prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildRemarksSection() {
    return TextFormField(
      controller: _remarksController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Remarques / Synopsis',
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 40),
          child: Icon(Icons.notes_rounded, size: 18),
        ),
      ),
    );
  }
}
