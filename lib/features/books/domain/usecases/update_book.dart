import '../entities/book_entity.dart';
import '../entities/chapter_entity.dart';
import '../repositories/books_repository.dart';

class UpdateBookUseCase {
	const UpdateBookUseCase(this._repository);

	final BooksRepository _repository;

	Future<BookEntity> call({
		required String bookId,
		String? title,
		String? description,
		String? category,
		String? coverPath,
		List<ChapterEntity>? chapters,
		int? publishedChapterIndex,
	}) {
		return _repository.updateBook(
			bookId: bookId,
			title: title,
			description: description,
			category: category,
			coverPath: coverPath,
			chapters: chapters,
			publishedChapterIndex: publishedChapterIndex,
		);
	}
}
