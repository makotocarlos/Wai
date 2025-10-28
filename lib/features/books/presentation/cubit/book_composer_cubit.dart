import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_book.dart';
import '../../domain/usecases/update_book.dart';
import 'book_composer_submission.dart';
import 'book_form_state.dart';

enum BookComposerMode { create, edit }

class BookComposerCubit extends Cubit<BookFormState> {
  BookComposerCubit.create({required CreateBook createBook})
      : _createBook = createBook,
        _updateBook = null,
        mode = BookComposerMode.create,
        super(const BookFormState());

  BookComposerCubit.edit({required UpdateBook updateBook})
      : _updateBook = updateBook,
        _createBook = null,
        mode = BookComposerMode.edit,
        super(const BookFormState());

  final CreateBook? _createBook;
  final UpdateBook? _updateBook;
  final BookComposerMode mode;

  Future<void> submit(BookComposerSubmission submission) async {
    if (state.status == BookFormStatus.submitting) {
      return;
    }

    emit(state.copyWith(status: BookFormStatus.submitting, errorMessage: null));

    try {
      if (mode == BookComposerMode.create) {
        if (_createBook == null) {
          throw Exception('Función no disponible.');
        }
        await _createBook!(
          CreateBookParams(
            title: submission.title,
            category: submission.category,
            chapters: submission.chapters,
            publishedChapterOrder: submission.publishedChapterOrder,
            description: submission.description,
            coverFile: submission.coverFile,
          ),
        );
      } else {
        if (_updateBook == null) {
          throw Exception('Función no disponible.');
        }
        final bookId = submission.bookId;
        if (bookId == null || bookId.isEmpty) {
          throw Exception('No se pudo identificar el libro a actualizar.');
        }
        await _updateBook!(
          UpdateBookParams(
            bookId: bookId,
            title: submission.title,
            category: submission.category,
            chapters: submission.chapters,
            publishedChapterOrder: submission.publishedChapterOrder,
            description: submission.description,
            coverFile: submission.coverFile,
            removeCover: submission.removeCover,
          ),
        );
      }

      emit(state.copyWith(status: BookFormStatus.success));
      emit(const BookFormState());
    } catch (error) {
      emit(state.copyWith(
        status: BookFormStatus.failure,
        errorMessage: error.toString(),
      ));
      emit(const BookFormState(status: BookFormStatus.initial));
    }
  }
}
