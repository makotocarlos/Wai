import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/books_repository.dart';
import '../../domain/usecases/add_chapter_comment.dart';
import '../../domain/usecases/reply_to_chapter_comment.dart';
import '../../domain/usecases/watch_chapter_comments.dart';
import '../cubit/chapter_comments_cubit.dart';
import '../cubit/chapter_comments_state.dart';

class ChapterReaderPage extends StatefulWidget {
  const ChapterReaderPage({
    super.key,
    required this.book,
    this.initialChapterIndex = 0,
    this.targetChapterId,
    this.targetCommentId,
  });

  final BookEntity book;
  final int initialChapterIndex;
  final String? targetChapterId;
  final String? targetCommentId;

  @override
  State<ChapterReaderPage> createState() => _ChapterReaderPageState();
}

class _ChapterReaderPageState extends State<ChapterReaderPage> {
  late final PageController _pageController;
  late int _currentIndex;
  String? _pendingChapterId;
  String? _pendingCommentId;
  bool _isOpeningModal = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialChapterIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _pendingChapterId = widget.targetChapterId;
    _pendingCommentId = widget.targetCommentId;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_openPendingCommentIfNeeded()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<ChapterEntity> get _publishedChapters {
    return widget.book.chapters
        .where(
          (chapter) =>
              chapter.isPublished ||
              chapter.order <= widget.book.publishedChapterIndex + 1,
        )
        .toList();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    unawaited(_openPendingCommentIfNeeded());
  }

  void _goToPreviousChapter() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextChapter() {
    final publishedChapters = _publishedChapters;
    if (_currentIndex < publishedChapters.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _openPendingCommentIfNeeded() async {
    if (!mounted || _pendingCommentId == null) {
      return;
    }

    final chapters = _publishedChapters;
    if (chapters.isEmpty) {
      return;
    }

    final desiredChapterId =
        _pendingChapterId ?? chapters[_currentIndex].id;
    final targetIndex = chapters.indexWhere((c) => c.id == desiredChapterId);
    if (targetIndex == -1) {
      _pendingChapterId = null;
      _pendingCommentId = null;
      return;
    }

    if (_currentIndex != targetIndex) {
      _currentIndex = targetIndex;
      _pageController.jumpToPage(targetIndex);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openPendingCommentIfNeeded()),
      );
      return;
    }

    if (_isOpeningModal) {
      return;
    }

    final user = context.read<AuthBloc>().state.user;
    if (user == null) {
      _pendingChapterId = null;
      _pendingCommentId = null;
      return;
    }

    _isOpeningModal = true;
    final chapterId = chapters[targetIndex].id;
    final cubit = ChapterCommentsCubit(
      watchChapterComments: sl<WatchChapterCommentsUseCase>(),
      addChapterComment: sl<AddChapterCommentUseCase>(),
      replyToChapterComment: sl<ReplyToChapterCommentUseCase>(),
      repository: sl<BooksRepository>(),
      chapterId: chapterId,
      user: user,
    );

    await _showCommentsModal(
      context: context,
      chapterId: chapterId,
      commentsCubit: cubit,
      highlightCommentId: _pendingCommentId,
    );
    await cubit.close();

    if (!mounted) {
      return;
    }

    _isOpeningModal = false;
    _pendingChapterId = null;
    _pendingCommentId = null;
  }

  Future<void> _showCommentsModal({
    required BuildContext context,
    required String chapterId,
    required ChapterCommentsCubit commentsCubit,
    String? highlightCommentId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: commentsCubit,
        child: _CommentsModalContent(
          chapterId: chapterId,
          highlightCommentId: highlightCommentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final publishedChapters = _publishedChapters;
    final chapter = publishedChapters[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Capitulo ${chapter.order} · ${chapter.title}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: publishedChapters.length,
        itemBuilder: (context, index) {
          final chap = publishedChapters[index];
          return _ChapterContent(
            book: widget.book,
            chapter: chap,
            chapterIndex: index,
            onPrevious: _goToPreviousChapter,
            onNext: _goToNextChapter,
            hasPrevious: index > 0,
            hasNext: index < publishedChapters.length - 1,
            showCommentsModal: ({required ChapterCommentsCubit cubit, String? highlightCommentId}) {
              return _showCommentsModal(
                context: context,
                chapterId: chap.id,
                commentsCubit: cubit,
                highlightCommentId: highlightCommentId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChapterContent extends StatelessWidget {
  const _ChapterContent({
    required this.book,
    required this.chapter,
    required this.chapterIndex,
    required this.onPrevious,
    required this.onNext,
    required this.hasPrevious,
    required this.hasNext,
    required this.showCommentsModal,
  });

  final BookEntity book;
  final ChapterEntity chapter;
  final int chapterIndex;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool hasPrevious;
  final bool hasNext;
  final Future<void> Function({
    required ChapterCommentsCubit cubit,
    String? highlightCommentId,
  }) showCommentsModal;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final chapterId = chapter.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capitulo ${chapter.order}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  chapter.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white24,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              chapter.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    fontSize: 15,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Capitulo ${chapterIndex + 1} de ${book.chapters.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                ),
                if (user != null)
                  BlocProvider(
                    create: (_) => ChapterCommentsCubit(
                      watchChapterComments: sl<WatchChapterCommentsUseCase>(),
                      addChapterComment: sl<AddChapterCommentUseCase>(),
                      replyToChapterComment: sl<ReplyToChapterCommentUseCase>(),
                      repository: sl<BooksRepository>(),
                      chapterId: chapterId,
                      user: user,
                    ),
                    child:
                        BlocBuilder<ChapterCommentsCubit, ChapterCommentsState>(
                      builder: (context, state) {
                        final commentsCubit =
                            context.read<ChapterCommentsCubit>();
                        return OutlinedButton.icon(
                          onPressed: () => showCommentsModal(
                            cubit: commentsCubit,
                          ),
                          icon: const Icon(Icons.comment_outlined, size: 18),
                          label: state.isLoading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text('Comentarios'),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Comentarios (${state.comments.length})',
                                ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasPrevious)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (hasPrevious && hasNext) const SizedBox(width: 12),
              if (hasNext)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente'),
                    iconAlignment: IconAlignment.end,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }
}

// Modal de comentarios del capitulo
class _CommentsModalContent extends StatefulWidget {
  const _CommentsModalContent({required this.chapterId, this.highlightCommentId});

  final String chapterId;
  final String? highlightCommentId;

  @override
  State<_CommentsModalContent> createState() => _CommentsModalContentState();
}

class _CommentsModalContentState extends State<_CommentsModalContent> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showAllComments = false;
  final Map<String, GlobalKey> _commentKeys = {};
  bool _didScrollToHighlight = false;

  @override
  void initState() {
    super.initState();
    _showAllComments = widget.highlightCommentId != null;
  }

  @override
  void didUpdateWidget(covariant _CommentsModalContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightCommentId != oldWidget.highlightCommentId) {
      _showAllComments = widget.highlightCommentId != null;
      _didScrollToHighlight = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<ChapterCommentsCubit>().addComment(text);
    _controller.clear();
    _focusNode.unfocus();
  }

  String? _findRootCommentId(List<CommentEntity> comments, String targetId) {
    for (final comment in comments) {
      if (comment.id == targetId) {
        return comment.id;
      }
      final nested = _findRootCommentId(comment.replies, targetId);
      if (nested != null) {
        return comment.id;
      }
    }
    return null;
  }

  void _scheduleHighlightScroll(List<CommentEntity> comments) {
    if (_didScrollToHighlight || widget.highlightCommentId == null) {
      return;
    }
    final rootId = _findRootCommentId(comments, widget.highlightCommentId!);
    if (rootId == null) {
      return;
    }
    final key = _commentKeys[rootId];
    if (key?.currentContext == null) {
      return;
    }
    _didScrollToHighlight = true;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header con titulo y boton cerrar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white12,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    BlocBuilder<ChapterCommentsCubit, ChapterCommentsState>(
                      builder: (context, state) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Comentarios',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (state.isLoading)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Text(
                                '(${state.comments.length})',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Lista de comentarios
              Expanded(
                child: BlocBuilder<ChapterCommentsCubit, ChapterCommentsState>(
                  builder: (context, state) {
                    if (state.comments.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Se el primero en comentar este capitulo.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white60,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final commentsToShow = _showAllComments
                        ? state.comments
                        : state.comments.take(1).toList();

                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scheduleHighlightScroll(state.comments),
                    );

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...commentsToShow.map(
                          (comment) {
                            final key = _commentKeys.putIfAbsent(
                              comment.id,
                              () => GlobalKey(),
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: KeyedSubtree(
                                key: key,
                                child: _CommentCard(
                                  comment: comment,
                                  highlightCommentId:
                                      widget.highlightCommentId,
                                ),
                              ),
                            );
                          },
                        ),

                        // Boton "Ver mas"
                        if (state.comments.length > 1)
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showAllComments = !_showAllComments;
                                });
                              },
                              icon: Icon(
                                _showAllComments
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              label: Text(
                                _showAllComments
                                    ? 'Ver menos'
                                    : 'Ver ${state.comments.length - 1} respuestas',
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Campo de texto para comentar
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white12,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Escribe un comentario...',
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _submitComment,
                      icon: Icon(
                        Icons.send,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({required this.comment, this.highlightCommentId});

  final CommentEntity comment;
  final String? highlightCommentId;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _showReplyField = false;
  bool _showReplies = false;
  final _replyController = TextEditingController();

  bool get _isHighlighted =>
      widget.highlightCommentId != null &&
      widget.highlightCommentId == widget.comment.id;

  bool get _hasHighlightedReply => widget.highlightCommentId != null &&
      _containsReply(widget.comment.replies, widget.highlightCommentId!);

  @override
  void initState() {
    super.initState();
    if (_hasHighlightedReply) {
      _showReplies = true;
    }
  }

  @override
  void didUpdateWidget(covariant _CommentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightCommentId != oldWidget.highlightCommentId &&
        _hasHighlightedReply) {
      setState(() {
        _showReplies = true;
      });
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    context.read<ChapterCommentsCubit>().toggleCommentLike(widget.comment.id);
  }

  void _toggleReplies() {
    setState(() {
      _showReplies = !_showReplies;
    });
  }

  void _submitReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    context
        .read<ChapterCommentsCubit>()
        .replyToComment(widget.comment.id, text);
    _replyController.clear();
    setState(() {
      _showReplyField = false;
      _showReplies = true;
    });
  }

  bool _containsReply(List<CommentEntity> replies, String targetId) {
    for (final reply in replies) {
      if (reply.id == targetId) {
        return true;
      }
      if (_containsReply(reply.replies, targetId)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _formatTimeAgo(widget.comment.createdAt);
    final backgroundColor = _isHighlighted
        ? theme.colorScheme.primary.withOpacity(0.18)
        : theme.colorScheme.surface;
    final border = _isHighlighted
        ? Border.all(color: theme.colorScheme.primary, width: 1.2)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserAvatar(
                avatarUrl: widget.comment.userAvatarUrl,
                userName: widget.comment.userName,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.comment.userName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.comment.content,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: _toggleLike,
                    icon: Icon(
                      widget.comment.userHasLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: widget.comment.userHasLiked
                          ? Colors.green
                          : Colors.white60,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (widget.comment.likeCount > 0)
                    Text(
                      '${widget.comment.likeCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (widget.comment.isRootComment) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showReplyField = !_showReplyField;
                    });
                  },
                  icon: Icon(
                    _showReplyField ? Icons.close : Icons.reply,
                    size: 16,
                  ),
                  label: Text(_showReplyField ? 'Cancelar' : 'Responder'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (widget.comment.hasReplies) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _toggleReplies,
                    icon: Icon(
                      _showReplies ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                    ),
                    label: Text(
                      '${widget.comment.replyCount} respuesta${widget.comment.replyCount > 1 ? 's' : ''}',
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (_showReplyField) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Escribe una respuesta...',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitReply(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submitReply,
                  icon: Icon(
                    Icons.send,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
          if (_showReplies && widget.comment.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 32),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Colors.white24,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: widget.comment.replies
                    .map(
                      (reply) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ReplyCard(
                          reply: reply,
                          highlightCommentId: widget.highlightCommentId,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'hace ${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'hace un momento';
    }
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply, this.highlightCommentId});

  final CommentEntity reply;
  final String? highlightCommentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _formatTimeAgo(reply.createdAt);
    final isHighlighted =
        highlightCommentId != null && reply.id == highlightCommentId;
    final backgroundColor = isHighlighted
        ? theme.colorScheme.primary.withOpacity(0.18)
        : theme.colorScheme.surface.withValues(alpha: 0.5);
    final border = isHighlighted
        ? Border.all(color: theme.colorScheme.primary, width: 1)
        : null;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserAvatar(
            avatarUrl: reply.userAvatarUrl,
            userName: reply.userName,
            radius: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.userName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.content,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () {
                  context
                      .read<ChapterCommentsCubit>()
                      .toggleCommentLike(reply.id);
                },
                icon: Icon(
                  reply.userHasLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color:
                      reply.userHasLiked ? Colors.green : Colors.white60,
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (reply.likeCount > 0)
                Text(
                  '${reply.likeCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'ahora';
    }
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.userName,
    this.avatarUrl,
    this.radius = 16,
  });

  final String? avatarUrl;
  final String userName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
        child: Container(),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.6,
        ),
      ),
    );
  }
}
