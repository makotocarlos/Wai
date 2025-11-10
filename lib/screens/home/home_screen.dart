import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/books/domain/entities/book_entity.dart';
import '../../features/books/domain/usecases/watch_books.dart';
import '../../features/books/presentation/cubit/book_list_cubit.dart';
import '../../features/books/presentation/cubit/book_list_state.dart';
import '../../features/books/presentation/pages/book_detail_page.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_state.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../components/offline_banner.dart';
import '../profile/profile_screen.dart';
import '../write/writing_dashboard.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import '../../services/notification/notification_preferences.dart';
import '../../services/notification/push_notifications_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final NotificationsCubit _notificationsCubit;
  StreamSubscription<NotificationsState>? _notificationsSubscription;
  int _unreadNotifications = 0;
  late final NotificationsPage _notificationsPage;
  late final PushNotificationsService _pushNotificationsService;

  @override
  void initState() {
    super.initState();
    _notificationsCubit = sl<NotificationsCubit>();
    _notificationsCubit.start();
    _notificationsSubscription = _notificationsCubit.stream.listen((state) {
      final unread = state.notifications.where((item) => !item.isRead).length;
      if (unread != _unreadNotifications) {
        setState(() {
          _unreadNotifications = unread;
        });
      }
    });
    _notificationsPage = NotificationsPage(cubit: _notificationsCubit);
    _pushNotificationsService = sl<PushNotificationsService>()..initialize();
    NotificationPreferences.isPushEnabled().then((enabled) {
      if (!enabled) {
        return;
      }
      _pushNotificationsService.syncTokenIfAuthorized();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForPushNotifications();
    });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _notificationsCubit.close();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _maybePromptForPushNotifications() async {
    final alreadyPrompted = await NotificationPreferences.isPromptShown();
    if (alreadyPrompted || !mounted) {
      return;
    }

    final enablePush = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('¿Activar notificaciones push?'),
            content: const Text(
              'Podemos avisarte en tu teléfono cuando recibas mensajes, nuevos seguidores o capítulos en tus favoritos. '
              '¿Quieres activar las notificaciones push?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Solo en la app'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Activar'),
              ),
            ],
          ),
        ) ??
        false;

    await NotificationPreferences.setPromptShown();
    if (!enablePush) {
      await NotificationPreferences.setPushEnabled(false);
      await _pushNotificationsService.disablePushNotifications();
      return;
    }

    final granted = await _pushNotificationsService.enablePushNotifications();
    await NotificationPreferences.setPushEnabled(granted);

    if (!mounted) {
      return;
    }

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificaciones push activadas.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos activar las notificaciones push. Revisa los permisos del sistema.',
          ),
        ),
      );
    }
  }

  List<_TabItem> _buildTabs(BuildContext context, UserEntity? user) {
    return [
      _TabItem(
        title: 'Inicio',
        icon: Icons.home_outlined,
        builder: (_) => const _FeedView(),
      ),
      _TabItem(
        title: 'Buscar',
        icon: Icons.search_rounded,
        builder: (_) => const SearchScreen(),
      ),
      _TabItem(
        title: 'Notificaciones',
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        isNotifications: true,
        builder: (_) => user == null
            ? const _PlaceholderView(
                'Inicia sesión para ver tus notificaciones.',
              )
            : _notificationsPage,
      ),
      _TabItem(
        title: 'Biblioteca',
        icon: Icons.menu_book_outlined,
        builder: (_) => user == null
            ? const _PlaceholderView(
                'Inicia sesion para ver y gestionar tus libros publicados.',
              )
            : LibraryScreen(user: user),
      ),
      _TabItem(
        title: 'Escribir',
        icon: Icons.edit_outlined,
        builder: (_) => const WritingDashboard(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final avatarUrl = user?.avatarUrl;
    final displayName = (user?.username ?? user?.email ?? 'Autor').trim();
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(2)
        .join();
    final initialsFallback = initials.isEmpty ? 'A' : initials;
    final tabs = _buildTabs(context, user);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Image.asset('assets/logo.png'),
        ),
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(initialsFallback)
                    : null,
              ),
            ),
          ),
        ],
      ),
      // 🔥 Agregar banner de offline aquí
      body: OfflineBanner(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs.map((tab) => tab.builder(context)).toList(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.white60,
        backgroundColor: Theme.of(context).colorScheme.surface,
        items: tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: _buildTabIcon(context, tab, isActive: false),
                activeIcon: _buildTabIcon(context, tab, isActive: true),
                label: tab.title,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTabIcon(BuildContext context, _TabItem tab,
      {required bool isActive}) {
    final iconData =
        isActive && tab.activeIcon != null ? tab.activeIcon! : tab.icon;
    final icon = Icon(iconData);

    if (!tab.isNotifications || _unreadNotifications == 0) {
      return icon;
    }

    final badgeLabel =
        _unreadNotifications > 99 ? '99+' : '$_unreadNotifications';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -8,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              badgeLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.title,
    required this.icon,
    required this.builder,
    this.activeIcon,
    this.isNotifications = false,
  });

  final String title;
  final IconData icon;
  final IconData? activeIcon;
  final WidgetBuilder builder;
  final bool isNotifications;
}

class _FeedView extends StatefulWidget {
  const _FeedView();

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView>
    with AutomaticKeepAliveClientMixin {
  late final BookListCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = BookListCubit(
      watchBooks: sl<WatchBooksUseCase>(),
      eventsBus: sl(),
    )..start();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<BookListCubit, BookListState>(
        builder: (context, state) {
          switch (state.status) {
            case BookListStatus.initial:
            case BookListStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case BookListStatus.failure:
              return _ErrorRetryView(
                message:
                    state.errorMessage ?? 'No se pudieron cargar los libros.',
                onRetry: () => _cubit.start(),
              );
            case BookListStatus.success:
              if (state.books.isEmpty) {
                return const _PlaceholderView(
                  'Todavia no hay libros publicados. Comparte el primero desde "Escribir".',
                );
              }

              final categories = _groupBooksByCategory(state.books);

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  for (final entry in categories) ...[
                    Text(
                      entry.key,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: entry.value.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (_, index) => _BookCard(
                          book: entry.value[index],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              );
          }
        },
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookDetailPage(bookId: book.id),
          ),
        );
      },
      child: Container(
        width: 160,
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BookCoverImage(path: book.coverPath),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetryView extends StatelessWidget {
  const _ErrorRetryView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCoverImage extends StatelessWidget {
  const _BookCoverImage({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return const _DefaultCoverPlaceholder();
    }

    if (_looksLikeUrl(path!)) {
      return Image.network(
        path!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _DefaultCoverPlaceholder(),
      );
    }

    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _DefaultCoverPlaceholder(),
    );
  }
}

class _DefaultCoverPlaceholder extends StatelessWidget {
  const _DefaultCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Colors.grey.shade800,
      child: const Icon(
        Icons.menu_book_rounded,
        size: 36,
        color: Colors.white60,
      ),
    );
  }
}

List<MapEntry<String, List<BookEntity>>> _groupBooksByCategory(
  List<BookEntity> books,
) {
  final Map<String, List<BookEntity>> grouped = {};

  for (final book in books) {
    final key = book.category.trim().isEmpty ? 'Otros' : book.category.trim();
    grouped.putIfAbsent(key, () => <BookEntity>[]).add(book);
  }

  final entries = grouped.entries.toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

  return entries;
}

bool _looksLikeUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}
