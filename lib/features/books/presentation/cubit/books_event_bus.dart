import 'dart:async';

import '../../domain/entities/book_entity.dart';

enum BooksEventType { created, updated, deleted }

class BooksEvent {
  const BooksEvent._({
    required this.type,
    required this.book,
  });

  factory BooksEvent.created(BookEntity book) =>
      BooksEvent._(type: BooksEventType.created, book: book);

  factory BooksEvent.updated(BookEntity book) =>
      BooksEvent._(type: BooksEventType.updated, book: book);

  factory BooksEvent.deleted(BookEntity book) =>
      BooksEvent._(type: BooksEventType.deleted, book: book);

  final BooksEventType type;
  final BookEntity book;
}

class BooksEventBus {
  BooksEventBus() : _controller = StreamController<BooksEvent>.broadcast();

  final StreamController<BooksEvent> _controller;

  Stream<BooksEvent> get stream => _controller.stream;

  void emitCreated(BookEntity book) {
    _controller.add(BooksEvent.created(book));
  }

  void emitUpdated(BookEntity book) {
    _controller.add(BooksEvent.updated(book));
  }

  void emitDeleted(BookEntity book) {
    _controller.add(BooksEvent.deleted(book));
  }

  void dispose() {
    _controller.close();
  }
}
