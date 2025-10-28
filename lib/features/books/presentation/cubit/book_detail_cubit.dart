import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/book_reaction.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/usecases/add_comment.dart';
import '../../domain/usecases/increment_book_views.dart';
import '../../domain/usecases/react_to_book.dart';
import '../../domain/usecases/react_to_comment.dart';
import '../../domain/usecases/watch_book.dart';
import '../../domain/usecases/watch_comments.dart';
import '../../domain/usecases/get_book_reaction.dart';
import '../../domain/usecases/get_comment_reactions.dart';
import 'book_detail_state.dart';

class BookDetailCubit extends Cubit<BookDetailState> {
  BookDetailCubit({
    required WatchBook watchBook,
    required WatchComments watchComments,
    required AddComment addComment,
    required IncrementBookViews incrementBookViews,
    required ReactToBook reactToBook,
    required ReactToComment reactToComment,
    required GetBookReaction getBookReaction,
    required GetCommentReactions getCommentReactions,
  })  : _watchComments = watchComments,
        _watchBook = watchBook,
        _addComment = addComment,
        _incrementBookViews = incrementBookViews,
        _reactToBook = reactToBook,
        _reactToComment = reactToComment,
        _getBookReaction = getBookReaction,
        _getCommentReactions = getCommentReactions,
        super(const BookDetailState());

  final WatchBook _watchBook;
  final WatchComments _watchComments;
  final AddComment _addComment;
  final IncrementBookViews _incrementBookViews;
  final ReactToBook _reactToBook;
  final ReactToComment _reactToComment;
  final GetBookReaction _getBookReaction;
  final GetCommentReactions _getCommentReactions;
  StreamSubscription? _subscription;
  StreamSubscription? _bookSubscription;
  late String _bookId;

  Future<void> start(String bookId) async {
    _bookId = bookId;
    emit(state.copyWith(isLoading: true, clearError: true));
    unawaited(_incrementBookViews(bookId));
    await _bookSubscription?.cancel();
    _bookSubscription = _watchBook(bookId).listen(
      (book) {
        emit(state.copyWith(book: book));
      },
      onError: (error) {
        emit(state.copyWith(error: error.toString()));
      },
    );
    await _subscription?.cancel();
    _subscription = _watchComments(bookId).listen(
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
    unawaited(_loadUserReaction());
    unawaited(_syncCommentReactions());
  }

  Future<void> _loadUserReaction() async {
    try {
      final reaction = await _getBookReaction(_bookId);
      emit(state.copyWith(userReaction: reaction, clearError: true));
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
        GetCommentReactionsParams(bookId: _bookId),
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

  Future<void> addComment(String content, {String? parentId}) async {
    if (content.trim().isEmpty) {
      return;
    }
    try {
      await _addComment(AddCommentParams(
        bookId: _bookId,
        content: content,
        parentId: parentId,
      ));
      emit(state.copyWith(clearError: true));
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> increaseViews() async {
    try {
      await _incrementBookViews(_bookId);
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> reactToBook(bool isLike) async {
    final currentBook = state.book;
    if (currentBook == null) {
      return;
    }
    final previous = state.userReaction;
    try {
      final next = await _reactToBook(
        ReactToBookParams(bookId: _bookId, isLike: isLike),
      );
      var likes = currentBook.likes;
      var dislikes = currentBook.dislikes;

      if (previous == BookReaction.like) {
        likes = max(0, likes - 1);
      } else if (previous == BookReaction.dislike) {
        dislikes = max(0, dislikes - 1);
      }

      if (next == BookReaction.like) {
        likes += 1;
      } else if (next == BookReaction.dislike) {
        dislikes += 1;
      }

      emit(state.copyWith(
        book: currentBook.copyWith(likes: likes, dislikes: dislikes),
        userReaction: next,
        clearError: true,
      ));
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

  @override
  Future<void> close() {
    _subscription?.cancel();
    _bookSubscription?.cancel();
    return super.close();
  }
}
