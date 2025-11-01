import 'dart:async';
import 'dart:math' show max;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../books/domain/entities/book_entity.dart';
import '../../../books/domain/usecases/watch_books.dart';
import 'profile_books_state.dart';

class ProfileBooksCubit extends Cubit<ProfileBooksState> {
  ProfileBooksCubit(this._watchBooks) : super(const ProfileBooksState());

  final WatchBooksUseCase _watchBooks;
  StreamSubscription<List<BookEntity>>? _subscription;

  Future<void> watchAuthorBooks(String userId) async {
    emit(state.copyWith(status: ProfileBooksStatus.loading));

    await _subscription?.cancel();

    _subscription = _watchBooks(userId: userId).listen(
      (books) {
        final publishedBooks = books
            .where(_isPublishedBook)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        emit(
          state.copyWith(
            status: ProfileBooksStatus.loaded,
            books: publishedBooks,
          ),
        );
      },
      onError: (error) {
        emit(
          state.copyWith(
            status: ProfileBooksStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  bool _isPublishedBook(BookEntity book) {
    if (book.chapters.isEmpty) {
      return false;
    }

    final publishedByFlag = book.chapters.where((c) => c.isPublished).length;
    final publishedByIndex = (book.publishedChapterIndex + 1)
        .clamp(0, book.chapters.length);
    final publishedCount = max(publishedByFlag, publishedByIndex);

    return publishedCount > 0;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
