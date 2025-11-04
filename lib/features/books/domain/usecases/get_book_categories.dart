import '../repositories/books_repository.dart';

class GetBookCategoriesUseCase {
  GetBookCategoriesUseCase(this._repository);

  final BooksRepository _repository;

  Future<List<String>> call() {
    return _repository.fetchCategories();
  }
}
