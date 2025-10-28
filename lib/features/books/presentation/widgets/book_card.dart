import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/entities/book_entity.dart';

class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, required this.onTap});

  final BookEntity book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverImage(
              url: book.coverUrl,
              base64: book.coverBase64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.category,
                    style: const TextStyle(color: Colors.greenAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Por ${book.authorName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    book.description?.isNotEmpty == true
                        ? book.description!
                        : _firstChapterPreview(book),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _firstChapterPreview(BookEntity book) {
    if (book.chapters.isEmpty) {
      return 'Sin capítulos aún.';
    }
    return book.chapters.first.content;
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.url, this.base64});

  final String? url;
  final String? base64;

  @override
  Widget build(BuildContext context) {
    const size = 80.0;
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(size),
        ),
      );
    }

    if (base64 != null && base64!.isNotEmpty) {
      try {
        final bytes = base64Decode(base64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(size),
          ),
        );
      } catch (_) {
        return _placeholder(size);
      }
    }

    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.menu_book, color: Colors.white54),
    );
  }
}
