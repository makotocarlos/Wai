import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/chat_participant_entity.dart';
import '../../domain/entities/chat_thread_entity.dart';
import '../cubit/chat_thread_list_cubit.dart';
import '../cubit/chat_thread_list_state.dart';
import 'chat_conversation_page.dart';

class ChatThreadListPage extends StatefulWidget {
  const ChatThreadListPage({
    super.key,
    required this.currentUserId,
    this.showAppBar = true,
  });

  final String currentUserId;
  final bool showAppBar;

  @override
  State<ChatThreadListPage> createState() => _ChatThreadListPageState();
}

class _ChatThreadListPageState extends State<ChatThreadListPage> {
  late final ChatThreadListCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<ChatThreadListCubit>()..start(widget.currentUserId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  ChatParticipantEntity _resolveOtherParticipant(ChatThreadEntity thread) {
    return thread.participants.firstWhere(
      (participant) => participant.id != widget.currentUserId,
      orElse: () => thread.participants.first,
    );
  }

  String _formatPreview(ChatThreadEntity thread) {
    final preview = thread.preview;
    if (preview == null) {
      return 'Inicia la conversación';
    }

    if (preview.isDeleted) {
      return 'Mensaje eliminado';
    }

    final body = preview.body ?? '';
    if (body.isEmpty) {
      return 'Mensaje enviado';
    }

    final prefix = preview.senderId == widget.currentUserId ? 'Tú: ' : '';
    return prefix + body;
  }

  String _formatTimestamp(ChatThreadEntity thread) {
    final sentAt = thread.preview?.sentAt;
    if (sentAt == null) {
      return '';
    }

    final now = DateTime.now();
    if (sentAt.year == now.year && sentAt.month == now.month && sentAt.day == now.day) {
      return DateFormat('HH:mm').format(sentAt);
    }

    return DateFormat('dd/MM').format(sentAt);
  }

  Future<void> _openConversation(ChatThreadEntity thread) async {
    final other = _resolveOtherParticipant(thread);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationPage(
          threadId: thread.id,
          currentUserId: widget.currentUserId,
          otherParticipant: other,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<ChatThreadListCubit, ChatThreadListState>(
        builder: (context, state) {
          switch (state.status) {
            case ChatThreadListStatus.initial:
            case ChatThreadListStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ChatThreadListStatus.error:
              return _ChatThreadError(
                message: state.errorMessage ?? 'No pudimos cargar las conversaciones.',
                onRetry: () => _cubit.start(widget.currentUserId),
              );
            case ChatThreadListStatus.loaded:
              if (state.threads.isEmpty) {
                return const _ChatThreadEmpty();
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: state.threads.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final thread = state.threads[index];
                  final other = _resolveOtherParticipant(thread);
                  final preview = _formatPreview(thread);
                  final timestamp = _formatTimestamp(thread);

                  return ListTile(
                    onTap: () => _openConversation(thread),
                    leading: CircleAvatar(
                      backgroundImage: other.avatarUrl != null && other.avatarUrl!.isNotEmpty
                          ? NetworkImage(other.avatarUrl!)
                          : null,
                      child: (other.avatarUrl == null || other.avatarUrl!.isEmpty)
                          ? Text(other.username.isNotEmpty ? other.username[0].toUpperCase() : other.email[0].toUpperCase())
                          : null,
                    ),
                    title: Text(other.username.isEmpty ? other.email : other.username),
                    subtitle: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: timestamp.isEmpty
                        ? null
                        : Text(
                            timestamp,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  );
                },
              );
          }
        },
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos y colaboraciones'),
      ),
      body: content,
    );
  }
}

class _ChatThreadEmpty extends StatelessWidget {
  const _ChatThreadEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.forum_outlined, size: 48),
            SizedBox(height: 16),
            Text(
              'Todavía no tienes conversaciones. Empieza a colaborar desde los perfiles de otros autores.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatThreadError extends StatelessWidget {
  const _ChatThreadError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
