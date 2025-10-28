import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/usecases/create_book.dart';
import '../../domain/usecases/update_book.dart';
import '../cubit/book_composer_cubit.dart';
import '../cubit/book_composer_submission.dart';
import '../cubit/book_form_state.dart';

class CreateBookPage extends StatelessWidget {
  const CreateBookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookComposerCubit.create(createBook: sl<CreateBook>()),
      child: const _BookComposerPage(
        mode: BookComposerMode.create,
        submitLabel: 'Publicar libro',
        successMessage: 'Libro creado correctamente.',
      ),
    );
  }
}

class EditBookPage extends StatelessWidget {
  const EditBookPage({super.key, required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookComposerCubit.edit(updateBook: sl<UpdateBook>()),
      child: _BookComposerPage(
        mode: BookComposerMode.edit,
        submitLabel: 'Guardar cambios',
        successMessage: 'Cambios guardados.',
        initialBook: book,
      ),
    );
  }
}

class _BookComposerPage extends StatefulWidget {
  const _BookComposerPage({
    required this.mode,
    required this.submitLabel,
    required this.successMessage,
    this.initialBook,
  });

  final BookComposerMode mode;
  final String submitLabel;
  final String successMessage;
  final BookEntity? initialBook;

  @override
  State<_BookComposerPage> createState() => _BookComposerPageState();
}

class _BookComposerPageState extends State<_BookComposerPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final ImagePicker _picker;
  late List<_ChapterFormData> _chapters;
  late List<String> _categories;

  String? _selectedCategory;
  File? _coverFile;
  String? _existingCoverUrl;
  String? _existingCoverBase64;
  bool _removeExistingCover = false;
  int _publishedChapterIndex = 0;

  bool get _isEditing => widget.mode == BookComposerMode.edit;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _picker = ImagePicker();
    _categories = [
      'Fantasía',
      'Ciencia ficción',
      'Romance',
      'Terror',
      'Misterio',
      'Aventura',
      'Otros',
    ];

    if (_isEditing && widget.initialBook != null) {
      _initializeForEditing(widget.initialBook!);
    } else {
      _selectedCategory = _categories.first;
      _chapters = [_ChapterFormData(initialOrder: 0)];
    }
  }

  void _initializeForEditing(BookEntity book) {
    if (!_categories.contains(book.category)) {
      _categories.insert(0, book.category);
    }

    _selectedCategory = book.category;
    _titleController.text = book.title;
    _descriptionController.text = book.description ?? '';

    final sortedChapters = List<ChapterEntity>.from(book.chapters)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (sortedChapters.isEmpty) {
      _chapters = [_ChapterFormData(initialOrder: 0)];
      _publishedChapterIndex = 0;
    } else {
      _chapters = List.generate(sortedChapters.length, (index) {
        final chapter = sortedChapters[index];
        return _ChapterFormData(
          initialOrder: index,
          initialTitle: chapter.title,
          initialContent: chapter.content,
        );
      });
      _publishedChapterIndex =
          book.publishedChapterOrder.clamp(0, _chapters.length - 1);
    }

    _existingCoverUrl = book.coverUrl;
    _existingCoverBase64 = book.coverBase64;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final chapter in _chapters) {
      chapter.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          _isEditing ? 'Editar libro' : 'Publicar libro',
        ),
      ),
      body: BlocConsumer<BookComposerCubit, BookFormState>(
        listener: (context, state) {
          if (!mounted) return;
          if (state.status == BookFormStatus.success) {
            if (_isEditing) {
              Navigator.of(context).pop(true);
            } else {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(widget.successMessage)));
              _clearForm();
            }
          } else if (state.status == BookFormStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          final publishValue = _chapters.isEmpty
              ? 0
              : _publishedChapterIndex
                  .clamp(0, _chapters.length - 1)
                  .toInt();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Datos generales',
                      description: _isEditing
                          ? 'Actualiza la información principal de tu historia.'
                          : 'Define el título, género y descripción para captar a tus primeros lectores.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Título del libro'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa un título';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Categoría'),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          _inputDecoration('Descripción (opcional)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    _CoverPicker(
                      file: _coverFile,
                      imageUrl: _existingCoverUrl,
                      imageBase64: _existingCoverBase64,
                      onPick: _pickCover,
                      onClear: _clearCover,
                    ),
                    const SizedBox(height: 32),
                    const _SectionHeader(
                      title: 'Capítulos',
                      description:
                          'Divide tu historia en capítulos para que sea más fácil de seguir.',
                    ),
                    const SizedBox(height: 16),
                    for (final chapter in _chapters) ...[
                      _ChapterForm(
                        data: chapter,
                        onEdit: () => _openChapterEditor(chapter),
                        onRemove: _chapters.length > 1
                            ? () => _removeChapter(chapter)
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addChapter,
                        icon: const Icon(Icons.add,
                            color: Colors.greenAccent),
                        label: const Text(
                          'Agregar capítulo',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const _SectionHeader(
                      title: 'Publicación',
                      description:
                          'Elige qué capítulo queda visible. Los anteriores se publicarán automáticamente.',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: publishValue,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          _inputDecoration('Capítulo publicado'),
                      items: List.generate(
                        _chapters.length,
                        (index) => DropdownMenuItem(
                          value: index,
                          child: Text(_chapterDisplayName(index)),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _publishedChapterIndex = value);
                      },
                    ),
                    const SizedBox(height: 32),
                    const _SectionHeader(
                      title: 'Asistente IA (muy pronto)',
                      description:
                          'Estamos preparando sugerencias narrativas, sinopsis automáticas y recomendaciones de giros.',
                    ),
                    const SizedBox(height: 12),
                    const _AiPlaceholderCard(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: state.status == BookFormStatus.submitting
                            ? null
                            : () => _submit(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: state.status == BookFormStatus.submitting
                            ? const SizedBox.shrink()
                            : Icon(
                                _isEditing
                                    ? Icons.save_alt
                                    : Icons.cloud_upload,
                              ),
                        label: state.status == BookFormStatus.submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(widget.submitLabel),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _pickCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _coverFile = File(picked.path);
      _existingCoverUrl = null;
      _existingCoverBase64 = null;
      _removeExistingCover = false;
    });
  }

  void _clearCover() {
    setState(() {
      _coverFile = null;
      _existingCoverUrl = null;
      _existingCoverBase64 = null;
      _removeExistingCover = _isEditing;
    });
  }

  void _addChapter() {
    setState(() {
      _chapters.add(_ChapterFormData(initialOrder: _chapters.length));
      _reindexChapters();
    });
  }

  void _removeChapter(_ChapterFormData data) {
    setState(() {
      _chapters.remove(data);
      _reindexChapters();
      if (_publishedChapterIndex >= _chapters.length) {
        _publishedChapterIndex = _chapters.length - 1;
      }
    });
  }

  Future<void> _openChapterEditor(_ChapterFormData data) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChapterEditorPage(
          data: data,
          chapterNumber: data.order + 1,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _submit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final chapters = <ChapterEntity>[];
    for (var i = 0; i < _chapters.length; i++) {
      final data = _chapters[i];
      final title = data.titleController.text.trim();
      final content = data.contentController.text.trim();
      if (content.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
                content: Text('Completa el contenido de cada capítulo.')),
          );
        return;
      }
      chapters.add(
        ChapterEntity(
          title: title.isEmpty ? 'Capítulo ${i + 1}' : title,
          content: content,
          order: i,
          isPublished: i <= _publishedChapterIndex,
        ),
      );
    }

    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Agrega al menos un capítulo.')),
        );
      return;
    }

    final submission = BookComposerSubmission(
      bookId: widget.initialBook?.id,
      title: _titleController.text.trim(),
      category: _selectedCategory ?? _categories.first,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      chapters: chapters,
      coverFile: _coverFile,
      publishedChapterOrder: _publishedChapterIndex,
      removeCover: _isEditing && _removeExistingCover && _coverFile == null,
    );

    await context.read<BookComposerCubit>().submit(submission);
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = _categories.first;
      _coverFile = null;
      _existingCoverUrl = null;
      _existingCoverBase64 = null;
      _removeExistingCover = false;
      _publishedChapterIndex = 0;
      for (final chapter in _chapters) {
        chapter.dispose();
      }
      _chapters = [_ChapterFormData(initialOrder: 0)];
      _reindexChapters();
    });
  }

  void _reindexChapters() {
    for (var i = 0; i < _chapters.length; i++) {
      _chapters[i].order = i;
    }
    if (_chapters.isEmpty) {
      _publishedChapterIndex = 0;
    } else if (_publishedChapterIndex >= _chapters.length) {
      _publishedChapterIndex = _chapters.length - 1;
    }
  }

  String _chapterDisplayName(int index) {
    final title = _chapters[index].titleController.text.trim();
    if (title.isEmpty) {
      return 'Capítulo ${index + 1}';
    }
    return 'Capítulo ${index + 1} · $title';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

class _AiPlaceholderCard extends StatelessWidget {
  const _AiPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
  color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.auto_awesome, color: Colors.greenAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aquí aparecerán las herramientas inteligentes para generar sinopsis, sugerir escenas y mejorar tu narrativa.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.file,
    required this.imageUrl,
    required this.imageBase64,
    required this.onPick,
    required this.onClear,
  });

  final File? file;
  final String? imageUrl;
  final String? imageBase64;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasCover =
        file != null || (imageUrl != null && imageUrl!.isNotEmpty) ||
            (imageBase64 != null && imageBase64!.isNotEmpty);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoverPreview(
          file: file,
          imageUrl: imageUrl,
          imageBase64: imageBase64,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: onPick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.greenAccent,
                  ),
                  icon: const Icon(Icons.image),
                  label: const Text('Elegir portada'),
                ),
              ),
              if (hasCover)
                TextButton(
                  onPressed: onClear,
                  child: const Text(
                    'Quitar',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.file,
    required this.imageUrl,
    required this.imageBase64,
  });

  final File? file;
  final String? imageUrl;
  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    const size = 120.0;

    Widget child;
    if (file != null) {
      child = Image.file(
        file!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _coverPlaceholder();
        },
      );
    } else if (imageBase64 != null && imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(imageBase64!);
        child = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (_) {
        child = _coverPlaceholder();
      }
    } else {
      child = _coverPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size,
        height: size,
        child: child,
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.photo, color: Colors.white54, size: 40),
    );
  }
}

class _ChapterForm extends StatelessWidget {
  const _ChapterForm({
    required this.data,
    required this.onEdit,
    this.onRemove,
  });

  final _ChapterFormData data;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capítulo ${data.order + 1}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.titleController.text.trim().isEmpty
                ? 'Sin título'
                : data.titleController.text.trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.contentController.text.trim().isEmpty
                ? 'Aún no has escrito este capítulo. Toca "Editar" para comenzar.'
                : data.contentController.text.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, color: Colors.greenAccent),
              label: const Text(
                'Editar capítulo',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterFormData {
  _ChapterFormData({
    required int initialOrder,
    String? initialTitle,
    String? initialContent,
  })  : order = initialOrder,
        titleController = TextEditingController(text: initialTitle ?? ''),
        contentController = TextEditingController(text: initialContent ?? '');

  int order;
  final TextEditingController titleController;
  final TextEditingController contentController;

  void dispose() {
    titleController.dispose();
    contentController.dispose();
  }
}

class _ChapterEditorPage extends StatefulWidget {
  const _ChapterEditorPage({
    required this.data,
    required this.chapterNumber,
  });

  final _ChapterFormData data;
  final int chapterNumber;

  @override
  State<_ChapterEditorPage> createState() => _ChapterEditorPageState();
}

class _ChapterEditorPageState extends State<_ChapterEditorPage> {
  TextEditingController get _titleController => widget.data.titleController;

  TextEditingController get _contentController => widget.data.contentController;

  void _handleIaTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La asistencia con IA estará disponible próximamente.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Capítulo ${widget.chapterNumber}'),
        actions: [
          IconButton(
            onPressed: _handleIaTap,
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'Chat IA (próximamente)',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Editor de capítulo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _handleIaTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                    ),
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Text('Chat IA (pronto)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Título del capítulo (opcional)',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Escribe aquí tu historia sin límites...',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  expands: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
