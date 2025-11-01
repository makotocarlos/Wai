import 'package:equatable/equatable.dart';

import '../../domain/entities/comment_entity.dart';

class ChapterCommentsState extends Equatable {
	const ChapterCommentsState({
		this.comments = const [],
		this.isLoading = true,
	});

	final List<CommentEntity> comments;
	final bool isLoading;

	ChapterCommentsState copyWith({
		List<CommentEntity>? comments,
		bool? isLoading,
	}) {
		return ChapterCommentsState(
			comments: comments ?? this.comments,
			isLoading: isLoading ?? this.isLoading,
		);
	}

	@override
	List<Object?> get props => [comments, isLoading];
}
