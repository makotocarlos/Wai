import 'package:bloc/bloc.dart';

import '../../../../services/ai/gemini_search_service.dart';
import 'chapter_ai_state.dart';

class ChapterAiCubit extends Cubit<ChapterAiState> {
  ChapterAiCubit({required GeminiSearchService geminiSearchService})
      : _geminiSearchService = geminiSearchService,
        super(const ChapterAiState());

  final GeminiSearchService _geminiSearchService;

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  void resetProofreading() {
    emit(state.copyWith(clearProofreading: true));
  }

  void resetChat() {
    emit(state.copyWith(
      chatMessages: const [],
      chatIdeas: const [],
      chatNextSteps: const [],
      isChatLoading: false,
    ));
  }

  void hydrateChat({
    List<ChapterAiMessage> messages = const [],
    List<String> ideas = const [],
    List<String> nextSteps = const [],
  }) {
    emit(state.copyWith(
      chatMessages: messages,
      chatIdeas: ideas,
      chatNextSteps: nextSteps,
      isChatLoading: false,
      clearError: true,
    ));
  }

  Future<void> proofreadChapter({
    required String bookTitle,
    required String chapterTitle,
    required String chapterContent,
    List<String> previousChapters = const [],
    String? synopsis,
  }) async {
    if (chapterContent.trim().isEmpty) {
      emit(state.copyWith(
        errorMessage: 'Escribe contenido para poder corregirlo.',
        clearProofreading: true,
      ));
      return;
    }

    if (!_geminiSearchService.isConfigured) {
      emit(state.copyWith(
        errorMessage:
            'Configura la variable GEMINI_API_KEY para usar las herramientas de escritura.',
        clearProofreading: true,
      ));
      return;
    }

    emit(state.copyWith(
      isProofreading: true,
      clearProofreading: true,
      clearError: true,
    ));

    try {
      final result = await _geminiSearchService.proofreadChapter(
        bookTitle: bookTitle,
        chapterTitle: chapterTitle,
        chapterContent: chapterContent,
        previousChapters: previousChapters,
        synopsis: synopsis,
      );

      emit(state.copyWith(
        isProofreading: false,
        proofreadingResult: result,
        clearError: true,
      ));
    } on GeminiNotConfiguredException {
      emit(state.copyWith(
        isProofreading: false,
        errorMessage:
            'Configura la variable GEMINI_API_KEY para usar las herramientas de escritura.',
      ));
    } on GeminiSearchFailure catch (error) {
      emit(state.copyWith(
        isProofreading: false,
        errorMessage: error.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        isProofreading: false,
        errorMessage: 'No pudimos corregir el texto en este momento.',
      ));
    }
  }

  Future<void> sendChatMessage({
    required String message,
    required ChapterStoryContext storyContext,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    if (!_geminiSearchService.isConfigured) {
      emit(state.copyWith(
        errorMessage:
            'Configura la variable GEMINI_API_KEY para usar el chatbot de escritura.',
      ));
      return;
    }

    final userMessage = ChapterAiMessage.user(trimmed);
    final updatedMessages = [...state.chatMessages, userMessage];

    emit(state.copyWith(
      chatMessages: updatedMessages,
      isChatLoading: true,
      clearError: true,
    ));

    try {
      final reply = await _geminiSearchService.chatAboutChapter(
        prompt: trimmed,
        context: storyContext,
        history: updatedMessages
            .map((msg) => msg.isUser
                ? ChapterChatTurn.user(msg.content)
                : ChapterChatTurn.assistant(msg.content))
            .toList(growable: false),
      );

      final responseMessage = ChapterAiMessage.assistant(reply.reply);
      emit(state.copyWith(
        chatMessages: [...updatedMessages, responseMessage],
        chatIdeas: reply.ideas,
        chatNextSteps: reply.suggestedNextSteps,
        isChatLoading: false,
      ));
    } on GeminiNotConfiguredException {
      emit(state.copyWith(
        chatMessages: updatedMessages,
        isChatLoading: false,
        errorMessage:
            'Configura la variable GEMINI_API_KEY para usar el chatbot de escritura.',
      ));
    } on GeminiSearchFailure catch (error) {
      emit(state.copyWith(
        chatMessages: updatedMessages,
        isChatLoading: false,
        errorMessage: error.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        chatMessages: updatedMessages,
        isChatLoading: false,
        errorMessage: 'No pudimos procesar la solicitud del chatbot.',
      ));
    }
  }
}
