import 'package:flutter/material.dart';

import '../../domain/entities/book_reaction.dart';
import '../../domain/entities/comment_entity.dart';

typedef CommentSubmitCallback = Future<void> Function(
    String content, String? parentId);
typedef CommentReactCallback = Future<void> Function(
    String commentId, bool isLike);

class CommentSheet extends StatefulWidget {
  const CommentSheet({
    super.key,
    required this.comments,
    required this.onSubmit,
    required this.onReact,
    this.title = 'Comentarios',
    this.reactions = const {},
  });

  final List<CommentEntity> comments;
  final CommentSubmitCallback onSubmit;
  final CommentReactCallback onReact;
  final String title;
  final Map<String, BookReaction> reactions;

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  CommentEntity? _replyTarget;
  bool _isSubmitting = false;
  final Set<String> _pendingReactions = <String>{};
  final Set<String> _expandedThreads = <String>{};

  @override
  void didUpdateWidget(covariant CommentSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validIds = widget.comments.map((comment) => comment.id).toSet();
    _expandedThreads.removeWhere((id) => !validIds.contains(id));
    if (_replyTarget != null && !validIds.contains(_replyTarget!.id)) {
      _replyTarget = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderedComments = List<CommentEntity>.from(widget.comments)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final byId = {
      for (final comment in orderedComments) comment.id: comment,
    };
    final topLevel = <CommentEntity>[];
    final repliesMap = <String, List<CommentEntity>>{};

    for (final comment in orderedComments) {
      final parentId = comment.parentId;
      if (parentId == null || !byId.containsKey(parentId)) {
        if (!topLevel.any((element) => element.id == comment.id)) {
          topLevel.add(comment);
        }
        continue;
      }

      CommentEntity? ancestor = byId[parentId];
      while (ancestor != null &&
          ancestor.parentId != null &&
          byId.containsKey(ancestor.parentId!)) {
        ancestor = byId[ancestor.parentId!];
      }

      final root = ancestor ?? byId[parentId] ?? comment;

      if (!topLevel.any((element) => element.id == root.id)) {
        topLevel.add(root);
      }

      if (comment.id == root.id) {
        continue;
      }

      final bucket = repliesMap.putIfAbsent(root.id, () => <CommentEntity>[]);
      if (!bucket.any((element) => element.id == comment.id)) {
        bucket.add(comment);
      }
    }

    topLevel.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final entry in repliesMap.entries) {
      entry.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final toggleButtonStyle = TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: Colors.greenAccent,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );

    final threadWidgets = <Widget>[];
    for (var i = 0; i < topLevel.length; i++) {
      final root = topLevel[i];
      final replies = List<CommentEntity>.from(
        repliesMap[root.id] ?? const <CommentEntity>[],
      );
      final isExpanded = _expandedThreads.contains(root.id);
      final rootReaction = widget.reactions[root.id] ?? BookReaction.none;
      final rootPending = _pendingReactions.contains(root.id);

      threadWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentEntry(
              comment: root,
              parent: null,
              reaction: rootReaction,
              isPending: rootPending,
              onReact: _handleReact,
              onReply: _setReplyTarget,
              isReply: false,
            ),
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 8),
                child: isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final reply in replies)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CommentEntry(
                                comment: reply,
                                parent: reply.parentId != null
                                    ? byId[reply.parentId!]
                                    : null,
                                reaction: widget.reactions[reply.id] ??
                                    BookReaction.none,
                                isPending: _pendingReactions.contains(reply.id),
                                onReact: _handleReact,
                                onReply: null,
                                isReply: true,
                              ),
                            ),
                          TextButton(
                            style: toggleButtonStyle,
                            onPressed: () {
                              setState(() {
                                _expandedThreads.remove(root.id);
                              });
                            },
                            child: const Text('Ocultar respuestas'),
                          ),
                        ],
                      )
                    : TextButton(
                        style: toggleButtonStyle,
                        onPressed: () {
                          setState(() {
                            _expandedThreads.add(root.id);
                          });
                        },
                        child: Text(
                          replies.length == 1
                              ? 'Ver 1 respuesta'
                              : 'Ver ${replies.length} respuestas',
                        ),
                      ),
              ),
          ],
        ),
      );

      if (i != topLevel.length - 1) {
        threadWidgets.add(const SizedBox(height: 16));
      }
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.title} (${widget.comments.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: threadWidgets.isEmpty
                ? const Center(
                    child: Text(
                      'Sé el primero en dejar un comentario.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: threadWidgets,
                  ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Padding(
            padding:
                MediaQuery.of(context).viewInsets + const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyTarget != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Respondiendo a ${_replyTarget!.userName}',
                            style: const TextStyle(color: Colors.greenAccent),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _replyTarget = null),
                          child: const Icon(Icons.close,
                              size: 18, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _replyTarget == null
                              ? 'Escribe un comentario...'
                              : 'Responde a ${_replyTarget!.userName}...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send,
                                color: Colors.greenAccent),
                            onPressed: _submit,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setReplyTarget(CommentEntity target) {
    setState(() => _replyTarget = target);
  }

  Future<void> _handleReact(String commentId, bool isLike) async {
    if (_pendingReactions.contains(commentId)) {
      return;
    }
    setState(() => _pendingReactions.add(commentId));
    try {
      await widget.onReact(commentId, isLike);
    } finally {
      if (mounted) {
        setState(() => _pendingReactions.remove(commentId));
      }
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(text, _replyTarget?.id);
      _controller.clear();
      setState(() => _replyTarget = null);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _CommentEntry extends StatelessWidget {
  const _CommentEntry({
    required this.comment,
    required this.parent,
    required this.reaction,
    required this.isPending,
    required this.onReact,
    this.onReply,
    required this.isReply,
  });

  final CommentEntity comment;
  final CommentEntity? parent;
  final BookReaction reaction;
  final bool isPending;
  final CommentReactCallback onReact;
  final ValueChanged<CommentEntity>? onReply;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply ? 32.0 : 40.0;
    final cardColor = isReply
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.07);

    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarBubble(
            name: comment.userName,
            photoUrl: comment.userPhotoUrl,
            size: avatarSize,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          comment.userName,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(comment.createdAt),
                        style:
                            const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  if (parent != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'En respuesta a ${parent!.userName}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    comment.content,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MiniAction(
                        icon: Icons.thumb_up_alt_outlined,
                        label: comment.likes.toString(),
                        onTap:
                            isPending ? null : () => onReact(comment.id, true),
                        isSelected: reaction == BookReaction.like,
                        selectedColor: Colors.greenAccent,
                      ),
                      _MiniAction(
                        icon: Icons.thumb_down_alt_outlined,
                        label: comment.dislikes.toString(),
                        onTap:
                            isPending ? null : () => onReact(comment.id, false),
                        isSelected: reaction == BookReaction.dislike,
                        selectedColor: Colors.redAccent,
                      ),
                      if (onReply != null)
                        GestureDetector(
                          onTap: () => onReply!(comment),
                          child: const Text(
                            'Responder',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.green.withValues(alpha: 0.35),
      backgroundImage:
          photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? null
          : Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.selectedColor = Colors.greenAccent,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = isSelected
        ? selectedColor
        : (enabled ? Colors.white54 : Colors.white24);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
