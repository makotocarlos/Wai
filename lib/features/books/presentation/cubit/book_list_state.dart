import 'package:equatable/equatable.dart';

import '../../domain/entities/book_entity.dart';

enum BookListStatus { initial, loading, success, failure }

class BookListState extends Equatable {
	const BookListState({
		this.status = BookListStatus.initial,
		this.books = const [],
		this.errorMessage,
	});

	final BookListStatus status;
	final List<BookEntity> books;
	final String? errorMessage;

	BookListState copyWith({
		BookListStatus? status,
		List<BookEntity>? books,
		String? errorMessage,
		bool clearError = false,
	}) {
		return BookListState(
			status: status ?? this.status,
			books: books ?? this.books,
			errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
		);
	}

	@override
	List<Object?> get props => [status, books, errorMessage];
}
