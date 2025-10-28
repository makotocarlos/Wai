import 'package:equatable/equatable.dart';

import '../../domain/entities/book_entity.dart';

enum UserBooksDeleteStatus { idle, deleting, success, failure }

class UserBooksState extends Equatable {
  const UserBooksState({
    this.books = const [],
    this.isLoading = false,
    this.errorMessage,
    this.deleteStatus = UserBooksDeleteStatus.idle,
    this.deleteError,
    this.lastDeletedBookId,
  });

  final List<BookEntity> books;
  final bool isLoading;
  final String? errorMessage;
  final UserBooksDeleteStatus deleteStatus;
  final String? deleteError;
  final String? lastDeletedBookId;

  UserBooksState copyWith({
    List<BookEntity>? books,
    bool? isLoading,
    String? errorMessage,
    UserBooksDeleteStatus? deleteStatus,
    String? deleteError,
    String? lastDeletedBookId,
  }) {
    return UserBooksState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      deleteStatus: deleteStatus ?? this.deleteStatus,
      deleteError: deleteError,
      lastDeletedBookId: lastDeletedBookId,
    );
  }

  @override
  List<Object?> get props => [
        books,
        isLoading,
        errorMessage,
        deleteStatus,
        deleteError,
        lastDeletedBookId,
      ];
}
