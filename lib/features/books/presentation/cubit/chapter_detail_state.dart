import 'package:equatable/equatable.dart';

import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/book_reaction.dart';

class ChapterDetailState extends Equatable {
  const ChapterDetailState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
    this.commentReactions = const {},
  });

  final List<CommentEntity> comments;
  final bool isLoading;
  final String? error;
  final Map<String, BookReaction> commentReactions;

  ChapterDetailState copyWith({
    List<CommentEntity>? comments,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Map<String, BookReaction>? commentReactions,
  }) {
    return ChapterDetailState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      commentReactions: commentReactions ?? this.commentReactions,
    );
  }

  @override
  List<Object?> get props => [comments, isLoading, error, commentReactions];
}
