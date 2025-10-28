import 'package:equatable/equatable.dart';

import '../../domain/entities/book_entity.dart';

class BookListState extends Equatable {
  const BookListState({
    this.books = const [],
    this.isLoading = false,
    this.error,
  });

  final List<BookEntity> books;
  final bool isLoading;
  final String? error;

  BookListState copyWith({
    List<BookEntity>? books,
    bool? isLoading,
    String? error,
  }) {
    return BookListState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [books, isLoading, error];
}
