import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/books/domain/entities/book_entity.dart';
import '../../features/books/presentation/cubit/book_list_cubit.dart';
import '../../features/books/presentation/cubit/book_list_state.dart';
import '../../features/books/presentation/pages/book_detail_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<BookListCubit, BookListState>(
            builder: (context, state) {
              if (state.isLoading && state.books.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.error != null && state.books.isEmpty) {
                return Center(
                  child: Text(
                    'No se pudieron cargar los libros:\n${state.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              if (state.books.isEmpty) {
                return const Center(
                  child: Text(
                    'Aún no hay libros publicados. ¡Sé el primero en crear uno!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final grouped = _groupBooksByCategory(state.books);
              final categories = grouped.keys.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              return ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final books = grouped[category]!;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == categories.length - 1 ? 24 : 16,
                    ),
                    child: _CategorySection(
                      category: category,
                      books: books,
                      onBookTap: (book) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailPage(book: book),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Map<String, List<BookEntity>> _groupBooksByCategory(List<BookEntity> books) {
    final Map<String, List<BookEntity>> grouped = {};
    for (final book in books) {
      final key = book.category.trim().isEmpty
          ? 'Sin categoría'
          : book.category.trim();
      grouped.putIfAbsent(key, () => []).add(book);
    }
    return grouped;
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.books,
    required this.onBookTap,
  });

  final String category;
  final List<BookEntity> books;
  final ValueChanged<BookEntity> onBookTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final book = books[index];
              return _CategoryBookCard(
                book: book,
                onTap: () => onBookTap(book),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryBookCard extends StatelessWidget {
  const _CategoryBookCard({required this.book, required this.onTap});

  final BookEntity book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookCover(url: book.coverUrl, base64: book.coverBase64),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({this.url, this.base64});

  final String? url;
  final String? base64;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (url != null && url!.isNotEmpty) {
      return Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (base64 != null && base64!.isNotEmpty) {
      try {
        final bytes = base64Decode(base64!);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      } catch (_) {
        return _placeholder();
      }
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[850],
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book, color: Colors.white30, size: 40),
    );
  }
}
