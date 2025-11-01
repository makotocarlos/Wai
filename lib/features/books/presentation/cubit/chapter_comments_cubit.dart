import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/books_repository.dart';
import '../../domain/usecases/add_chapter_comment.dart';
import '../../domain/usecases/reply_to_chapter_comment.dart';
import '../../domain/usecases/watch_chapter_comments.dart';
import 'chapter_comments_state.dart';

/// Cubit para manejar comentarios de un capítulo específico.
class ChapterCommentsCubit extends Cubit<ChapterCommentsState> {
	ChapterCommentsCubit({
		required WatchChapterCommentsUseCase watchChapterComments,
		required AddChapterCommentUseCase addChapterComment,
		required ReplyToChapterCommentUseCase replyToChapterComment,
		required BooksRepository repository,
		required String chapterId,
		required UserEntity user,
	})  : _watchChapterComments = watchChapterComments,
			_addChapterComment = addChapterComment,
			_replyToChapterComment = replyToChapterComment,
			_repository = repository,
			_chapterId = chapterId,
			_user = user,
			super(const ChapterCommentsState()) {
		_start();
	}

	final WatchChapterCommentsUseCase _watchChapterComments;
	final AddChapterCommentUseCase _addChapterComment;
	final ReplyToChapterCommentUseCase _replyToChapterComment;
	final BooksRepository _repository;
	final String _chapterId;
	final UserEntity _user;
	final _uuid = const Uuid();

	StreamSubscription? _commentsSubscription;

	void _start() {
		_commentsSubscription?.cancel();

		emit(state.copyWith(isLoading: true));

		// Cargar comentarios del capítulo (no del libro)
		_commentsSubscription = _watchChapterComments(_chapterId, userId: _user.id).listen(
			(comments) {
				emit(state.copyWith(comments: comments, isLoading: false));
			},
			onError: (_) {
				emit(state.copyWith(isLoading: false));
			},
		);
	}

	Future<void> addComment(String content) async {
		final trimmed = content.trim();
		if (trimmed.isEmpty) return;

		// Obtener el nombre del usuario
		String userName = _user.username;
		if (userName.isEmpty) {
			userName = _user.fullName ?? '';
		}
		if (userName.isEmpty) {
			userName = _user.email.split('@').first;
		}

		final comment = CommentEntity(
			id: _uuid.v4(),
			userId: _user.id,
			userName: userName,
			content: trimmed,
			createdAt: DateTime.now(),
			userAvatarUrl: _user.avatarUrl,
		);

		// Actualización optimista
		final updatedComments = [...state.comments, comment];
		emit(state.copyWith(comments: updatedComments, isLoading: false));

		try {
			await _addChapterComment(chapterId: _chapterId, comment: comment);
		} catch (e) {
			debugPrint('Error al agregar comentario de capítulo: $e');
			// Revertir si falla
			final revertedComments = state.comments.where((c) => c.id != comment.id).toList();
			emit(state.copyWith(comments: revertedComments));
		}
	}

	Future<void> replyToComment(String parentCommentId, String content) async {
		final trimmed = content.trim();
		if (trimmed.isEmpty) return;

		String userName = _user.username;
		if (userName.isEmpty) {
			userName = _user.fullName ?? '';
		}
		if (userName.isEmpty) {
			userName = _user.email.split('@').first;
		}

		final reply = CommentEntity(
			id: _uuid.v4(),
			userId: _user.id,
			userName: userName,
			content: trimmed,
			createdAt: DateTime.now(),
			userAvatarUrl: _user.avatarUrl,
			parentCommentId: parentCommentId,
		);

		// Actualización optimista: agregar reply al comentario padre
		final updatedComments = state.comments.map((comment) {
			if (comment.id == parentCommentId) {
				return comment.copyWith(
					replies: [...comment.replies, reply],
					replyCount: comment.replyCount + 1,
				);
			}
			return comment;
		}).toList();

		emit(state.copyWith(comments: updatedComments, isLoading: false));

		try {
			await _replyToChapterComment(
				chapterId: _chapterId,
				parentCommentId: parentCommentId,
				reply: reply,
			);
		} catch (e) {
			debugPrint('Error al responder comentario: $e');
			// Revertir si falla
			final revertedComments = state.comments.map((comment) {
				if (comment.id == parentCommentId) {
					return comment.copyWith(
						replies: comment.replies.where((r) => r.id != reply.id).toList(),
						replyCount: comment.replyCount - 1,
					);
				}
				return comment;
			}).toList();
			emit(state.copyWith(comments: revertedComments));
		}
	}

	Future<void> toggleCommentLike(String commentId) async {
		// Encontrar el comentario y alternar su estado de like
		final updatedComments = _toggleLikeInList(state.comments, commentId);
		emit(state.copyWith(comments: updatedComments, isLoading: false));

		// Obtener el comentario actualizado para saber el nuevo estado
		final comment = _findComment(updatedComments, commentId);
		if (comment == null) return;

		try {
			await _repository.toggleChapterCommentLike(
				commentId: commentId,
				userId: _user.id,
				isLiked: !comment.userHasLiked, // Invertido porque ya lo cambiamos optimísticamente
			);
		} catch (e) {
			debugPrint('Error al dar like: $e');
			// Revertir
			final revertedComments = _toggleLikeInList(state.comments, commentId);
			emit(state.copyWith(comments: revertedComments));
		}
	}

	List<CommentEntity> _toggleLikeInList(List<CommentEntity> comments, String commentId) {
		return comments.map((comment) {
			if (comment.id == commentId) {
				return comment.copyWith(
					userHasLiked: !comment.userHasLiked,
					likeCount: comment.userHasLiked 
						? comment.likeCount - 1 
						: comment.likeCount + 1,
				);
			}
			// Buscar en replies también
			if (comment.replies.isNotEmpty) {
				return comment.copyWith(
					replies: _toggleLikeInList(comment.replies, commentId),
				);
			}
			return comment;
		}).toList();
	}

	CommentEntity? _findComment(List<CommentEntity> comments, String commentId) {
		for (final comment in comments) {
			if (comment.id == commentId) return comment;
			final found = _findComment(comment.replies, commentId);
			if (found != null) return found;
		}
		return null;
	}

	@override
	Future<void> close() {
		_commentsSubscription?.cancel();
		return super.close();
	}
}

