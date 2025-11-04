import 'package:equatable/equatable.dart';

import '../../../../services/ai/gemini_search_service.dart';

class ChapterAiMessage extends Equatable {
  const ChapterAiMessage._({
    required this.isUser,
    required this.content,
  });

  const ChapterAiMessage.user(String content)
      : this._(isUser: true, content: content);

  const ChapterAiMessage.assistant(String content)
      : this._(isUser: false, content: content);

  final bool isUser;
  final String content;

  @override
  List<Object?> get props => [isUser, content];
}

class ChapterAiState extends Equatable {
  const ChapterAiState({
    this.isProofreading = false,
    this.proofreadingResult,
    this.isChatLoading = false,
    this.chatMessages = const [],
    this.chatIdeas = const [],
    this.chatNextSteps = const [],
    this.errorMessage,
  });

  final bool isProofreading;
  final ChapterProofreadingResult? proofreadingResult;
  final bool isChatLoading;
  final List<ChapterAiMessage> chatMessages;
  final List<String> chatIdeas;
  final List<String> chatNextSteps;
  final String? errorMessage;

  ChapterAiState copyWith({
    bool? isProofreading,
    ChapterProofreadingResult? proofreadingResult,
    bool clearProofreading = false,
    bool? isChatLoading,
    List<ChapterAiMessage>? chatMessages,
    List<String>? chatIdeas,
    List<String>? chatNextSteps,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChapterAiState(
      isProofreading: isProofreading ?? this.isProofreading,
      proofreadingResult: clearProofreading
          ? null
          : (proofreadingResult ?? this.proofreadingResult),
      isChatLoading: isChatLoading ?? this.isChatLoading,
      chatMessages: chatMessages ?? this.chatMessages,
      chatIdeas: chatIdeas ?? this.chatIdeas,
      chatNextSteps: chatNextSteps ?? this.chatNextSteps,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        isProofreading,
        proofreadingResult,
        isChatLoading,
        chatMessages,
        chatIdeas,
        chatNextSteps,
        errorMessage,
      ];
}
