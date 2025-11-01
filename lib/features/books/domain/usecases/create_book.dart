import '../entities/book_entity.dart';
import '../entities/chapter_entity.dart';
import '../repositories/books_repository.dart';

class CreateBookUseCase {
	const CreateBookUseCase(this._repository);

	final BooksRepository _repository;

	Future<BookEntity> call({
		required String authorId,
		required String authorName,
		required String title,
		required String category,
		required String description,
		required List<ChapterEntity> chapters,
		required int publishedChapterIndex,
		String? coverPath,
	}) {
		return _repository.createBook(
			authorId: authorId,
			authorName: authorName,
			title: title,
			category: category,
			description: description,
			chapters: chapters,
			publishedChapterIndex: publishedChapterIndex,
			coverPath: coverPath,
		);
	}
}
