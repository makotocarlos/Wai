import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/books/domain/entities/book_entity.dart';
import '../../features/books/domain/usecases/watch_books.dart';
import '../../features/books/presentation/cubit/book_form_cubit.dart';
import '../../features/books/presentation/cubit/book_list_cubit.dart';
import '../../features/books/presentation/cubit/book_list_state.dart';
import '../../features/books/presentation/cubit/books_event_bus.dart';
import '../../features/books/presentation/pages/book_detail_page.dart';
import '../library/edit_book_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookListCubit(
        watchBooks: sl<WatchBooksUseCase>(),
        user: user,
        onlyUserBooks: true,
        eventsBus: sl(),
      )..start(),
      child: BlocBuilder<BookListCubit, BookListState>(
        builder: (context, state) {
          switch (state.status) {
            case BookListStatus.initial:
            case BookListStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case BookListStatus.failure:
              return _LibraryErrorView(
                message: state.errorMessage ??
                    'Ocurrio un problema al cargar tus libros.',
                onRetry: () => context.read<BookListCubit>().start(),
              );
            case BookListStatus.success:
              if (state.books.isEmpty) {
                return const _LibraryPlaceholder(
                  'Aun no tienes libros publicados. Escribe uno desde la pestaña "Escribir".',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                itemBuilder: (context, index) => _LibraryBookCard(
                  book: state.books[index],
                ),
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemCount: state.books.length,
              );
          }
        },
      ),
    );
  }
}

class _LibraryBookCard extends StatelessWidget {
  const _LibraryBookCard({required this.book});

  final BookEntity book;

  void _showOptionsMenu(BuildContext context) {
    // Pasar el cubit al modal usando BlocProvider.value
    final cubit = context.read<BookListCubit>();
    showModalBottomSheet<void>(
      context: context,
      builder: (modalContext) => BlocProvider.value(
        value: cubit,
        child: _BookOptionsMenu(book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalChapters = book.chapters.length;
    // Usar is_published si está disponible, sino usar publishedChapterIndex
    final publishedByFlag = book.chapters.where((ch) => ch.isPublished).length;
    final publishedByIndex = totalChapters > 0
        ? (book.publishedChapterIndex + 1).clamp(0, totalChapters)
        : 0;
    final publishedChapters = math.max(publishedByFlag, publishedByIndex);
    final isLive = publishedChapters > 0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookDetailPage(bookId: book.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            _LibraryBookCover(path: book.coverPath),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título y menú
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showOptionsMenu(context),
                          icon: const Icon(Icons.more_vert),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Capítulos publicados
                    Text(
                      '$publishedChapters / $totalChapters publicados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Estado "En vivo"
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'En vivo',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Estadísticas
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _LibraryMetricChip(
                          icon: Icons.visibility_rounded,
                          label: '${book.viewCount}',
                        ),
                        _LibraryMetricChip(
                          icon: Icons.thumb_up_alt_outlined,
                          label: '${book.likeCount}',
                        ),
                        _LibraryMetricChip(
                          icon: Icons.thumb_down_alt_outlined,
                          label: '${book.dislikeCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookOptionsMenu extends StatelessWidget {
  const _BookOptionsMenu({required this.book});

  final BookEntity book;

  Future<void> _editBook(BuildContext context) async {
    Navigator.pop(context); // Cerrar modal

    final user = context.read<BookListCubit>().user;
    if (user == null) return;

    final updatedBook = await Navigator.of(context).push<BookEntity?>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => BookFormCubit(
            createBook: sl(),
            user: user,
            uploadBookCover: sl(),
            draftRepository: sl(),
            booksEventBus: sl(),
          ),
          child: EditBookScreen(book: book),
        ),
      ),
    );

    if (updatedBook != null && context.mounted) {
      context.read<BookListCubit>().upsertBook(updatedBook);
      sl<BooksEventBus>().emitUpdated(updatedBook);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar libro'),
            onTap: () => _editBook(context),
          ),
          // Botón de eliminar REMOVIDO - ahora está dentro de la pantalla de edición
        ],
      ),
    );
  }
}

class _LibraryBookCover extends StatelessWidget {
  const _LibraryBookCover({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        color: Colors.grey.shade900,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (path == null || path!.isEmpty) {
      return const _LibraryDefaultCover();
    }
    if (_looksLikeUrl(path!)) {
      return Image.network(
        path!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _LibraryDefaultCover(),
      );
    }
    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _LibraryDefaultCover(),
    );
  }
}

class _LibraryDefaultCover extends StatelessWidget {
  const _LibraryDefaultCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Colors.grey.shade800,
      child: const Icon(
        Icons.menu_book_rounded,
        size: 36,
        color: Colors.white60,
      ),
    );
  }
}

class _LibraryMetricChip extends StatelessWidget {
  const _LibraryMetricChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

class _LibraryPlaceholder extends StatelessWidget {
  const _LibraryPlaceholder(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _LibraryErrorView extends StatelessWidget {
  const _LibraryErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _looksLikeUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}
