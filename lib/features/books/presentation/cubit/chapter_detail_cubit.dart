import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/book_reaction.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/usecases/add_chapter_comment.dart';
import '../../domain/usecases/get_comment_reactions.dart';
import '../../domain/usecases/react_to_comment.dart';
import '../../domain/usecases/watch_chapter_comments.dart';
import 'chapter_detail_state.dart';

class ChapterDetailCubit extends Cubit<ChapterDetailState> {
  ChapterDetailCubit({
    required WatchChapterComments watchChapterComments,
    required AddChapterComment addChapterComment,
    required ReactToComment reactToComment,
    required GetCommentReactions getCommentReactions,
  })  : _watchChapterComments = watchChapterComments,
        _addChapterComment = addChapterComment,
        _reactToComment = reactToComment,
        _getCommentReactions = getCommentReactions,
        super(const ChapterDetailState());

  final WatchChapterComments _watchChapterComments;
  final AddChapterComment _addChapterComment;
  final ReactToComment _reactToComment;
  final GetCommentReactions _getCommentReactions;
  StreamSubscription? _subscription;
  late String _bookId;
  late int _chapterOrder;

  Future<void> start({
    required String bookId,
    required int chapterOrder,
  }) async {
    _bookId = bookId;
    _chapterOrder = chapterOrder;
    emit(state.copyWith(isLoading: true, clearError: true));
    await _subscription?.cancel();
    _subscription = _watchChapterComments(
      WatchChapterCommentsParams(
        bookId: bookId,
        chapterOrder: chapterOrder,
      ),
    ).listen(
      (comments) {
        emit(state.copyWith(
          comments: comments,
          isLoading: false,
          clearError: true,
        ));
        unawaited(_syncCommentReactions());
      },
      onError: (error) {
        emit(state.copyWith(
          isLoading: false,
          error: error.toString(),
        ));
      },
    );
    unawaited(_syncCommentReactions());
  }

  Future<void> addComment(String content, {String? parentId}) async {
    if (content.trim().isEmpty) return;
    try {
      await _addChapterComment(
        AddChapterCommentParams(
          bookId: _bookId,
          chapterOrder: _chapterOrder,
          content: content,
          parentId: parentId,
        ),
      );
      emit(state.copyWith(clearError: true));
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> reactToComment({
    required String commentId,
    required bool isLike,
  }) async {
    final index = state.comments.indexWhere((comment) => comment.id == commentId);
    if (index == -1) {
      return;
    }

    final comment = state.comments[index];
    final currentReaction =
        state.commentReactions[commentId] ?? BookReaction.none;
    final desired = isLike ? BookReaction.like : BookReaction.dislike;
    final nextReaction =
        currentReaction == desired ? BookReaction.none : desired;

    var likes = comment.likes;
    var dislikes = comment.dislikes;

    if (currentReaction == BookReaction.like) {
      likes = max(0, likes - 1);
    } else if (currentReaction == BookReaction.dislike) {
      dislikes = max(0, dislikes - 1);
    }

    if (nextReaction == BookReaction.like) {
      likes += 1;
    } else if (nextReaction == BookReaction.dislike) {
      dislikes += 1;
    }

    final updatedComment = CommentEntity(
      id: comment.id,
      userId: comment.userId,
      userName: comment.userName,
      userPhotoUrl: comment.userPhotoUrl,
      content: comment.content,
      createdAt: comment.createdAt,
      likes: likes,
      dislikes: dislikes,
      parentId: comment.parentId,
    );

    final updatedComments = [...state.comments]..[index] = updatedComment;
    final updatedReactions = Map<String, BookReaction>.from(state.commentReactions);
    if (nextReaction == BookReaction.none) {
      updatedReactions.remove(commentId);
    } else {
      updatedReactions[commentId] = nextReaction;
    }

    emit(state.copyWith(
      comments: updatedComments,
      commentReactions: updatedReactions,
      clearError: true,
    ));

    try {
      final reaction = await _reactToComment(
        ReactToCommentParams(
          bookId: _bookId,
          commentId: commentId,
          isLike: isLike,
          chapterOrder: _chapterOrder,
        ),
      );
      final synced = Map<String, BookReaction>.from(state.commentReactions);
      if (reaction == BookReaction.none) {
        synced.remove(commentId);
      } else {
        synced[commentId] = reaction;
      }
      emit(state.copyWith(commentReactions: synced, clearError: true));
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _syncCommentReactions() async {
    final ids = state.comments.map((comment) => comment.id).toSet();
    if (ids.isEmpty) {
      emit(state.copyWith(commentReactions: const {}, clearError: true));
      return;
    }
    try {
      final reactions = await _getCommentReactions(
        GetCommentReactionsParams(
          bookId: _bookId,
          chapterOrder: _chapterOrder,
        ),
      );
      final filtered = {
        for (final entry in reactions.entries)
          if (ids.contains(entry.key)) entry.key: entry.value,
      };
      emit(state.copyWith(commentReactions: filtered, clearError: true));
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
