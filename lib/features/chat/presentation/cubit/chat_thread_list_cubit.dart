import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat_thread_entity.dart';
import '../../domain/usecases/watch_threads.dart';
import 'chat_thread_list_state.dart';

class ChatThreadListCubit extends Cubit<ChatThreadListState> {
  ChatThreadListCubit(this._watchThreads)
      : super(const ChatThreadListState());

  final WatchThreadsUseCase _watchThreads;
  StreamSubscription<List<ChatThreadEntity>>? _subscription;
  String? _userId;

  void start(String userId) {
    if (_userId == userId && _subscription != null) {
      return;
    }

    _userId = userId;
    emit(state.copyWith(status: ChatThreadListStatus.loading));

    _subscription?.cancel();
    _subscription = _watchThreads(userId: userId).listen(
      (threads) {
        emit(
          state.copyWith(
            status: ChatThreadListStatus.loaded,
            threads: threads,
            errorMessage: null,
          ),
        );
      },
      onError: (error) {
        emit(
          state.copyWith(
            status: ChatThreadListStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
