import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/watch_books.dart';
import 'book_list_state.dart';

class BookListCubit extends Cubit<BookListState> {
  BookListCubit({required WatchBooks watchBooks})
      : _watchBooks = watchBooks,
        super(const BookListState());

  final WatchBooks _watchBooks;
  StreamSubscription? _subscription;

  Future<void> start() async {
    emit(state.copyWith(isLoading: true, error: null));
    await _subscription?.cancel();
    _subscription = _watchBooks().listen(
      (books) {
        emit(state.copyWith(books: books, isLoading: false, error: null));
      },
      onError: (error) {
        emit(state.copyWith(
          isLoading: false,
          error: error.toString(),
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
