import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/di/injection.dart';
import '../../features/books/presentation/cubit/book_form_cubit.dart';
import '../../features/books/presentation/cubit/book_form_state.dart';
import '../../features/books/presentation/cubit/chapter_ai_cubit.dart';
import '../../features/books/presentation/cubit/chapter_ai_state.dart';
import '../../services/ai/gemini_search_service.dart';

class PublishBookScreen extends StatefulWidget {
  const PublishBookScreen({super.key});

  @override
  State<PublishBookScreen> createState() => _PublishBookScreenState();
}

class _PublishBookScreenState extends State<PublishBookScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<BookFormCubit>();
    final state = cubit.state;
    _titleController
      ..text = state.title
      ..addListener(() => cubit.titleChanged(_titleController.text));
    _descriptionController
      ..text = state.description
      ..addListener(
          () => cubit.descriptionChanged(_descriptionController.text));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCover(BookFormCubit cubit) async {
    final result = await _picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      cubit.coverPicked(File(result.path));
    }
  }

  Widget _buildCoverPreview(String path) {
    if (_isRemotePath(path)) {
      if (path.trim().toLowerCase().startsWith('data:')) {
        try {
          final commaIndex = path.indexOf(',');
          final data = commaIndex >= 0 ? path.substring(commaIndex + 1) : path;
          final bytes = base64Decode(data);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
          );
        } catch (_) {
          return const Icon(Icons.broken_image_outlined);
        }
      }
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
    );
  }

  bool _isRemotePath(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('data:');
  }

  Future<void> _editChapter({
    required BuildContext context,
    required int index,
    required ChapterDraftState chapter,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: context.read<BookFormCubit>(),
            ),
            BlocProvider(
              create: (_) => sl<ChapterAiCubit>(),
            ),
          ],
          child: ChapterEditorScreen(index: index, draft: chapter),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookFormCubit, BookFormState>(
      listener: (context, state) {
        if (state.status == BookFormStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.status == BookFormStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Libro publicado con exito.')),
          );
          Navigator.of(context).pop(state.lastCreatedBook);
        }
      },
      builder: (context, state) {
        final cubit = context.read<BookFormCubit>();
        final coverPath = state.coverPath;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Publicar libro'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Layout horizontal: Portada + Datos generales
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Portada (Izquierda) - más pequeña
                    SizedBox(
                      width: 110,
                      child: Column(
                        children: [
                          Text(
                            'Añadir portada',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _pickCover(cubit),
                            child: Container(
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context).colorScheme.surface,
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: coverPath == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 28,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            'Añadir',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildCoverPreview(coverPath),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Datos generales (Derecha)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Añadir titulo',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: state.category,
                            items: const [
                              'Fantasia',
                              'Ciencia ficcion',
                              'Romance',
                              'Suspenso',
                              'Terror',
                              'Drama contemporaneo',
                            ]
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                cubit.categoryChanged(value);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Escoger genero',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Descripcion',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              contentPadding: const EdgeInsets.all(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Capitulos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Divide tu historia en partes y trabaja cada borrador por separado.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    for (int i = 0; i < state.chapters.length; i++)
                      _ChapterCard(
                        draft: state.chapters[i],
                        index: i,
                        canDelete:
                            i > 0, // Solo permitir borrar si no es el primero
                        onEdit: () => _editChapter(
                          context: context,
                          index: i,
                          chapter: state.chapters[i],
                        ),
                        onDelete: () => cubit.removeChapter(i),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: cubit.addChapter,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar capitulo'),
                ),
                const SizedBox(height: 28),
                DropdownButtonFormField<int>(
                  value: state.publishIndex,
                  items: [
                    for (int i = 0; i < state.chapters.length; i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                            'Publicar hasta capitulo ${state.chapters[i].order}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      cubit.setPublishIndex(value);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Capitulo publicado',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Asistente IA (muy pronto)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estamos preparando sugerencias narrativas, sinopsis automaticas y giros recomendados.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aqui apareceran herramientas inteligentes para ayudarte a generar ideas y mejorar tu narrativa.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final maxWidth = constraints.maxWidth;
                    final itemsPerRow = maxWidth >= 600
                        ? 3
                        : maxWidth >= 420
                            ? 2
                            : 1;
                    final buttonWidth =
                        (maxWidth - spacing * (itemsPerRow - 1)) / itemsPerRow;

                    final buttons = const [
                      _SoonActionButton(label: 'Compartir (pronto)'),
                      _SoonActionButton(label: 'Editar portada (pronto)'),
                      _SoonActionButton(label: 'Pagina completa (pronto)'),
                    ];

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: buttons
                          .map(
                            (button) => SizedBox(
                              width: buttonWidth,
                              child: button,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: state.status == BookFormStatus.submitting
                      ? null
                      : cubit.submit,
                  child: state.status == BookFormStatus.submitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Publicar libro'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.draft,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.canDelete,
  });

  final ChapterDraftState draft;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capitulo ${draft.order}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: () {
                    // Mostrar confirmación antes de borrar
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar capitulo'),
                        content: Text(
                          '¿Estas seguro de eliminar el Capitulo ${draft.order}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onDelete();
                            },
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar capitulo',
                  color: Colors.red,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            draft.title.isEmpty ? 'Sin titulo' : draft.title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            draft.content.isEmpty
                ? 'Aun no has escrito este capitulo. Toca "Editar" para comenzar.'
                : draft.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Editar capitulo'),
          ),
        ],
      ),
    );
  }
}

class _SoonActionButton extends StatelessWidget {
  const _SoonActionButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: () {},
      child: Text(label),
    );
  }
}

class ChapterEditorScreen extends StatefulWidget {
  const ChapterEditorScreen({
    super.key,
    required this.index,
    required this.draft,
  });

  final int index;
  final ChapterDraftState draft;

  @override
  State<ChapterEditorScreen> createState() => _ChapterEditorScreenState();
}

class _ChapterEditorScreenState extends State<ChapterEditorScreen> {
  late final TextEditingController _chapterTitleController;
  late final TextEditingController _chapterNotesController;

  @override
  void initState() {
    super.initState();
    _chapterTitleController = TextEditingController(text: widget.draft.title);
    _chapterNotesController = TextEditingController(text: widget.draft.content);
  }

  @override
  void dispose() {
    _chapterTitleController.dispose();
    _chapterNotesController.dispose();
    super.dispose();
  }

  void _saveChapter() {
    context.read<BookFormCubit>().updateChapter(
          widget.index,
          title: _chapterTitleController.text.trim(),
          content: _chapterNotesController.text.trim(),
        );
    Navigator.of(context).pop();
  }

  List<String> _previousChaptersContent() {
    final chapters = context.read<BookFormCubit>().state.chapters;
    return chapters
        .where((chapter) => chapter.order < widget.draft.order)
        .map((chapter) => chapter.content)
        .where((content) => content.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
  }

  ChapterStoryContext _buildStoryContext() {
    final bookState = context.read<BookFormCubit>().state;
    final bookTitle = bookState.title.trim().isEmpty
        ? 'Libro sin titulo'
        : bookState.title.trim();
    final chapterTitle = _chapterTitleController.text.trim().isEmpty
        ? 'Capitulo ${widget.draft.order}'
        : _chapterTitleController.text.trim();

    return ChapterStoryContext(
      bookTitle: bookTitle,
      chapterTitle: chapterTitle,
      chapterContent: _chapterNotesController.text,
      synopsis: bookState.description.trim().isEmpty
          ? null
          : bookState.description.trim(),
      previousChapters: _previousChaptersContent(),
      readerComments: const [],
    );
  }

  void _insertTextAtCursor(String value) {
    final controller = _chapterNotesController;
    final selection = controller.selection;
    final text = controller.text;
    if (!selection.isValid) {
      controller
        ..text = '$text$value'
        ..selection = TextSelection.collapsed(offset: controller.text.length);
      return;
    }
    final newText = text.replaceRange(selection.start, selection.end, value);
    final newOffset = selection.start + value.length;
    controller
      ..text = newText
      ..selection = TextSelection.collapsed(offset: newOffset);
  }

  Future<void> _openProofreadingSheet() async {
    final cubit = context.read<ChapterAiCubit>();
    cubit.resetProofreading();
    final story = _buildStoryContext();
    cubit.proofreadChapter(
      bookTitle: story.bookTitle,
      chapterTitle: story.chapterTitle,
      chapterContent: story.chapterContent,
      previousChapters: story.previousChapters,
      synopsis: story.synopsis,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => BlocProvider.value(
        value: cubit,
        child: _ChapterProofreadingSheet(
          onApply: (text) {
            _chapterNotesController.text = text;
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  Future<void> _openChatbotSheet() async {
    final aiCubit = context.read<ChapterAiCubit>();
    final bookCubit = context.read<BookFormCubit>();
    final draft = bookCubit.state.chapters[widget.index];

    aiCubit.hydrateChat(
      messages: draft.chatHistory,
      ideas: draft.chatIdeas,
      nextSteps: draft.chatNextSteps,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => BlocProvider.value(
        value: aiCubit,
        child: _ChapterChatSheet(
          storyContextBuilder: _buildStoryContext,
          onInsertText: _insertTextAtCursor,
        ),
      ),
    );

    final aiState = aiCubit.state;
    bookCubit.updateChapterChat(
      widget.index,
      messages: aiState.chatMessages,
      ideas: aiState.chatIdeas,
      nextSteps: aiState.chatNextSteps,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChapterAiCubit, ChapterAiState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Capitulo ${widget.draft.order}'),
          actions: [
            IconButton(
              onPressed: _saveChapter,
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: 'Guardar',
            ),
          ],
        ),
        body: Column(
          children: [
            // Navbar fijo con herramientas IA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openProofreadingSheet,
                      icon: const Icon(Icons.spellcheck),
                      label: const Text('Ortografia IA'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openChatbotSheet,
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Chatbot IA'),
                    ),
                  ),
                ],
              ),
            ),
            // Área de escritura scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Titulo capitulo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _chapterTitleController,
                      decoration: InputDecoration(
                        hintText: 'Escribe el titulo del capitulo...',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Escribir',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _chapterNotesController,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      maxLines: null,
                      minLines: 20,
                      decoration: InputDecoration(
                        alignLabelWithHint: true,
                        hintText:
                            'Escribe tu capitulo aqui...\n\nComienza a escribir tu historia...',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveChapter,
          icon: const Icon(Icons.save),
          label: const Text('Guardar capitulo'),
        ),
      ),
    );
  }
}

class _ChapterProofreadingSheet extends StatelessWidget {
  const _ChapterProofreadingSheet({required this.onApply});

  final ValueChanged<String> onApply;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + viewInsets),
        child: BlocBuilder<ChapterAiCubit, ChapterAiState>(
          builder: (context, state) {
            if (state.isProofreading) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final result = state.proofreadingResult;
            if (result == null) {
              return const SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    'Esperando la corrección... Si no ocurre nada, intenta de nuevo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final availableHeight = MediaQuery.of(context).size.height * 0.65;
            return SizedBox(
              height: availableHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Correcciones sugeridas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              result.correctedText,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (result.summary != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Resumen de cambios',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              result.summary!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          if (result.notes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Notas del editor',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final note in result.notes)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('• '),
                                        Expanded(
                                          child: Text(
                                            note,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => onApply(result.correctedText),
                          icon: const Icon(Icons.content_copy_outlined),
                          label: const Text('Aplicar correcciones'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChapterChatSheet extends StatefulWidget {
  const _ChapterChatSheet({
    required this.storyContextBuilder,
    this.onInsertText,
  });

  final ChapterStoryContext Function() storyContextBuilder;
  final ValueChanged<String>? onInsertText;

  @override
  State<_ChapterChatSheet> createState() => _ChapterChatSheetState();
}

class _ChapterChatSheetState extends State<_ChapterChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final cubit = context.read<ChapterAiCubit>();
    cubit.sendChatMessage(
      message: text,
      storyContext: widget.storyContextBuilder(),
    );
    _messageController.clear();
  }

  void _exploreIdea(String idea) {
    final cubit = context.read<ChapterAiCubit>();
    cubit.sendChatMessage(
      message: 'Desarrolla la siguiente idea en detalle: $idea',
      storyContext: widget.storyContextBuilder(),
    );
  }

  Future<void> _openIdeaPreview(String idea) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IdeaPreviewSheet(
        ideaText: idea,
        onClose: () => Navigator.of(ctx).pop(),
        onInsert: widget.onInsertText == null
            ? null
            : () {
                widget.onInsertText!(idea);
                Navigator.of(ctx).pop();
              },
        onExplore: () {
          Navigator.of(ctx).pop();
          _exploreIdea(idea);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final availableHeight = ((mediaQuery.size.height - bottomInset) * 0.9)
        .clamp(320.0, 720.0)
        .toDouble();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: SizedBox(
          height: availableHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chatbot IA',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<ChapterAiCubit, ChapterAiState>(
                  builder: (context, state) {
                    if (state.chatMessages.length != _lastMessageCount) {
                      _lastMessageCount = state.chatMessages.length;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || !_scrollController.hasClients) return;
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      });
                    }

                    final children = <Widget>[];

                    for (final message in state.chatMessages) {
                      final isUser = message.isUser;
                      final alignment =
                          isUser ? Alignment.centerRight : Alignment.centerLeft;
                      final bubbleColor = isUser
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.15)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.3);

                      children.add(
                        Align(
                          alignment: alignment,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              message.content,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      );
                    }

                    if (state.chatIdeas.isNotEmpty) {
                      children.addAll([
                        const SizedBox(height: 16),
                        Text(
                          'Ideas sugeridas',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final idea in state.chatIdeas)
                              ActionChip(
                                label: SizedBox(
                                  width: 200,
                                  child: Text(
                                    idea,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                onPressed: () => _openIdeaPreview(idea),
                              ),
                          ],
                        ),
                      ]);
                    }

                    if (state.chatNextSteps.isNotEmpty) {
                      children.addAll([
                        const SizedBox(height: 16),
                        Text(
                          'Siguientes pasos',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final step in state.chatNextSteps)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $step'),
                              ),
                          ],
                        ),
                      ]);
                    }

                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 24),
                      children: children,
                    );
                  },
                ),
              ),
              BlocBuilder<ChapterAiCubit, ChapterAiState>(
                buildWhen: (previous, current) =>
                    previous.isChatLoading != current.isChatLoading,
                builder: (context, state) {
                  if (!state.isChatLoading) {
                    return const SizedBox.shrink();
                  }
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu mensaje para la IA...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _sendMessage,
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdeaPreviewSheet extends StatelessWidget {
  const _IdeaPreviewSheet({
    required this.ideaText,
    required this.onClose,
    this.onInsert,
    this.onExplore,
  });

  final String ideaText;
  final VoidCallback onClose;
  final VoidCallback? onInsert;
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    final formatted = ideaText.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Idea sugerida',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                formatted,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: formatted));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Idea copiada al portapapeles.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar'),
                ),
                if (onInsert != null)
                  FilledButton.icon(
                    onPressed: onInsert,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Insertar en el capitulo'),
                  ),
                if (onExplore != null)
                  OutlinedButton.icon(
                    onPressed: onExplore,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Desarrollar con la IA'),
                  ),
                OutlinedButton(
                  onPressed: onClose,
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
