import 'package:equatable/equatable.dart';

class CommentEntity extends Equatable {
	const CommentEntity({
		required this.id,
		required this.userId,
		required this.userName,
		required this.content,
		required this.createdAt,
		this.userAvatarUrl,
		this.parentCommentId,
		this.replyCount = 0,
		this.replies = const [],
		this.likeCount = 0,
		this.userHasLiked = false,
	});

	final String id;
	final String userId;
	final String userName;
	final String content;
	final DateTime createdAt;
	final String? userAvatarUrl;
	final String? parentCommentId; // NULL = comentario raíz, NOT NULL = respuesta
	final int replyCount; // Número de respuestas directas
	final List<CommentEntity> replies; // Lista de respuestas (para UI)
	final int likeCount; // Número de likes
	final bool userHasLiked; // Si el usuario actual dio like

	/// Retorna true si este es un comentario raíz (top-level)
	bool get isRootComment => parentCommentId == null;

	/// Retorna true si este comentario tiene respuestas
	bool get hasReplies => replyCount > 0;

	CommentEntity copyWith({
		String? id,
		String? userId,
		String? userName,
		String? content,
		DateTime? createdAt,
		String? userAvatarUrl,
		String? parentCommentId,
		int? replyCount,
		List<CommentEntity>? replies,
		int? likeCount,
		bool? userHasLiked,
	}) {
		return CommentEntity(
			id: id ?? this.id,
			userId: userId ?? this.userId,
			userName: userName ?? this.userName,
			content: content ?? this.content,
			createdAt: createdAt ?? this.createdAt,
			userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
			parentCommentId: parentCommentId ?? this.parentCommentId,
			replyCount: replyCount ?? this.replyCount,
			replies: replies ?? this.replies,
			likeCount: likeCount ?? this.likeCount,
			userHasLiked: userHasLiked ?? this.userHasLiked,
		);
	}

	@override
	List<Object?> get props => [
		id,
		userId,
		userName,
		content,
		createdAt,
		userAvatarUrl,
		parentCommentId,
		replyCount,
		replies,
		likeCount,
		userHasLiked,
	];
}
