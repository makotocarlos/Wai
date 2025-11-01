import 'package:equatable/equatable.dart';

import '../../../books/domain/entities/book_entity.dart';

enum ProfileBooksStatus { initial, loading, loaded, error }

class ProfileBooksState extends Equatable {
  const ProfileBooksState({
    this.status = ProfileBooksStatus.initial,
    this.books = const [],
    this.errorMessage,
  });

  final ProfileBooksStatus status;
  final List<BookEntity> books;
  final String? errorMessage;

  ProfileBooksState copyWith({
    ProfileBooksStatus? status,
    List<BookEntity>? books,
    String? errorMessage,
  }) {
    return ProfileBooksState(
      status: status ?? this.status,
      books: books ?? this.books,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, books, errorMessage];
}
