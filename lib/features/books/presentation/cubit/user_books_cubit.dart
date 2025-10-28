import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/delete_book.dart';
import '../../domain/usecases/watch_user_books.dart';
import 'user_books_state.dart';

class UserBooksCubit extends Cubit<UserBooksState> {
  UserBooksCubit({
    required WatchUserBooks watchUserBooks,
    required DeleteBook deleteBook,
  })  : _watchUserBooks = watchUserBooks,
        _deleteBook = deleteBook,
        super(const UserBooksState());

  final WatchUserBooks _watchUserBooks;
  final DeleteBook _deleteBook;
  StreamSubscription? _subscription;

  Future<void> start() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _subscription?.cancel();
    _subscription = _watchUserBooks().listen(
      (books) {
        emit(state.copyWith(
          books: books,
          isLoading: false,
          errorMessage: null,
        ));
      },
      onError: (error) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        ));
      },
    );
  }

  Future<void> deleteBook(String bookId) async {
    if (state.deleteStatus == UserBooksDeleteStatus.deleting) {
      return;
    }

    emit(state.copyWith(
      deleteStatus: UserBooksDeleteStatus.deleting,
      deleteError: null,
      lastDeletedBookId: null,
    ));

    try {
      await _deleteBook(bookId);
      emit(state.copyWith(
        deleteStatus: UserBooksDeleteStatus.success,
        lastDeletedBookId: bookId,
      ));
      emit(state.copyWith(deleteStatus: UserBooksDeleteStatus.idle));
    } catch (error) {
      emit(state.copyWith(
        deleteStatus: UserBooksDeleteStatus.failure,
        deleteError: error.toString(),
      ));
      emit(state.copyWith(deleteStatus: UserBooksDeleteStatus.idle));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
