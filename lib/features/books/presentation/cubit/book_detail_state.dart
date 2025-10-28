import 'package:equatable/equatable.dart';

import '../../domain/entities/book_entity.dart';
import '../../domain/entities/book_reaction.dart';
import '../../domain/entities/comment_entity.dart';

class BookDetailState extends Equatable {
  const BookDetailState({
    this.book,
    this.comments = const [],
    this.isLoading = false,
    this.error,
    this.userReaction = BookReaction.none,
    this.commentReactions = const {},
  });

  final BookEntity? book;
  final List<CommentEntity> comments;
  final bool isLoading;
  final String? error;
  final BookReaction userReaction;
  final Map<String, BookReaction> commentReactions;

  BookDetailState copyWith({
    BookEntity? book,
    List<CommentEntity>? comments,
    bool? isLoading,
    String? error,
    bool clearError = false,
    BookReaction? userReaction,
    Map<String, BookReaction>? commentReactions,
  }) {
    return BookDetailState(
      book: book ?? this.book,
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      userReaction: userReaction ?? this.userReaction,
      commentReactions: commentReactions ?? this.commentReactions,
    );
  }

  @override
  List<Object?> get props =>
      [book, comments, isLoading, error, userReaction, commentReactions];
}
