import 'package:equatable/equatable.dart';

import '../../../books/domain/entities/book_entity.dart';

enum ProfileFavoritesStatus { initial, loading, loaded, error }

class ProfileFavoritesState extends Equatable {
  const ProfileFavoritesState({
    this.status = ProfileFavoritesStatus.initial,
    this.books = const [],
    this.errorMessage,
  });

  final ProfileFavoritesStatus status;
  final List<BookEntity> books;
  final String? errorMessage;

  ProfileFavoritesState copyWith({
    ProfileFavoritesStatus? status,
    List<BookEntity>? books,
    String? errorMessage,
  }) {
    return ProfileFavoritesState(
      status: status ?? this.status,
      books: books ?? this.books,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, books, errorMessage];
}
