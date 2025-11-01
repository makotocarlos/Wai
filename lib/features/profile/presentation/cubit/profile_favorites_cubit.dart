import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../books/domain/entities/book_entity.dart';
import '../../../books/domain/usecases/watch_favorite_books.dart';
import 'profile_favorites_state.dart';

class ProfileFavoritesCubit extends Cubit<ProfileFavoritesState> {
  ProfileFavoritesCubit(this._watchFavoriteBooks)
      : super(const ProfileFavoritesState());

  final WatchFavoriteBooksUseCase _watchFavoriteBooks;
  StreamSubscription<List<BookEntity>>? _subscription;

  Future<void> watchFavorites(String userId) async {
    emit(state.copyWith(status: ProfileFavoritesStatus.loading));

    await _subscription?.cancel();

    _subscription = _watchFavoriteBooks(userId: userId).listen(
      (books) {
        emit(
          state.copyWith(
            status: ProfileFavoritesStatus.loaded,
            books: books,
          ),
        );
      },
      onError: (error) {
        emit(
          state.copyWith(
            status: ProfileFavoritesStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
