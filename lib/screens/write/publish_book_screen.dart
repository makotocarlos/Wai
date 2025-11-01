import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/books/presentation/cubit/book_form_cubit.dart';
import '../../features/books/presentation/cubit/book_form_state.dart';

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
      ..addListener(() => cubit.descriptionChanged(_descriptionController.text));
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

  Future<void> _editChapter({
    required BuildContext context,
    required int index,
    required ChapterDraftState chapter,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<BookFormCubit>(),
          child: ChapterEditorScreen(index: index, draft: chapter),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookFormCubit, BookFormState>(
      listener: (context, state) {
        if (state.status == BookFormStatus.failure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.status == BookFormStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Libro publicado con exito.')),
          );
          Navigator.of(context).pop();
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
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 28,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            'Añadir',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.labelSmall,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(coverPath),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
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
                        canDelete: i > 0, // Solo permitir borrar si no es el primero
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
                        child: Text('Publicar hasta capitulo ${state.chapters[i].order}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implementar ortografía IA
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ortografia IA - Proximamente')),
                      );
                    },
                    icon: const Icon(Icons.spellcheck),
                    label: const Text('Ortografia IA'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implementar chatbot IA
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chatbot IA - Proximamente')),
                      );
                    },
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
                      hintText: 'Escribe tu capitulo aqui...\n\nComienza a escribir tu historia...',
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
    );
  }
}
