import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/domain/entities/user_entity.dart';

import '../../domain/entities/book_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/books_repository.dart';
import '../../domain/usecases/add_comment.dart';
import '../../domain/usecases/add_view.dart';
import '../../domain/usecases/react_to_book.dart';
import '../../domain/usecases/reply_to_comment_usecase.dart';
import '../../domain/usecases/watch_book.dart';
import '../../domain/usecases/watch_comments.dart';
import '../../domain/usecases/toggle_favorite.dart';
import 'book_detail_state.dart';

class BookDetailCubit extends Cubit<BookDetailState> {
	BookDetailCubit({
		required WatchBookUseCase watchBook,
		required WatchCommentsUseCase watchComments,
		required ReactToBookUseCase reactToBook,
		required AddViewUseCase addView,
		required AddCommentUseCase addComment,
		required ReplyToCommentUseCase replyToComment,
		required ToggleFavoriteUseCase toggleFavorite,
		required BooksRepository repository,
		required UserEntity user,
		required String bookId,
	})  : _watchBook = watchBook,
				_watchComments = watchComments,
				_reactToBook = reactToBook,
				_addView = addView,
				_addComment = addComment,
				_replyToComment = replyToComment,
				_toggleFavorite = toggleFavorite,
				_repository = repository,
				_user = user,
				_bookId = bookId,
				super(const BookDetailState()) {
		_start();
	}

	final WatchBookUseCase _watchBook;
	final WatchCommentsUseCase _watchComments;
	final ReactToBookUseCase _reactToBook;
	final AddViewUseCase _addView;
	final AddCommentUseCase _addComment;
	final ReplyToCommentUseCase _replyToComment;
	final ToggleFavoriteUseCase _toggleFavorite;
	final BooksRepository _repository;
	final UserEntity _user;
	final String _bookId;

	StreamSubscription? _bookSubscription;
	StreamSubscription? _commentsSubscription;
	bool _viewAdded = false;

	void _start() {
		emit(state.copyWith(
			status: BookDetailStatus.loading,
			clearError: true,
			commentsLoading: true,
		));

		_bookSubscription?.cancel();
		_bookSubscription = _watchBook(bookId: _bookId, userId: _user.id).listen(
			(book) {
				emit(state.copyWith(
					status: BookDetailStatus.success,
					book: book,
					clearError: true,
				));

				// Registrar vista una sola vez
				if (!_viewAdded) {
					_viewAdded = true;
					_addView(bookId: _bookId, userId: _user.id);
				}
			},
			onError: (_) {
				emit(state.copyWith(
					status: BookDetailStatus.failure,
					errorMessage: 'No se pudo cargar el libro.',
				));
			},
		);

		_commentsSubscription?.cancel();
		_commentsSubscription = _watchComments(_bookId, userId: _user.id).listen(
			(comments) {
				emit(state.copyWith(
					comments: comments,
					commentsLoading: false,
					clearError: true,
				));
			},
			onError: (_) {
				emit(state.copyWith(
					commentsLoading: false,
					clearError: true,
				));
			},
		);
	}

	Future<void> toggleReaction(BookReactionType reaction) async {
		final current = state.book;
		if (current == null) return;
		
		final nextReaction = current.userReaction == reaction ? null : reaction;
		
		// Actualización optimista - actualiza la UI inmediatamente
		final updatedBook = _calculateOptimisticReaction(current, nextReaction);
		emit(state.copyWith(book: updatedBook));
		
		// Luego actualiza en el servidor
		try {
			await _reactToBook(
				bookId: current.id,
				userId: _user.id,
				reaction: nextReaction,
			);
		} catch (e) {
			// Si falla, el stream revertirá al estado correcto
			debugPrint('Error al dar reacción: $e');
		}
	}
	
	BookEntity _calculateOptimisticReaction(BookEntity book, BookReactionType? newReaction) {
		final oldReaction = book.userReaction;
		int newLikes = book.likeCount;
		int newDislikes = book.dislikeCount;
		
		// Quitar reacción anterior
		if (oldReaction == BookReactionType.like) {
			newLikes = (newLikes - 1).clamp(0, 999999);
		} else if (oldReaction == BookReactionType.dislike) {
			newDislikes = (newDislikes - 1).clamp(0, 999999);
		}
		
		// Agregar nueva reacción
		if (newReaction == BookReactionType.like) {
			newLikes += 1;
		} else if (newReaction == BookReactionType.dislike) {
			newDislikes += 1;
		}
		
		return book.copyWith(
			userReaction: newReaction,
			likeCount: newLikes,
			dislikeCount: newDislikes,
		);
	}

	Future<void> toggleFavorite() async {
		final current = state.book;
		if (current == null) return;

		final wasFavorited = current.isFavorited;
		final nextIsFavorited = !wasFavorited;
		final nextCount = nextIsFavorited
			? current.favoritesCount + 1
			: (current.favoritesCount - 1 < 0 ? 0 : current.favoritesCount - 1);

		final optimistic = current.copyWith(
			isFavorited: nextIsFavorited,
			favoritesCount: nextCount,
		);
		emit(state.copyWith(book: optimistic));

		try {
			await _toggleFavorite(bookId: current.id, userId: _user.id);
		} catch (error) {
			emit(state.copyWith(book: current));
		}
	}

	Future<void> addComment(String content) async {
		final book = state.book;
		if (book == null) return;
		
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
			id: const Uuid().v4(),
			userId: _user.id,
			userName: userName,
			content: trimmed,
			createdAt: DateTime.now(),
			userAvatarUrl: _user.avatarUrl,
			// Sin parent = comentario raíz
		);
		
		// Actualización optimista
		final updatedComments = [...state.comments, comment];
		emit(state.copyWith(
			comments: updatedComments,
			commentsLoading: false,
		));
		
		try {
			await _addComment(bookId: _bookId, comment: comment);
		} catch (e) {
			debugPrint('Error al agregar comentario: $e');
			// Revertir si falla
			final revertedComments = state.comments.where((c) => c.id != comment.id).toList();
			emit(state.copyWith(comments: revertedComments));
		}
	}

	Future<void> replyToComment({
		required String parentCommentId,
		required String content,
	}) async {
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
		
		final reply = CommentEntity(
			id: const Uuid().v4(),
			userId: _user.id,
			userName: userName,
			content: trimmed,
			createdAt: DateTime.now(),
			userAvatarUrl: _user.avatarUrl,
			parentCommentId: parentCommentId, // FK al padre
		);
		
		// Actualización optimista: agregar reply al padre
		final updatedComments = _addReplyOptimistically(state.comments, parentCommentId, reply);
		emit(state.copyWith(
			comments: updatedComments,
			commentsLoading: false,
		));
		
		try {
			await _replyToComment(
				bookId: _bookId,
				parentCommentId: parentCommentId,
				reply: reply,
			);
		} catch (e) {
			debugPrint('Error al responder comentario: $e');
			// Revertir si falla
			final revertedComments = _removeReplyOptimistically(state.comments, reply.id);
			emit(state.copyWith(comments: revertedComments));
		}
	}

	/// Agrega reply optimistically a su padre en el árbol
	List<CommentEntity> _addReplyOptimistically(
		List<CommentEntity> comments,
		String parentId,
		CommentEntity reply,
	) {
		return comments.map((comment) {
			if (comment.id == parentId) {
				// Encontramos el padre, agregar reply
				final updatedReplies = [...comment.replies, reply];
				return comment.copyWith(
					replies: updatedReplies,
					replyCount: comment.replyCount + 1,
				);
			} else if (comment.hasReplies) {
				// Buscar recursivamente en las replies
				final updatedReplies = _addReplyOptimistically(comment.replies, parentId, reply);
				return comment.copyWith(replies: updatedReplies);
			}
			return comment;
		}).toList();
	}

	/// Remueve reply optimistically del árbol
	List<CommentEntity> _removeReplyOptimistically(
		List<CommentEntity> comments,
		String replyId,
	) {
		return comments.map((comment) {
			final filteredReplies = comment.replies
				.where((r) => r.id != replyId)
				.map((r) => r.hasReplies ? r.copyWith(
					replies: _removeReplyOptimistically([r], replyId),
				) : r)
				.toList();
			
			if (filteredReplies.length != comment.replies.length) {
				// Se eliminó una reply
				return comment.copyWith(
					replies: filteredReplies,
					replyCount: filteredReplies.length,
				);
			}
			
			return comment.copyWith(replies: filteredReplies);
		}).toList();
	}

	// ===== Método de likes =====

	Future<void> toggleCommentLike(String commentId) async {
		// Buscar el comentario en la lista actual
		final comment = _findComment(state.comments, commentId);
		if (comment == null) return;

		final isLiked = comment.userHasLiked;
		final newLikeCount = isLiked ? comment.likeCount - 1 : comment.likeCount + 1;

		// Actualización optimista
		final updatedComments = _toggleLikeInList(
			state.comments,
			commentId,
			!isLiked,
			newLikeCount,
		);
		emit(state.copyWith(comments: updatedComments));

		// Llamar al servidor
		try {
			await _repository.toggleCommentLike(
				commentId: commentId,
				userId: _user.id,
				isLiked: isLiked,
			);
		} catch (e) {
			// Rollback en caso de error
			final rolledBack = _toggleLikeInList(
				state.comments,
				commentId,
				isLiked,
				comment.likeCount,
			);
			emit(state.copyWith(comments: rolledBack));
		}
	}

	/// Busca un comentario por ID en el árbol de comentarios
	CommentEntity? _findComment(List<CommentEntity> comments, String commentId) {
		for (final comment in comments) {
			if (comment.id == commentId) {
				return comment;
			}
			// Buscar en las respuestas
			final found = _findComment(comment.replies, commentId);
			if (found != null) {
				return found;
			}
		}
		return null;
	}

	/// Actualiza el estado de like de un comentario en la lista
	List<CommentEntity> _toggleLikeInList(
		List<CommentEntity> comments,
		String commentId,
		bool userHasLiked,
		int likeCount,
	) {
		return comments.map((comment) {
			if (comment.id == commentId) {
				return comment.copyWith(
					userHasLiked: userHasLiked,
					likeCount: likeCount,
				);
			}
			
			// Buscar en replies
			if (comment.replies.isNotEmpty) {
				final updatedReplies = _toggleLikeInList(
					comment.replies,
					commentId,
					userHasLiked,
					likeCount,
				);
				return comment.copyWith(replies: updatedReplies);
			}
			
			return comment;
		}).toList();
	}

	@override
	Future<void> close() {
		_bookSubscription?.cancel();
		_commentsSubscription?.cancel();
		return super.close();
	}
}
