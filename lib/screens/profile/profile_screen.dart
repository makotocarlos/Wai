import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:wappa_app/core/di/injection.dart';
import 'package:wappa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:wappa_app/features/chat/domain/entities/chat_participant_entity.dart';
import 'package:wappa_app/features/chat/domain/usecases/create_or_fetch_thread.dart';
import 'package:wappa_app/features/chat/presentation/pages/chat_conversation_page.dart';
import 'package:wappa_app/features/chat/presentation/pages/chat_thread_list_page.dart';
import 'package:wappa_app/features/profile/domain/entities/profile_entity.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_connections_cubit.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_state.dart';
import 'profile_settings_screen.dart';
import 'profile_user_list_screen.dart';
import 'profile_favorites_screen.dart';
import 'profile_books_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.userId});

  static const String routeName = '/profile';

  final String? userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => sl<ProfileCubit>()..loadProfile(userId: userId),
      child: _ProfileView(showSettings: userId == null),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView({required this.showSettings});

  final bool showSettings;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final ImagePicker _picker = ImagePicker();
  bool _isOpeningChat = false;

  Future<void> _pickAndUploadAvatar(ProfileEntity profile) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (!mounted || picked == null) return;
    final bytes = await picked.readAsBytes();
    await _uploadAvatar(bytes, p.extension(picked.path));
  }

  Future<void> _uploadAvatar(Uint8List bytes, String extension) async {
    final fileExtension = extension.replaceFirst('.', '');
    await context.read<ProfileCubit>().changeAvatar(
          bytes: bytes,
          fileExtension: fileExtension.isEmpty ? 'jpg' : fileExtension,
        );
  }

  Future<void> _promptUsername(ProfileEntity profile) async {
    final controller = TextEditingController(text: profile.username);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar nombre'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre de usuario',
              hintText: 'Ingresa tu nombre',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.of(context).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (!mounted || newName == null || newName == profile.username) return;

    await context.read<ProfileCubit>().updateUsername(newName);
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;
    final cubit = context.read<ProfileCubit>();
    await cubit.refreshProfile();
  }

  Future<void> _openChatThreads(ProfileEntity profile) async {
    final authUser = context.read<AuthBloc>().state.user;
    if (authUser == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Inicia sesión para ver tus colaboraciones.')),
        );
      return;
    }

    if (!profile.isCurrentUser) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadListPage(currentUserId: authUser.id),
      ),
    );
  }

  Future<void> _openConversation(ProfileEntity profile) async {
    final authBloc = context.read<AuthBloc>();
    final currentUser = authBloc.state.user;

    if (currentUser == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Inicia sesión para enviar mensajes.')),
        );
      return;
    }

    if (_isOpeningChat) {
      return;
    }

    setState(() {
      _isOpeningChat = true;
    });

    try {
      final threadId = await sl<CreateOrFetchThreadUseCase>()(
        currentUserId: currentUser.id,
        otherUserId: profile.id,
      );

      final participant = ChatParticipantEntity(
        id: profile.id,
        username: profile.username,
        email: profile.email,
        avatarUrl: profile.avatarUrl,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatConversationPage(
            threadId: threadId,
            currentUserId: currentUser.id,
            otherParticipant: participant,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('No se pudo abrir el chat: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningChat = false;
        });
      }
    }
  }

  void _openConnections(ProfileEntity profile, ProfileConnectionsType type) {
    final privacyMessage = _privacyBlockMessage(profile, type);
    if (privacyMessage != null) {
      _showInfoSnackBar(privacyMessage);
      return;
    }

    if (type == ProfileConnectionsType.favorites) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileFavoritesScreen(profile: profile),
        ),
      ).then((_) => _refreshProfile());
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<ProfileConnectionsCubit>(
          create: (_) =>
              sl<ProfileConnectionsCubit>()..loadConnections(profile.id, type),
          child: ProfileUserListScreen(
            type: type,
            profile: profile,
            onUserTap: (selectedProfile) async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(userId: selectedProfile.id),
                ),
              );
              if (!mounted) return;
              await _refreshProfile();
            },
          ),
        ),
      ),
    ).then((_) => _refreshProfile());
  }

  void _openPublishedBooks(ProfileEntity profile) {
    if (!profile.isCurrentUser && profile.privacy.booksPrivate) {
      _showInfoSnackBar('Este usuario mantiene sus libros en privado.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileBooksScreen(profile: profile),
      ),
    );
  }

  String? _privacyBlockMessage(
      ProfileEntity profile, ProfileConnectionsType type) {
    if (profile.isCurrentUser) {
      return null;
    }
    final privacy = profile.privacy;
    switch (type) {
      case ProfileConnectionsType.followers:
        return privacy.followersPrivate
            ? 'Este usuario mantiene sus seguidores en privado.'
            : null;
      case ProfileConnectionsType.following:
        return privacy.followingPrivate
            ? 'Este usuario mantiene a quienes sigue en privado.'
            : null;
      case ProfileConnectionsType.favorites:
        return privacy.favoritesPrivate
            ? 'Este usuario mantiene sus favoritos en privado.'
            : null;
    }
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (widget.showSettings)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileSettingsScreen(),
                  ),
                );
              },
            ),
          if (widget.showSettings) const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state.status == ProfileStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
          }
        },
        builder: (context, state) {
          if (state.status == ProfileStatus.loading ||
              (state.status == ProfileStatus.initial &&
                  state.profile == null)) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = state.profile;
          if (profile == null) {
            return const Center(child: Text('No pudimos cargar el perfil.'));
          }

          return RefreshIndicator(
            onRefresh: () => context.read<ProfileCubit>().loadProfile(
                  userId: profile.isCurrentUser ? null : profile.id,
                ),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                _ProfileHeader(
                  profile: profile,
                  onEditAvatar: profile.isCurrentUser
                      ? () => _pickAndUploadAvatar(profile)
                      : null,
                ),
                const SizedBox(height: 16),
                _ProfileNameSection(
                  profile: profile,
                  onEditName: profile.isCurrentUser
                      ? () => _promptUsername(profile)
                      : null,
                ),
                const SizedBox(height: 24),
                _ProfileStats(
                  profile: profile,
                  onFollowersTap: () => _openConnections(
                    profile,
                    ProfileConnectionsType.followers,
                  ),
                  onFollowingTap: () => _openConnections(
                    profile,
                    ProfileConnectionsType.following,
                  ),
                  onFavoritesTap: () => _openConnections(
                    profile,
                    ProfileConnectionsType.favorites,
                  ),
                  onBooksTap: () => _openPublishedBooks(profile),
                ),
                const SizedBox(height: 32),
                if (!profile.isCurrentUser) ...[
                  FilledButton.icon(
                    onPressed: () =>
                        context.read<ProfileCubit>().toggleFollow(profile),
                    icon: Icon(
                      profile.isFollowing ? Icons.check : Icons.person_add,
                    ),
                    label: Text(
                        profile.isFollowing ? 'Siguiendo' : 'Seguir autor'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isOpeningChat
                        ? null
                        : () => _openConversation(profile),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(
                      _isOpeningChat ? 'Abriendo chat...' : 'Enviar mensaje',
                    ),
                  ),
                ],
                if (profile.isCurrentUser) ...[
                  const Text(
                    'Acciones rápidas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        _ProfileActionTile(
                          icon: Icons.favorite_outline,
                          title: 'Ver favoritos',
                          onTap: () => _openConnections(
                            profile,
                            ProfileConnectionsType.favorites,
                          ),
                        ),
                        const Divider(height: 1),
                        _ProfileActionTile(
                          icon: Icons.book_outlined,
                          title: 'Mis libros publicados',
                          onTap: () => _openPublishedBooks(profile),
                        ),
                        const Divider(height: 1),
                        _ProfileActionTile(
                          icon: Icons.group_outlined,
                          title: 'Amigos y colaboraciones',
                          onTap: () => _openChatThreads(profile),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    this.onEditAvatar,
  });

  final ProfileEntity profile;
  final VoidCallback? onEditAvatar;

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 60,
        backgroundImage: NetworkImage(profile.avatarUrl!),
      );
    } else {
      avatar = CircleAvatar(
        radius: 60,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          profile.username.isNotEmpty
              ? profile.username.substring(0, 1).toUpperCase()
              : profile.email.substring(0, 1).toUpperCase(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            avatar,
            if (onEditAvatar != null)
              Material(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: onEditAvatar,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfileNameSection extends StatelessWidget {
  const _ProfileNameSection({
    required this.profile,
    this.onEditName,
  });

  final ProfileEntity profile;
  final VoidCallback? onEditName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profile.username,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (onEditName != null) ...[
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEditName,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          profile.email,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({
    required this.profile,
    required this.onFollowersTap,
    required this.onFollowingTap,
    required this.onFavoritesTap,
    required this.onBooksTap,
  });

  final ProfileEntity profile;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onBooksTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Seguidores',
                value: profile.followersCount,
                onTap: onFollowersTap,
              ),
            ),
            Expanded(
              child: _StatTile(
                label: 'Siguiendo',
                value: profile.followingCount,
                onTap: onFollowingTap,
              ),
            ),
            Expanded(
              child: _StatTile(
                label: 'Favoritos',
                value: profile.favoritesCount,
                onTap: onFavoritesTap,
              ),
            ),
            Expanded(
              child: _StatTile(
                label: 'Libros',
                value: profile.booksCount,
                onTap: onBooksTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
