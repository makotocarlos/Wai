import 'package:equatable/equatable.dart';

import '../../domain/entities/book_entity.dart';
import '../../domain/entities/comment_entity.dart';

enum BookDetailStatus { loading, success, failure }

class BookDetailState extends Equatable {
	const BookDetailState({
		this.status = BookDetailStatus.loading,
		this.book,
		this.comments = const [],
		this.commentsLoading = true,
		this.errorMessage,
	});

	final BookDetailStatus status;
	final BookEntity? book;
	final List<CommentEntity> comments;
		final bool commentsLoading;
	final String? errorMessage;

	BookDetailState copyWith({
		BookDetailStatus? status,
		BookEntity? book,
		List<CommentEntity>? comments,
			bool? commentsLoading,
		String? errorMessage,
		bool clearError = false,
	}) {
		return BookDetailState(
			status: status ?? this.status,
			book: book ?? this.book,
			comments: comments ?? this.comments,
				commentsLoading: commentsLoading ?? this.commentsLoading,
			errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
		);
	}

	@override
		List<Object?> get props => [status, book, comments, commentsLoading, errorMessage];
}
