import 'dart:typed_data';

import '../repositories/books_repository.dart';

class UploadBookCoverUseCase {
  const UploadBookCoverUseCase(this._repository);

  final BooksRepository _repository;

  Future<String> call({
    required String authorId,
    required Uint8List bytes,
    required String fileExtension,
  }) {
    return _repository.uploadBookCover(
      authorId: authorId,
      bytes: bytes,
      fileExtension: fileExtension,
    );
  }
}
