import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../features/books/domain/entities/book_entity.dart';
import '../../features/books/presentation/cubit/user_books_cubit.dart';
import '../../features/books/presentation/cubit/user_books_state.dart';
import '../../features/books/presentation/pages/book_detail_page.dart';
import '../../features/books/presentation/pages/create_book_page.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<UserBooksCubit>()..start(),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatelessWidget {
  const _LibraryView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserBooksCubit, UserBooksState>(
      listener: (context, state) {
        if (state.deleteStatus == UserBooksDeleteStatus.success &&
            state.lastDeletedBookId != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Libro eliminado.')),
            );
        } else if (state.deleteStatus == UserBooksDeleteStatus.failure &&
            state.deleteError != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(state.deleteError!)),
            );
        }
      },
      builder: (context, state) {
        final isDeleting =
            state.deleteStatus == UserBooksDeleteStatus.deleting;

        return Scaffold(
          backgroundColor: Colors.black,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const CreateBookPage()),
              );
              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Libro creado correctamente.')),
                  );
              }
            },
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.auto_stories),
            label: const Text('Nuevo libro'),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.menu_book, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text(
                        'Tu biblioteca',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildContent(context, state, isDeleting),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserBooksState state,
    bool isDeleting,
  ) {
    if (state.isLoading && state.books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return _ErrorPlaceholder(
        message: state.errorMessage!,
        onRetry: () => context.read<UserBooksCubit>().start(),
      );
    }

    if (state.books.isEmpty) {
      return const _EmptyLibraryPlaceholder();
    }

    return Stack(
      children: [
        ListView.separated(
          itemCount: state.books.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final book = state.books[index];
            return _LibraryBookCard(
              book: book,
              isDeleting: isDeleting,
            );
          },
        ),
        if (isDeleting)
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            ),
          ),
      ],
    );
  }
}

class _LibraryBookCard extends StatelessWidget {
  const _LibraryBookCard({required this.book, required this.isDeleting});

  final BookEntity book;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final publishedChapters = book.chapters
        .where((chapter) => chapter.isPublished)
        .length;
    final totalChapters = book.chapters.length;
    final isFullyPublished = publishedChapters == totalChapters;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LibraryCover(book: book),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        book.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<_LibraryAction>(
                      enabled: !isDeleting,
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      color: Colors.grey[900],
                      onSelected: (action) => _handleAction(context, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: _LibraryAction.edit,
                          child: Text('Editar'),
                        ),
                        const PopupMenuItem(
                          value: _LibraryAction.view,
                          child: Text('Ver publicación'),
                        ),
                        const PopupMenuItem(
                          value: _LibraryAction.delete,
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  book.category,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  book.description?.isNotEmpty == true
                      ? book.description!
                      : 'Sin descripción',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(
                        '$publishedChapters / $totalChapters publicados',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      side: BorderSide.none,
                    ),
                    Chip(
                      label: Text(
                        isFullyPublished ? 'En vivo' : 'En progreso',
                        style: TextStyle(
                          color: isFullyPublished
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                        ),
                      ),
                      backgroundColor: Colors.white12,
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatIcon(icon: Icons.remove_red_eye, value: book.views),
                    const SizedBox(width: 12),
                    _StatIcon(icon: Icons.thumb_up, value: book.likes),
                    const SizedBox(width: 12),
                    _StatIcon(icon: Icons.thumb_down, value: book.dislikes),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, _LibraryAction action) async {
    switch (action) {
      case _LibraryAction.edit:
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => EditBookPage(book: book)),
        );
        if (result == true && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Cambios guardados.')),
            );
        }
        break;
      case _LibraryAction.view:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
        );
        break;
      case _LibraryAction.delete:
        _confirmDelete(context);
        break;
    }
  }

  void _confirmDelete(BuildContext context) async {
    final cubit = context.read<UserBooksCubit>();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Eliminar libro'),
        content: Text(
          '¿Deseas eliminar "${book.title}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      await cubit.deleteBook(book.id);
    }
  }
}

class _LibraryCover extends StatelessWidget {
  const _LibraryCover({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    const size = 90.0;

    Widget child;
    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      child = Image.network(
        book.coverUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (book.coverBase64 != null && book.coverBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(book.coverBase64!);
        child = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (_) {
        child = _placeholder();
      }
    } else {
      child = _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.photo, color: Colors.white54),
    );
  }
}

class _StatIcon extends StatelessWidget {
  const _StatIcon({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white60),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _EmptyLibraryPlaceholder extends StatelessWidget {
  const _EmptyLibraryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.auto_stories, size: 56, color: Colors.white38),
          SizedBox(height: 16),
          Text(
            'Aún no tienes publicaciones',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Publica tu primera historia y adminístrala desde aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 56, color: Colors.orangeAccent),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

enum _LibraryAction { edit, view, delete }
