import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:path/path.dart' as p;

import '../../../auth/domain/entities/user_entity.dart';
import '../../data/repositories_impl/draft_repository.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/usecases/create_book.dart';
import '../../domain/usecases/upload_book_cover.dart';
import 'book_form_state.dart';
import 'books_event_bus.dart';
import 'chapter_ai_state.dart';

class BookFormCubit extends Cubit<BookFormState> {
  BookFormCubit({
    required CreateBookUseCase createBook,
    required UserEntity user,
    required UploadBookCoverUseCase uploadBookCover,
    DraftRepository? draftRepository,
    String? draftId,
    BooksEventBus? booksEventBus,
  })  : _createBook = createBook,
        _user = user,
        _uploadBookCover = uploadBookCover,
        _draftRepository = draftRepository,
        _draftId = draftId,
        _booksEventBus = booksEventBus,
        super(const BookFormState());

  final CreateBookUseCase _createBook;
  final UserEntity _user;
  final UploadBookCoverUseCase _uploadBookCover;
  final DraftRepository? _draftRepository;
  String? _draftId;
  final BooksEventBus? _booksEventBus;

  /// Auto-guardar borrador después de cada cambio
  Future<void> _autoSaveDraft() async {
    if (_draftRepository == null) return;
    if (state.title.isEmpty) return; // No guardar si no hay título

    try {
      final savedId = await _draftRepository!.saveDraft(
        id: _draftId,
        authorId: _user.id,
        authorName: _user.username.isEmpty ? _user.email : _user.username,
        title: state.title,
        category: state.category,
        description: state.description,
        coverPath: state.coverPath,
        publishedChapterIndex: state.publishIndex,
        chapters: state.chapters.map((draft) {
          return ChapterEntity(
            id: draft.id,
            order: draft.order,
            title: draft.title,
            content: draft.content,
            isPublished: draft.isPublished,
          );
        }).toList(),
      );
      _draftId = savedId;
    } catch (e) {
      // Fallar silenciosamente, no interrumpir la experiencia del usuario
      print('Error auto-guardando borrador: $e');
    }
  }

  void titleChanged(String value) {
    emit(state.copyWith(title: value, clearLastCreatedBook: true));
    _autoSaveDraft();
  }

  void categoryChanged(String value) {
    emit(state.copyWith(category: value, clearLastCreatedBook: true));
    _autoSaveDraft();
  }

  void descriptionChanged(String value) {
    emit(state.copyWith(description: value, clearLastCreatedBook: true));
    _autoSaveDraft();
  }

  void coverPicked(File? file) {
    emit(state.copyWith(coverPath: file?.path, clearLastCreatedBook: true));
    _autoSaveDraft();
  }

  void setCoverPath(String path) {
    emit(state.copyWith(coverPath: path, clearLastCreatedBook: true));
    _autoSaveDraft();
  }

  void addChapterFromExisting(ChapterEntity chapter) {
    final chapters = [...state.chapters];
    chapters.add(ChapterDraftState(
      id: chapter.id,
      order: chapter.order,
      title: chapter.title,
      content: chapter.content,
    ));
    emit(state.copyWith(chapters: chapters, clearLastCreatedBook: true));
  }

  /// Reemplazar todos los capítulos (para cargar libro existente)
  void loadExistingChapters(
    List<ChapterEntity> chapters, {
    int? publishedChapterIndex,
  }) {
    if (chapters.isEmpty) {
      // Si no hay capítulos, crear uno por defecto
      emit(state.copyWith(
        chapters: [const ChapterDraftState(id: 'chapter_1', order: 1)],
        clearLastCreatedBook: true,
      ));
      return;
    }

    final fallbackIndex = publishedChapterIndex ?? state.publishIndex;
    final draftChapters = chapters.map((ch) {
      final isPublished = ch.isPublished ||
          (fallbackIndex >= 0 && ch.order <= fallbackIndex + 1);
      return ChapterDraftState(
        id: ch.id,
        order: ch.order,
        title: ch.title,
        content: ch.content,
        isPublished: isPublished,
      );
    }).toList();

    emit(state.copyWith(
      chapters: draftChapters,
      clearLastCreatedBook: true,
    ));
  }

  void updateChapter(int index, {String? title, String? content}) {
    final chapters = [...state.chapters];
    if (index < 0 || index >= chapters.length) return;
    chapters[index] = chapters[index].copyWith(
      title: title ?? chapters[index].title,
      content: content ?? chapters[index].content,
    );
    emit(state.copyWith(chapters: chapters, clearLastCreatedBook: true));
    _autoSaveDraft();
  }

  void updateChapterChat(
    int index, {
    List<ChapterAiMessage>? messages,
    List<String>? ideas,
    List<String>? nextSteps,
  }) {
    final chapters = [...state.chapters];
    if (index < 0 || index >= chapters.length) return;

    chapters[index] = chapters[index].copyWith(
      chatHistory: messages != null
          ? List<ChapterAiMessage>.from(messages)
          : chapters[index].chatHistory,
      chatIdeas:
          ideas != null ? List<String>.from(ideas) : chapters[index].chatIdeas,
      chatNextSteps: nextSteps != null
          ? List<String>.from(nextSteps)
          : chapters[index].chatNextSteps,
    );

    emit(state.copyWith(chapters: chapters, clearLastCreatedBook: true));
    _autoSaveDraft();
  }

  void addChapter() {
    final chapters = [...state.chapters];
    final id = 'chapter_${DateTime.now().microsecondsSinceEpoch}';
    // Comienza desde 1 en vez de 0
    chapters.add(ChapterDraftState(id: id, order: chapters.length + 1));
    emit(state.copyWith(
      chapters: chapters,
      publishIndex: chapters.length - 1,
      clearLastCreatedBook: true,
    ));
    _autoSaveDraft();
  }

  void removeChapter(int index) {
    // No permitir borrar el primer capítulo (Capítulo 1)
    if (index == 0) return;

    final chapters = [...state.chapters];
    if (index < 0 || index >= chapters.length) return;

    chapters.removeAt(index);

    // Reordenar los capítulos restantes
    for (int i = 0; i < chapters.length; i++) {
      chapters[i] = chapters[i].copyWith(order: i + 1);
    }

    // Ajustar publishIndex si es necesario
    int newPublishIndex = state.publishIndex;
    if (newPublishIndex >= chapters.length) {
      newPublishIndex = chapters.length - 1;
    }

    emit(state.copyWith(
      chapters: chapters,
      publishIndex: newPublishIndex,
      clearLastCreatedBook: true,
    ));
    _autoSaveDraft();
  }

  void setPublishIndex(int index) {
    emit(state.copyWith(publishIndex: index, clearLastCreatedBook: true));
    _autoSaveDraft();
  }

  /// Marca un capítulo como publicado (no permite revertir el estado).
  void publishChapter(int index) {
    final chapters = [...state.chapters];
    if (index < 0 || index >= chapters.length) return;

    final current = chapters[index];
    if (current.isPublished) {
      return; // Ya publicado, no hacer nada
    }

    chapters[index] = current.copyWith(isPublished: true);
    final newPublishIndex =
        index > state.publishIndex ? index : state.publishIndex;

    emit(state.copyWith(chapters: chapters, publishIndex: newPublishIndex));
    _autoSaveDraft();
  }

  Future<void> submit() async {
    if (state.title.trim().isEmpty) {
      emit(state.copyWith(
        status: BookFormStatus.failure,
        errorMessage: 'Agrega un titulo para tu libro.',
      ));
      return;
    }
    if (state.chapters.isEmpty ||
        state.chapters.every((chapter) => chapter.content.trim().isEmpty)) {
      emit(state.copyWith(
        status: BookFormStatus.failure,
        errorMessage: 'Escribe al menos un capitulo para publicar.',
      ));
      return;
    }

    // Validar que ningún capítulo esté vacío (hasta el índice a publicar)
    final chaptersToPublish =
        state.chapters.take(state.publishIndex + 1).toList();
    if (chaptersToPublish.any((chapter) => chapter.content.trim().isEmpty)) {
      emit(state.copyWith(
        status: BookFormStatus.failure,
        errorMessage:
            'Completa el contenido de todos los capítulos antes de publicar.',
      ));
      return;
    }

    emit(state.copyWith(
      status: BookFormStatus.submitting,
      clearError: true,
      clearLastCreatedBook: true,
    ));

    final publishIndex = state.publishIndex;
    final chapters = <ChapterEntity>[];
    for (int i = 0; i < state.chapters.length; i++) {
      final chapter = state.chapters[i];
      chapters.add(
        ChapterEntity(
          id: chapter.id,
          order: chapter.order,
          title: chapter.title.trim().isEmpty
              ? 'Capitulo ${chapter.order}'
              : chapter.title.trim(),
          content: chapter.content.trim(),
          isPublished: i <= publishIndex,
        ),
      );
    }

    try {
      final coverUrl = await _prepareCoverUrl();
      final createdBook = await _createBook(
        authorId: _user.id,
        authorName: _user.username.isEmpty ? _user.email : _user.username,
        title: state.title.trim(),
        category: state.category,
        description: state.description.trim(),
        chapters: chapters,
        publishedChapterIndex: state.publishIndex,
        coverPath: coverUrl,
      );

      _booksEventBus?.emitCreated(createdBook);

      // Eliminar borrador local al publicar exitosamente
      if (_draftId != null && _draftRepository != null) {
        await _draftRepository!.deleteDraft(_draftId!);
      }

      emit(state.copyWith(
        status: BookFormStatus.success,
        lastCreatedBook: createdBook,
        clearError: true,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: BookFormStatus.failure,
        errorMessage: 'No se pudo crear el libro. Intenta nuevamente.',
        clearLastCreatedBook: true,
      ));
    }
  }

  Future<String?> _prepareCoverUrl() async {
    final path = state.coverPath;
    if (path == null || path.isEmpty) {
      return null;
    }

    if (_looksLikeUrl(path)) {
      return path;
    }

    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final extension = p.extension(path).replaceAll('.', '').toLowerCase();

    return _uploadBookCover(
      authorId: _user.id,
      bytes: bytes,
      fileExtension: extension.isEmpty ? 'jpg' : extension,
    );
  }
}

bool _looksLikeUrl(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith('http://') ||
      normalized.startsWith('https://') ||
      normalized.startsWith('data:');
}
