import '../repositories/books_repository.dart';

class ToggleFavoriteUseCase {
  const ToggleFavoriteUseCase(this._repository);

  final BooksRepository _repository;

  Future<void> call({
    required String bookId,
    required String userId,
  }) {
    return _repository.toggleFavorite(bookId: bookId, userId: userId);
  }
}
