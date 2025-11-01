import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/di/injection.dart';
import '../../features/books/domain/entities/book_entity.dart';
import '../../features/books/domain/entities/chapter_entity.dart';
import '../../features/books/domain/usecases/update_book.dart';
import '../../features/books/presentation/cubit/book_form_cubit.dart';
import '../../features/books/presentation/cubit/book_form_state.dart';
import '../write/publish_book_screen.dart';

class EditBookScreen extends StatefulWidget {
  const EditBookScreen({super.key, required this.book});

  final BookEntity book;

  @override
  State<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Inicializar el cubit con los datos del libro existente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<BookFormCubit>();

      // Cargar datos del libro
      cubit
        ..titleChanged(widget.book.title)
        ..descriptionChanged(widget.book.description)
        ..categoryChanged(widget.book.category);

      if (widget.book.coverPath != null && widget.book.coverPath!.isNotEmpty) {
        cubit.setCoverPath(widget.book.coverPath!);
      }

      // Cargar capítulos existentes (reemplaza los que vienen por defecto)
      cubit.loadExistingChapters(
        widget.book.chapters,
        publishedChapterIndex: widget.book.publishedChapterIndex,
      );

      // Establecer el índice de publicación DESPUÉS de cargar los capítulos
      cubit.setPublishIndex(widget.book.publishedChapterIndex);
    });

    _titleController
      ..text = widget.book.title
      ..addListener(() {
        context.read<BookFormCubit>().titleChanged(_titleController.text);
      });
    _descriptionController
      ..text = widget.book.description
      ..addListener(() {
        context
            .read<BookFormCubit>()
            .descriptionChanged(_descriptionController.text);
      });
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

  Future<void> _saveChanges() async {
    final cubit = context.read<BookFormCubit>();
    final state = cubit.state;

    // Validar que el título no esté vacío
    if (state.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega un título para tu libro')),
      );
      return;
    }

    try {
      final updateUseCase = sl<UpdateBookUseCase>();

      // Enviar todos los capítulos con su estado de publicación
      final updatedBook = await updateUseCase(
        bookId: widget.book.id,
        title: state.title != widget.book.title ? state.title : null,
        description: state.description != widget.book.description
            ? state.description
            : null,
        category:
            state.category != widget.book.category ? state.category : null,
        coverPath:
            state.coverPath != widget.book.coverPath ? state.coverPath : null,
        chapters: state.chapters.map((draft) {
          return ChapterEntity(
            id: draft.id,
            order: draft.order,
            title: draft.title.trim().isEmpty
                ? 'Capitulo ${draft.order}'
                : draft.title.trim(),
            content: draft.content.trim(),
            isPublished: draft.isPublished,
          );
        }).toList(),
        publishedChapterIndex: null, // Ya no usamos publishIndex
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Libro actualizado con éxito')),
        );
        Navigator.of(context).pop(updatedBook);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
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
      },
      builder: (context, state) {
        final cubit = context.read<BookFormCubit>();
        final coverPath = state.coverPath;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Editar libro'),
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
                    // Portada (Izquierda)
                    SizedBox(
                      width: 110,
                      child: Column(
                        children: [
                          Text(
                            'Cambiar portada',
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
                                      child: _buildCoverImage(coverPath),
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
                              labelText: 'Título',
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
                            value: state.category.isNotEmpty
                                ? state.category
                                : 'Fantasia',
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
                              labelText: 'Género',
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
                              labelText: 'Descripción',
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
                  'Capítulos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Edita, agrega o elimina capítulos de tu libro.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    for (int i = 0; i < state.chapters.length; i++)
                      _ChapterCard(
                        draft: state.chapters[i],
                        index: i,
                        canDelete: i > 0,
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
                  label: const Text('Agregar capítulo'),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _saveChanges,
                  child: const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const Icon(Icons.error),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
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
        border: draft.isPublished
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Capítulo ${draft.order}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  if (draft.isPublished)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Publicado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (draft.title.isNotEmpty)
            Text(
              draft.title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          const SizedBox(height: 8),
          Text(
            draft.content.isEmpty
                ? 'Sin contenido'
                : draft.content.length > 100
                    ? '${draft.content.substring(0, 100)}...'
                    : draft.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Editar'),
                ),
              ),
              if (!draft.isPublished) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: draft.content.trim().isEmpty
                        ? null
                        : () {
                            context.read<BookFormCubit>().publishChapter(index);
                          },
                    icon: const Icon(Icons.publish, size: 18),
                    label: const Text('Publicar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
