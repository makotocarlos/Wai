import 'package:equatable/equatable.dart';

enum BookFormStatus { initial, submitting, success, failure }

class BookFormState extends Equatable {
  const BookFormState({
    this.status = BookFormStatus.initial,
    this.errorMessage,
  });

  final BookFormStatus status;
  final String? errorMessage;

  BookFormState copyWith({
    BookFormStatus? status,
    String? errorMessage,
  }) {
    return BookFormState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
