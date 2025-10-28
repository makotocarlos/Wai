import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../cubit/chapter_detail_cubit.dart';
import '../cubit/chapter_detail_state.dart';
import '../widgets/comment_sheet.dart';

class ChapterDetailPage extends StatefulWidget {
  const ChapterDetailPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapters,
    this.initialIndex = 0,
  });

  final String bookId;
  final String bookTitle;
  final List<ChapterEntity> chapters;
  final int initialIndex;

  @override
  State<ChapterDetailPage> createState() => _ChapterDetailPageState();
}

class _ChapterDetailPageState extends State<ChapterDetailPage> {
  late final PageController _pageController;
  late int _currentIndex;

  ChapterEntity get _currentChapter => widget.chapters[_currentIndex];

  @override
  void initState() {
    super.initState();
    assert(widget.chapters.isNotEmpty, 'Chapters list cannot be empty');
    _currentIndex = widget.initialIndex;
    if (_currentIndex < 0) _currentIndex = 0;
    if (_currentIndex >= widget.chapters.length) {
      _currentIndex = widget.chapters.length - 1;
    }
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialOrder = _currentChapter.order;

    return BlocProvider(
      create: (_) => sl<ChapterDetailCubit>()
        ..start(bookId: widget.bookId, chapterOrder: initialOrder),
      child: BlocListener<ChapterDetailCubit, ChapterDetailState>(
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
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white70),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bookTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  _resolveChapterTitle(_currentChapter, _currentIndex),
                  style:
                      const TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          body: BlocBuilder<ChapterDetailCubit, ChapterDetailState>(
            builder: (context, state) {
              final topLevel =
                  state.comments.where((c) => c.parentId == null).toList();
              final highlight = topLevel.isNotEmpty ? topLevel.first : null;

              return Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: state.isLoading
                        ? const LinearProgressIndicator(
                            minHeight: 2,
                            color: Colors.greenAccent,
                            backgroundColor: Colors.white12,
                          )
                        : const SizedBox(height: 2),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) =>
                          _handlePageChanged(context, index),
                      itemCount: widget.chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = widget.chapters[index];
                        return _ChapterView(
                          chapter: chapter,
                          index: index,
                        );
                      },
                    ),
                  ),
                  _ChapterFooter(
                    currentIndex: _currentIndex,
                    total: widget.chapters.length,
                    commentCount: state.comments.length,
                    highlightComment: highlight,
                    onComments: () => _openCommentsSheet(context),
                    onPrevious: _currentIndex > 0
                        ? () => _jumpTo(_currentIndex - 1)
                        : null,
                    onNext: _currentIndex < widget.chapters.length - 1
                        ? () => _jumpTo(_currentIndex + 1)
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handlePageChanged(BuildContext context, int index) {
    setState(() => _currentIndex = index);
    final chapter = widget.chapters[index];
    context.read<ChapterDetailCubit>().start(
          bookId: widget.bookId,
          chapterOrder: chapter.order,
        );
  }

  void _jumpTo(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _openCommentsSheet(BuildContext context) {
    final cubit = context.read<ChapterDetailCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return BlocProvider.value(
          value: cubit,
          child: BlocBuilder<ChapterDetailCubit, ChapterDetailState>(
            builder: (context, state) {
              return FractionallySizedBox(
                heightFactor: 0.92,
                child: CommentSheet(
                  title: 'Comentarios del capítulo',
                  comments: state.comments,
                  reactions: state.commentReactions,
                  onSubmit: (content, parentId) => cubit.addComment(
                    content,
                    parentId: parentId,
                  ),
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

  static String _resolveChapterTitle(ChapterEntity chapter, int index) {
    final trimmed = chapter.title.trim();
    final base = 'Capítulo ${index + 1}';
    if (trimmed.isEmpty) {
      return base;
    }
    return '$base · $trimmed';
  }
}

class _ChapterView extends StatelessWidget {
  const _ChapterView({required this.chapter, required this.index});

  final ChapterEntity chapter;
  final int index;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Capítulo ${index + 1}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (chapter.title.trim().isNotEmpty)
                  Text(
                    chapter.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  chapter.content,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChapterFooter extends StatelessWidget {
  const _ChapterFooter({
    required this.currentIndex,
    required this.total,
    required this.commentCount,
    required this.onComments,
    this.highlightComment,
    this.onPrevious,
    this.onNext,
  });

  final int currentIndex;
  final int total;
  final int commentCount;
  final VoidCallback onComments;
  final CommentEntity? highlightComment;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Capítulo ${currentIndex + 1} de $total',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onComments,
                icon:
                    const Icon(Icons.forum_outlined, color: Colors.greenAccent),
                label: Text(
                  'Comentarios ($commentCount)',
                  style: const TextStyle(color: Colors.greenAccent),
                ),
              ),
            ],
          ),
          if (highlightComment != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    highlightComment!.userName,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    highlightComment!.content,
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPrevious,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Anterior'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(onNext == null ? 'Último' : 'Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
