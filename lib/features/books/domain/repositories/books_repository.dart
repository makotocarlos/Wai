import '../entities/book_entity.dart';
import '../entities/chapter_entity.dart';
import '../entities/comment_entity.dart';

abstract class BooksRepository {
	Stream<List<BookEntity>> watchBooks({String? userId});

	Stream<BookEntity> watchBook({
		required String bookId,
		required String userId,
	});

	Future<BookEntity> createBook({
		required String authorId,
		required String authorName,
		required String title,
		required String category,
		required String description,
		required List<ChapterEntity> chapters,
		required int publishedChapterIndex,
		String? coverPath,
	});

	Future<void> addView({
		required String bookId,
		required String userId,
	});

	Future<void> reactToBook({
		required String bookId,
		required String userId,
		required BookReactionType? reaction,
	});

	Stream<List<BookEntity>> watchFavoriteBooks({
		required String userId,
	});

	Future<void> toggleFavorite({
		required String bookId,
		required String userId,
	});

	Future<void> addComment({
		required String bookId,
		required CommentEntity comment,
	});

	/// Responder a un comentario existente (YouTube-style)
	Future<void> replyToComment({
		required String bookId,
		required String parentCommentId,
		required CommentEntity reply,
	});

	/// Retorna comentarios en estructura jerárquica (root + replies)
	Stream<List<CommentEntity>> watchComments(String bookId, {String? userId});

	// ===== Comentarios de Capítulos =====

	/// Agregar comentario a un capítulo específico
	Future<void> addChapterComment({
		required String chapterId,
		required CommentEntity comment,
	});

	/// Responder a un comentario de capítulo
	Future<void> replyToChapterComment({
		required String chapterId,
		required String parentCommentId,
		required CommentEntity reply,
	});

	/// Retorna comentarios de capítulo en estructura jerárquica
	Stream<List<CommentEntity>> watchChapterComments(String chapterId, {String? userId});

	// ===== Likes en Comentarios =====

	/// Dar/quitar like a un comentario de libro
	Future<void> toggleCommentLike({
		required String commentId,
		required String userId,
		required bool isLiked,
	});

	/// Dar/quitar like a un comentario de capítulo
	Future<void> toggleChapterCommentLike({
		required String commentId,
		required String userId,
		required bool isLiked,
	});

	/// Actualizar un libro existente
	Future<BookEntity> updateBook({
		required String bookId,
		String? title,
		String? description,
		String? category,
		String? coverPath,
		List<ChapterEntity>? chapters,
		int? publishedChapterIndex,
	});

	/// Eliminar un libro
	Future<void> deleteBook({required String bookId});
}
