import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_participant_entity.dart';
import '../cubit/chat_conversation_cubit.dart';
import '../cubit/chat_conversation_state.dart';

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.threadId,
    required this.currentUserId,
    required this.otherParticipant,
  });

  final String threadId;
  final String currentUserId;
  final ChatParticipantEntity otherParticipant;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  late final ChatConversationCubit _cubit;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _cubit = sl<ChatConversationCubit>(
      param1: widget.threadId,
      param2: widget.currentUserId,
    )..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text;
    try {
      await _cubit.send(text);
      _controller.clear();
      _inputFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: $error')),
        );
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMessageActions(ChatMessageEntity message) {
    final isMine = message.sender.id == widget.currentUserId;
    final actions = <Widget>[
      if (!message.isDeleted)
        ListTile(
          leading: const Icon(Icons.reply_outlined),
          title: const Text('Responder'),
          onTap: () {
            Navigator.of(context).pop();
            _cubit.setReply(message);
            _inputFocusNode.requestFocus();
          },
        ),
    ];

    if (isMine && !message.isDeleted) {
      actions.add(
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Eliminar para todos'),
          onTap: () async {
            Navigator.of(context).pop();
            try {
              await _cubit.deleteMessage(message);
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text('No se pudo eliminar el mensaje: $error')),
                );
            }
          },
        ),
      );
    }

    if (actions.isEmpty) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(ChatConversationState state) {
    final replyingTo = state.replyingTo;
    if (replyingTo == null) {
      return const SizedBox.shrink();
    }

    final author = replyingTo.sender.id == widget.currentUserId
        ? 'Tú'
        : replyingTo.sender.username.isNotEmpty
            ? replyingTo.sender.username
            : replyingTo.sender.email;
    final text = replyingTo.isDeleted
        ? 'Mensaje eliminado'
        : (replyingTo.body ?? '');

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  author,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  text.isEmpty ? 'Mensaje' : text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cubit.clearReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageEntity message) {
    final isMine = message.sender.id == widget.currentUserId;
  final background = isMine
    ? Theme.of(context).colorScheme.primary
    : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isMine
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final reply = message.replyTo;
    final timestamp = DateFormat('HH:mm').format(message.createdAt.toLocal());

    Widget? replySection;
    Color adjustAlpha(Color color, double factor) {
      final newAlpha = (color.a * factor).clamp(0.0, 1.0);
      return color.withValues(alpha: newAlpha);
    }

    if (reply != null) {
      final replyAuthor = reply.sender.id == widget.currentUserId
          ? 'Tú'
          : reply.sender.username.isNotEmpty
              ? reply.sender.username
              : reply.sender.email;
      final replyText = reply.isDeleted
          ? 'Mensaje eliminado'
          : (reply.body ?? 'Mensaje');
      replySection = Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color.fromARGB(13, 0, 0, 0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replyAuthor,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: adjustAlpha(textColor, 0.8)),
            ),
            const SizedBox(height: 2),
            Text(
              replyText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: adjustAlpha(textColor, 0.9)),
            ),
          ],
        ),
      );
    }

    final content = message.isDeleted
        ? Text(
            'Mensaje eliminado',
      style: Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: adjustAlpha(textColor, 0.7), fontStyle: FontStyle.italic),
          )
        : Text(
            message.body ?? '',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: textColor),
          );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: Radius.circular(isMine ? 0 : 16),
              bottomLeft: Radius.circular(isMine ? 16 : 0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replySection != null) replySection,
              content,
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  timestamp,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: adjustAlpha(textColor, 0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.otherParticipant;
    final title = other.username.isEmpty ? other.email : other.username;
    final avatar = other.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? NetworkImage(avatar)
                  : null,
              child: avatar == null || avatar.isEmpty
                  ? Text(title.isNotEmpty ? title[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: BlocProvider.value(
        value: _cubit,
        child: BlocListener<ChatConversationCubit, ChatConversationState>(
          listenWhen: (previous, current) => previous.messages != current.messages,
          listener: (_, __) => _scrollToBottom(),
          child: Column(
            children: [
              Expanded(
                child: BlocConsumer<ChatConversationCubit, ChatConversationState>(
                  listenWhen: (previous, current) => current.errorMessage != null && previous.errorMessage != current.errorMessage,
                  listener: (context, state) {
                    final message = state.errorMessage;
                    if (message == null || !mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(message)));
                  },
                  builder: (context, state) {
                    switch (state.status) {
                      case ChatConversationStatus.initial:
                      case ChatConversationStatus.loading:
                        return const Center(child: CircularProgressIndicator());
                      case ChatConversationStatus.error:
                        return const _ConversationError();
                      case ChatConversationStatus.loaded:
                        if (state.messages.isEmpty) {
                          return const _ConversationEmpty();
                        }
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: state.messages.length,
                          itemBuilder: (context, index) {
                            final message = state.messages[index];
                            return _buildMessageBubble(message);
                          },
                        );
                    }
                  },
                ),
              ),
              BlocBuilder<ChatConversationCubit, ChatConversationState>(
                buildWhen: (previous, current) => previous.replyingTo != current.replyingTo,
                builder: (context, state) => _buildReplyPreview(state),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _inputFocusNode,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BlocBuilder<ChatConversationCubit, ChatConversationState>(
                        buildWhen: (previous, current) => previous.isSending != current.isSending,
                        builder: (context, state) {
                          return IconButton(
                            icon: state.isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded),
                            onPressed: state.isSending ? null : _sendMessage,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationEmpty extends StatelessWidget {
  const _ConversationEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.chat_bubble_outline, size: 48),
            SizedBox(height: 16),
            Text(
              'Saluda a tu nueva colaboración y planifica la historia juntos.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationError extends StatelessWidget {
  const _ConversationError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline, size: 48),
            SizedBox(height: 16),
            Text(
              'No se pudo cargar esta conversación. Intenta nuevamente más tarde.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
