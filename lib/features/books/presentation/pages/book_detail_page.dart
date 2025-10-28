import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/entities/book_reaction.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../cubit/book_detail_cubit.dart';
import '../cubit/book_detail_state.dart';
import '../widgets/comment_sheet.dart';
import 'chapter_detail_page.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key, required this.book});

  final BookEntity book;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BookDetailCubit>()..start(widget.book.id),
      child: BlocListener<BookDetailCubit, BookDetailState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          final message = state.error;
          if (message != null && message.isNotEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        },
        child: BlocBuilder<BookDetailCubit, BookDetailState>(
          builder: (context, state) {
            final book = state.book ?? widget.book;
            final comments = state.comments;

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white70),
                title: Text(book.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white70),
                    onPressed: () => _shareBook(book),
                  ),
                ],
              ),
              body: SafeArea(
                child: state.isLoading && state.book == null
                    ? const Center(child: CircularProgressIndicator())
                    : _BookDetailBody(
                        book: book,
                        comments: comments,
                        userReaction: state.userReaction,
                        onLike: () =>
                            context.read<BookDetailCubit>().reactToBook(true),
                        onDislike: () =>
                            context.read<BookDetailCubit>().reactToBook(false),
                        onOpenComments: () => _openCommentsSheet(context),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _shareBook(BookEntity book) async {
    final description = book.description?.trim();
    final buffer = StringBuffer('Mira "${book.title}" en WAI.');
    if (description != null && description.isNotEmpty) {
      buffer.write(' $description');
    }
    buffer
      ..write('\n')
      ..write('https://wai.app/libro/${book.id}');
    await Share.share(buffer.toString(), subject: book.title);
  }

  void _openCommentsSheet(BuildContext context) {
    final cubit = context.read<BookDetailCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF060606),
      builder: (_) {
        return BlocProvider.value(
          value: cubit,
          child: BlocBuilder<BookDetailCubit, BookDetailState>(
            builder: (context, state) {
              return FractionallySizedBox(
                heightFactor: 0.92,
                child: CommentSheet(
                  comments: state.comments,
                  reactions: state.commentReactions,
                  onSubmit: (content, parentId) =>
                      cubit.addComment(content, parentId: parentId),
                  onReact: (commentId, isLike) => cubit.reactToComment(
                    commentId: commentId,
                    isLike: isLike,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BookDetailBody extends StatelessWidget {
  const _BookDetailBody({
    required this.book,
    required this.comments,
    required this.userReaction,
    required this.onLike,
    required this.onDislike,
    required this.onOpenComments,
  });

  final BookEntity book;
  final List<CommentEntity> comments;
  final BookReaction userReaction;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context) {
    final topLevelComments = comments.where((c) => c.parentId == null).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderSection(
            book: book,
            userReaction: userReaction,
            onLike: onLike,
            onDislike: onDislike,
          ),
          const SizedBox(height: 28),
          _BookMetaCard(book: book),
          const SizedBox(height: 28),
          _ChaptersSection(book: book),
          const SizedBox(height: 28),
          _CommentsPreview(
            topLevelComments: topLevelComments,
            totalCount: comments.length,
            onOpenComments: onOpenComments,
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.book,
    required this.userReaction,
    required this.onLike,
    required this.onDislike,
  });

  final BookEntity book;
  final BookReaction userReaction;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final hasDescription = book.description?.trim().isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: _LargeCover(
                url: book.coverUrl,
                base64: book.coverBase64,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Por ${book.authorName}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.category,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 12),
                    Text(
                      book.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionPill(
              icon: Icons.thumb_up_alt_rounded,
              label: book.likes.toString(),
              onTap: onLike,
              isSelected: userReaction == BookReaction.like,
            ),
            _ActionPill(
              icon: Icons.thumb_down_alt_rounded,
              label: book.dislikes.toString(),
              onTap: onDislike,
              isSelected: userReaction == BookReaction.dislike,
            ),
            _ActionPill(
              icon: Icons.remove_red_eye_outlined,
              label: book.views.toString(),
              onTap: null,
            ),
          ],
        ),
      ],
    );
  }
}

class _LargeCover extends StatelessWidget {
  const _LargeCover({this.url, this.base64});

  final String? url;
  final String? base64;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
      child: const Icon(Icons.menu_book, color: Colors.white24, size: 64),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final baseColor = isSelected
        ? Colors.greenAccent.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.06);
    final iconColor = isSelected ? Colors.greenAccent : Colors.white70;
    final textColor = enabled
        ? (isSelected ? Colors.greenAccent : Colors.white)
        : Colors.white54;

    return Material(
      color: baseColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookMetaCard extends StatelessWidget {
  const _BookMetaCard({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final hasDescription = book.description?.trim().isNotEmpty ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalles del libro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Publicado el ${_formatDate(book.createdAt)}',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          if (hasDescription) ...[
            const SizedBox(height: 16),
            Text(
              book.description!,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _ChaptersSection extends StatelessWidget {
  const _ChaptersSection({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    if (book.chapters.isEmpty) {
      return const Text(
        'No hay capítulos publicados todavía.',
        style: TextStyle(color: Colors.white60),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Capítulos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...book.chapters.map(
          (chapter) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChapterTile(
              book: book,
              chapter: chapter,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.book, required this.chapter});

  final BookEntity book;
  final ChapterEntity chapter;

  @override
  Widget build(BuildContext context) {
    final index = book.chapters.indexOf(chapter);
    final title = chapter.title.trim().isEmpty
        ? 'Capítulo ${index + 1}'
        : 'Capítulo ${index + 1}: ${chapter.title}';

    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChapterDetailPage(
                bookId: book.id,
                bookTitle: book.title,
                chapters: book.chapters,
                initialIndex: index,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsPreview extends StatelessWidget {
  const _CommentsPreview({
    required this.topLevelComments,
    required this.totalCount,
    required this.onOpenComments,
  });

  final List<CommentEntity> topLevelComments;
  final int totalCount;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Comentarios ($totalCount)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onOpenComments,
              icon: const Icon(Icons.forum_outlined, color: Colors.greenAccent),
              label: const Text(
                'Ver todos',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        ),
        if (topLevelComments.isEmpty)
          const Text(
            'Aún no hay comentarios aquí. Sé el primero en opinar.',
            style: TextStyle(color: Colors.white60),
          )
        else
          Column(
            children: topLevelComments.take(2).map((comment) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.content,
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
