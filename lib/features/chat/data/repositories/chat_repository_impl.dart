import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_participant_entity.dart';
import '../../domain/entities/chat_thread_entity.dart';
import '../../domain/repositories/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  static const _threadsTable = 'direct_threads';
  static const _participantsTable = 'direct_thread_participants';
  static const _messagesTable = 'direct_messages';

  @override
  Future<String> createOrFetchThread({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('User not authenticated');
    }

    final resolvedCurrentUserId = authUser.id;
    final effectiveCurrentUserId =
        resolvedCurrentUserId == currentUserId ? currentUserId : resolvedCurrentUserId;

    if (effectiveCurrentUserId == otherUserId) {
      throw ArgumentError('Cannot create conversation with the same user');
    }

    final existingId = await _findThreadBetween(effectiveCurrentUserId, otherUserId);
    if (existingId != null) {
      return existingId;
    }

    final inserted = await _client
        .from(_threadsTable)
        .insert({
          'created_by': effectiveCurrentUserId,
        })
        .select('id')
        .maybeSingle();

    if (inserted == null) {
      throw Exception('No se pudo crear el hilo de conversación.');
    }

    final threadId = inserted['id'] as String;

    await _client.from(_participantsTable).insert({
      'thread_id': threadId,
      'profile_id': effectiveCurrentUserId,
      'added_by': effectiveCurrentUserId,
    });

    await _client.from(_participantsTable).insert({
      'thread_id': threadId,
      'profile_id': otherUserId,
      'added_by': effectiveCurrentUserId,
    });

    return threadId;
  }

  @override
  Stream<List<ChatThreadEntity>> watchThreads({required String userId}) {
    final controller = StreamController<List<ChatThreadEntity>>.broadcast();
    final subscriptions = <StreamSubscription<List<Map<String, dynamic>>>>[];

    Future<void> emitLatest() async {
      if (controller.isClosed || !controller.hasListener) {
        return;
      }
      try {
        final threads = await _fetchThreads(userId);
        controller.add(threads);
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller.onListen = () {
      subscriptions.add(
        _client
            .from(_participantsTable)
            .stream(primaryKey: ['thread_id', 'profile_id'])
            .eq('profile_id', userId)
            .listen((_) => emitLatest()),
      );

      subscriptions.add(
        _client
            .from(_threadsTable)
            .stream(primaryKey: ['id'])
            .listen((_) => emitLatest()),
      );

      emitLatest();
    };

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  @override
  Stream<List<ChatMessageEntity>> watchMessages({required String threadId}) {
    final controller = StreamController<List<ChatMessageEntity>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? subscription;

    Future<void> emitLatest() async {
      if (controller.isClosed || !controller.hasListener) {
        return;
      }
      try {
        final messages = await _fetchMessages(threadId);
        controller.add(messages);
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller.onListen = () {
      subscription = _client
          .from(_messagesTable)
          .stream(primaryKey: ['id'])
          .eq('thread_id', threadId)
          .listen((_) => emitLatest());
      emitLatest();
    };

    controller.onCancel = () async {
      await subscription?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<ChatThreadEntity?> getThreadById({
    required String userId,
    required String threadId,
  }) async {
    final threads = await _fetchThreads(userId);
    for (final thread in threads) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    return null;
  }

  @override
  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String body,
    String? replyToMessageId,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return;
    }

    final inserted = await _client
        .from(_messagesTable)
        .insert({
          'thread_id': threadId,
          'sender_id': senderId,
          'body': trimmedBody,
          'reply_to': replyToMessageId,
        })
        .select('id, created_at')
        .maybeSingle();

    if (inserted == null) {
      throw Exception('No se pudo enviar el mensaje.');
    }

    final createdAt = DateTime.parse(inserted['created_at'] as String);
    final preview = _buildPreview(trimmedBody);

    await _client
        .from(_threadsTable)
        .update({
          'last_message_preview': preview,
          'last_message_at': createdAt.toIso8601String(),
          'last_message_sender': senderId,
          'updated_at': createdAt.toIso8601String(),
        })
        .eq('id', threadId);
  }

  @override
  Future<void> deleteMessage({
    required String messageId,
    required String senderId,
  }) async {
    final message = await _client
        .from(_messagesTable)
        .select('thread_id, created_at')
        .eq('id', messageId)
        .eq('sender_id', senderId)
        .maybeSingle();

    if (message == null) {
      throw Exception('Mensaje no encontrado o sin permisos para eliminar.');
    }

    final threadId = message['thread_id'] as String;
    final now = DateTime.now().toUtc();

    await _client
        .from(_messagesTable)
        .update({
          'body': null,
          'deleted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', senderId);

    final last = await _client
        .from(_messagesTable)
        .select('id, sender_id, body, deleted_at, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (last == null) {
      await _client
          .from(_threadsTable)
          .update({
            'last_message_preview': null,
            'last_message_at': null,
            'last_message_sender': null,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', threadId);
      return;
    }

    final lastDeletedAt = last['deleted_at'] as String?;
    final lastCreatedAt = DateTime.parse(last['created_at'] as String);
    final lastPreview = lastDeletedAt != null
        ? 'Mensaje eliminado'
        : _buildPreview((last['body'] as String?) ?? '');

    await _client
        .from(_threadsTable)
        .update({
          'last_message_preview': lastPreview,
          'last_message_at': lastCreatedAt.toIso8601String(),
          'last_message_sender': last['sender_id'],
          'updated_at': now.toIso8601String(),
        })
        .eq('id', threadId);
  }

  Future<String?> _findThreadBetween(
    String currentUserId,
    String otherUserId,
  ) async {
    final currentThreads = await _client
        .from(_participantsTable)
        .select('thread_id')
        .eq('profile_id', currentUserId);

    if (currentThreads.isEmpty) {
      return null;
    }

    final threadIds = currentThreads
        .map((row) => row['thread_id'] as String)
        .toList(growable: false);

  final matches = await _client
    .from(_participantsTable)
    .select('thread_id')
    .inFilter('thread_id', threadIds)
    .eq('profile_id', otherUserId)
    .maybeSingle();

    return matches == null ? null : matches['thread_id'] as String;
  }

  Future<List<ChatThreadEntity>> _fetchThreads(String userId) async {
    final participantRows = await _client
        .from(_participantsTable)
        .select('thread_id')
        .eq('profile_id', userId);

    if (participantRows.isEmpty) {
      return const <ChatThreadEntity>[];
    }

    final threadIds = participantRows
        .map<String>((dynamic row) => row['thread_id'] as String)
        .toSet()
        .toList(growable: false);

    final response = await _client
        .from(_threadsTable)
        .select('''
          id,
          created_at,
          updated_at,
          last_message_at,
          last_message_preview,
          last_message_sender,
          direct_thread_participants:direct_thread_participants_thread_id_fkey!inner(
            profile:profiles!direct_thread_participants_profile_id_fkey(
              id,
              username,
              email,
              avatar_url
            )
          )
        ''')
        .inFilter('id', threadIds)
        .order('last_message_at', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);

    return response.map<ChatThreadEntity>((dynamic row) {
      final data = row as Map<String, dynamic>;
      final participantsData =
          (data['direct_thread_participants'] as List<dynamic>? ?? const [])
              .map((dynamic participantRow) {
        final participant = participantRow as Map<String, dynamic>;
        final profile = participant['profile'] as Map<String, dynamic>;
        return ChatParticipantEntity(
          id: profile['id'] as String,
          username: (profile['username'] as String?) ?? 'Usuario',
          email: (profile['email'] as String?) ?? '',
          avatarUrl: profile['avatar_url'] as String?,
        );
      }).toList(growable: false);

      final previewText = data['last_message_preview'] as String?;
      final lastMessageAtRaw = data['last_message_at'] as String?;

      final preview = data['last_message_sender'] == null
          ? null
          : ChatThreadPreview(
              senderId: data['last_message_sender'] as String,
              body: previewText,
              sentAt: lastMessageAtRaw == null
                  ? null
                  : DateTime.parse(lastMessageAtRaw),
              isDeleted: previewText == 'Mensaje eliminado',
            );

      return ChatThreadEntity(
        id: data['id'] as String,
        createdAt: DateTime.parse(data['created_at'] as String),
        updatedAt: data['updated_at'] == null
            ? null
            : DateTime.parse(data['updated_at'] as String),
        participants: participantsData,
        preview: preview,
      );
    }).toList(growable: false);
  }

  Future<List<ChatMessageEntity>> _fetchMessages(String threadId) async {
    final response = await _client
        .from(_messagesTable)
        .select('''
          id,
          thread_id,
          sender_id,
          body,
          reply_to,
          created_at,
          updated_at,
          deleted_at,
          sender:profiles!direct_messages_sender_id_fkey(
            id,
            username,
            email,
            avatar_url
          )
        ''')
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);

    final rawMessages = response.map<_RawMessage>((dynamic row) {
      final data = row as Map<String, dynamic>;
      final senderData = data['sender'] as Map<String, dynamic>;
      return _RawMessage(
        id: data['id'] as String,
        threadId: data['thread_id'] as String,
        body: data['body'] as String?,
        sender: ChatParticipantEntity(
          id: senderData['id'] as String,
          username: (senderData['username'] as String?) ?? 'Usuario',
          email: (senderData['email'] as String?) ?? '',
          avatarUrl: senderData['avatar_url'] as String?,
        ),
        createdAt: DateTime.parse(data['created_at'] as String),
        updatedAt: data['updated_at'] == null
            ? null
            : DateTime.parse(data['updated_at'] as String),
        deletedAt: data['deleted_at'] == null
            ? null
            : DateTime.parse(data['deleted_at'] as String),
        replyToId: data['reply_to'] as String?,
      );
    }).toList(growable: false);

    final messageMap = {
      for (final raw in rawMessages) raw.id: raw,
    };

    return rawMessages.map((raw) {
      ChatMessageReference? reply;
      if (raw.replyToId != null) {
        final referenced = messageMap[raw.replyToId!];
        if (referenced != null) {
          reply = ChatMessageReference(
            id: referenced.id,
            sender: referenced.sender,
            body: referenced.body,
            deletedAt: referenced.deletedAt,
          );
        }
      }

      return ChatMessageEntity(
        id: raw.id,
        threadId: raw.threadId,
        sender: raw.sender,
        body: raw.body,
        createdAt: raw.createdAt,
        updatedAt: raw.updatedAt,
        deletedAt: raw.deletedAt,
        replyTo: reply,
      );
    }).toList(growable: false);
  }

  String _buildPreview(String body) {
    final text = body.trim();
    if (text.isEmpty) {
      return '';
    }
    if (text.length <= 120) {
      return text;
    }
    final clipped = text.substring(0, math.min(120, text.length)).trim();
    return '$clipped...';
  }
}

class _RawMessage {
  const _RawMessage({
    required this.id,
    required this.threadId,
    required this.sender,
    this.body,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.replyToId,
  });

  final String id;
  final String threadId;
  final ChatParticipantEntity sender;
  final String? body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? replyToId;
}
