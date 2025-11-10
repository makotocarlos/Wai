import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../books/domain/usecases/watch_book.dart';
import '../../../books/domain/entities/book_entity.dart';
import '../../../books/presentation/pages/book_detail_page.dart';
import '../../../books/presentation/pages/chapter_reader_page.dart';
import '../../../chat/domain/entities/chat_participant_entity.dart';
import '../../../chat/domain/usecases/get_thread_by_id.dart';
import '../../../chat/presentation/pages/chat_conversation_page.dart';
import '../../../../screens/profile/profile_screen.dart';
import '../../domain/entities/notification_entity.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.cubit});

  final NotificationsCubit? cubit;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with AutomaticKeepAliveClientMixin {
  late final NotificationsCubit _cubit;
  late final bool _ownsCubit;
  final Map<NotificationCategory, bool> _expandedCategories = {
    for (final category in NotificationCategory.values) category: false,
  };

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? sl<NotificationsCubit>();
    if (_ownsCubit) {
      _cubit.start();
    }
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _markCategory(NotificationCategory category) {
    _cubit.markCategoryAsRead(category);
  }

  void _toggleCategory(NotificationCategory category) {
    setState(() {
      _expandedCategories[category] = !(_expandedCategories[category] ?? false);
    });
  }

  Future<void> _showDeleteAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar todas las notificaciones'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todas tus notificaciones? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Mostrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Eliminando notificaciones...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );

        await _cubit.deleteAllNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Todas las notificaciones eliminadas'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          // Mensaje de error más detallado
          String errorMessage = '❌ Error al eliminar notificaciones';
          
          if (e.toString().contains('políticas RLS') || 
              e.toString().contains('RLS') ||
              e.toString().contains('Supabase')) {
            errorMessage = '❌ Error de permisos en Supabase\n'
                'Falta configurar políticas RLS.\n'
                'Ver archivo: supabase_notifications_delete_policy.sql';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Entendido',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.status == NotificationsStatus.loading ||
              state.status == NotificationsStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == NotificationsStatus.error) {
            return _NotificationsError(
              message: state.errorMessage ??
                  'No pudimos cargar tus notificaciones.',
              onRetry: _cubit.start,
            );
          }

          if (state.notifications.isEmpty) {
            return const _EmptyNotifications();
          }

          final grouped = state.grouped();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            children: [
              _Header(
                totalUnread: state.notifications
                    .where((item) => !item.isRead)
                    .length,
                onMarkAllRead: _cubit.markAllAsRead,
                onDeleteAll: _showDeleteAllDialog,
              ),
              const SizedBox(height: 16),
              for (final category in NotificationCategory.values)
                if (grouped[category]?.isNotEmpty ?? false) ...[
                  _CategorySection(
                    category: category,
                    notifications: grouped[category]!,
                    totalCount: grouped[category]!.length,
                    unreadCount:
                        state.unreadCountByCategory(category),
                    isExpanded: _expandedCategories[category] ?? false,
                    onCategoryMarkRead: () => _markCategory(category),
                    onNotificationTap: (item) {
                      _cubit.markNotificationAsRead(item.id);
                      unawaited(_handleNavigation(item));
                    },
                    onToggleExpanded: () => _toggleCategory(category),
                  ),
                  const SizedBox(height: 24),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleNavigation(AppNotification notification) async {
    if (!mounted) {
      return;
    }

    switch (notification.type) {
      case NotificationType.bookLike:
        await _openBook(notification);
        break;
      case NotificationType.bookComment:
        await _openBook(notification, highlightComment: true);
        break;
      case NotificationType.newChapter:
        await _openChapter(notification);
        break;
      case NotificationType.chapterComment:
        await _openChapter(notification, highlightComment: true);
        break;
      case NotificationType.chatMessage:
        await _openChat(notification);
        break;
      case NotificationType.newFollower:
        await _openProfile(notification);
        break;
    }
  }

  Future<void> _openBook(
    AppNotification notification, {
    bool highlightComment = false,
  }) async {
    final bookId = notification.data['book_id'];
    if (bookId is! String || bookId.isEmpty) {
      _showMessage('No encontramos información del libro.');
      return;
    }

    final commentId = highlightComment
        ? notification.data['comment_id'] as String?
        : null;

    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookDetailPage(
          bookId: bookId,
          highlightCommentId: commentId,
        ),
      ),
    );
  }

  Future<void> _openChapter(
    AppNotification notification, {
    bool highlightComment = false,
  }) async {
    final bookId = notification.data['book_id'] as String?;
    final chapterId = notification.data['chapter_id'] as String?;
    if (bookId == null || chapterId == null) {
      _showMessage('No encontramos el capítulo asociado.');
      return;
    }

    final authUser = context.read<AuthBloc>().state.user;
    if (authUser == null) {
      _showMessage('Inicia sesión para abrir el contenido.');
      return;
    }

    final book = await _fetchBook(bookId: bookId, userId: authUser.id);
    if (!mounted) {
      return;
    }
    if (book == null) {
      _showMessage('No pudimos cargar el libro.');
      return;
    }

    final chapters = book.chapters;
    final index = chapters.indexWhere((chapter) => chapter.id == chapterId);
    final initialIndex = index < 0 ? 0 : index;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderPage(
          book: book,
          initialChapterIndex: initialIndex,
          targetChapterId: chapterId,
          targetCommentId: highlightComment
              ? notification.data['comment_id'] as String?
              : null,
        ),
      ),
    );
  }

  Future<void> _openChat(AppNotification notification) async {
    final threadId = notification.data['thread_id'] as String?;
    if (threadId == null || threadId.isEmpty) {
      _showMessage('No pudimos abrir la conversación.');
      return;
    }

    final authUser = context.read<AuthBloc>().state.user;
    if (authUser == null) {
      _showMessage('Inicia sesión para abrir el chat.');
      return;
    }

    final thread = await sl<GetThreadByIdUseCase>()(
      userId: authUser.id,
      threadId: threadId,
    );
    if (!mounted) {
      return;
    }
    if (thread == null || thread.participants.isEmpty) {
      _showMessage('La conversación ya no está disponible.');
      return;
    }

    ChatParticipantEntity other = thread.participants.first;
    for (final participant in thread.participants) {
      if (participant.id != authUser.id) {
        other = participant;
        break;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationPage(
          threadId: thread.id,
          currentUserId: authUser.id,
          otherParticipant: other,
        ),
      ),
    );
  }

  Future<void> _openProfile(AppNotification notification) async {
    final userId = notification.data['actor_id'] as String?;
    if (userId == null || userId.isEmpty) {
      _showMessage('No encontramos el perfil.');
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
  }

  Future<BookEntity?> _fetchBook({
    required String bookId,
    required String userId,
  }) async {
    try {
      return await sl<WatchBookUseCase>()(
        bookId: bookId,
        userId: userId,
      ).first.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalUnread, 
    required this.onMarkAllRead,
    required this.onDeleteAll,
  });

  final int totalUnread;
  final VoidCallback onMarkAllRead;
  final VoidCallback onDeleteAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Notificaciones',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Eliminar todas las notificaciones',
          onPressed: onDeleteAll,
        ),
        if (totalUnread > 0)
          TextButton(
            onPressed: onMarkAllRead,
            child: const Text('Marcar todo como leído'),
          ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.notifications,
    required this.totalCount,
    required this.unreadCount,
    required this.isExpanded,
    required this.onCategoryMarkRead,
    required this.onNotificationTap,
    required this.onToggleExpanded,
  });

  final NotificationCategory category;
  final List<AppNotification> notifications;
  final int totalCount;
  final int unreadCount;
  final bool isExpanded;
  final VoidCallback onCategoryMarkRead;
  final ValueChanged<AppNotification> onNotificationTap;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final summaryBuffer = StringBuffer()
      ..write(totalCount == 1
          ? '1 notificación'
          : '$totalCount notificaciones');
    if (unreadCount > 0) {
      summaryBuffer.write(' · $unreadCount sin leer');
    }

    final canExpand = totalCount > 1;
    final visibleNotifications = isExpanded
        ? notifications
        : notifications.take(1).toList(growable: false);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summaryBuffer.toString(),
                        style: textTheme.bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: onCategoryMarkRead,
                    child: Text('Marcar $unreadCount como leídas'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...visibleNotifications.map(
            (notification) => _NotificationTile(
              notification: notification,
              onTap: () => onNotificationTap(notification),
            ),
          ),
          if (canExpand)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: onToggleExpanded,
                icon: Icon(isExpanded
                    ? Icons.expand_less
                    : Icons.expand_more),
                label: Text(isExpanded ? 'Ver menos' : 'Ver más'),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  IconData _resolveIcon() {
    switch (notification.type) {
      case NotificationType.bookLike:
        return Icons.favorite_border;
      case NotificationType.newFollower:
        return Icons.group_add_outlined;
      case NotificationType.bookComment:
        return Icons.comment_outlined;
      case NotificationType.chapterComment:
        return Icons.chat_bubble_outline;
      case NotificationType.chatMessage:
        return Icons.forum_outlined;
      case NotificationType.newChapter:
        return Icons.auto_stories_outlined;
    }
  }

  Color _resolveAccent(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return notification.isRead ? color.withOpacity(0.5) : color;
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = notification.createdAt;
    final accent = _resolveAccent(context);
    final subtitle = Text(
      notification.body,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: accent.withOpacity(0.15),
        foregroundColor: accent,
        child: Icon(_resolveIcon()),
      ),
      title: Text(notification.title ?? _resolveDefaultTitle()),
      subtitle: subtitle,
      trailing: Text(_formatTimestamp(createdAt)),
    );
  }

  String _resolveDefaultTitle() {
    switch (notification.type) {
      case NotificationType.bookLike:
        return 'Nuevo me gusta';
      case NotificationType.newFollower:
        return 'Nuevo seguidor';
      case NotificationType.bookComment:
        return 'Nuevo comentario';
      case NotificationType.chapterComment:
        return 'Nuevo comentario';
      case NotificationType.chatMessage:
        return 'Nuevo mensaje';
      case NotificationType.newChapter:
        return 'Nuevo capítulo publicado';
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Justo ahora';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h';
    }
    return '${difference.inDays}d';
  }
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.notifications_none, size: 48),
            SizedBox(height: 16),
            Text(
              'Aún no tienes notificaciones. Cuando suceda algo importante, lo verás aquí.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
