import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wappa_app/features/profile/domain/entities/profile_entity.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_connections_cubit.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_connections_state.dart';

class ProfileUserListScreen extends StatelessWidget {
  const ProfileUserListScreen({
    super.key,
    required this.type,
    required this.profile,
    this.onUserTap,
  });

  final ProfileConnectionsType type;
  final ProfileEntity profile;
  final Future<void> Function(ProfileEntity)? onUserTap;

  String get _title {
    switch (type) {
      case ProfileConnectionsType.followers:
        return 'Seguidores';
      case ProfileConnectionsType.following:
        return 'Siguiendo';
      case ProfileConnectionsType.favorites:
        return 'Favoritos';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: BlocBuilder<ProfileConnectionsCubit, ProfileConnectionsState>(
        builder: (context, state) {
          switch (state.status) {
            case ProfileConnectionsStatus.initial:
            case ProfileConnectionsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ProfileConnectionsStatus.error:
              return Center(
                child: Text(
                    state.errorMessage ?? 'Hubo un error al cargar la lista.'),
              );
            case ProfileConnectionsStatus.loaded:
              if (state.profiles.isEmpty) {
                return Center(
                    child: Text(
                        'Aquí aparecerán las conexiones de ${profile.username}.'));
              }
              return ListView.separated(
                itemCount: state.profiles.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = state.profiles[index];
          return ListTile(
          leading:
            _Avatar(url: item.avatarUrl, fallback: item.username),
          title: Text(item.username),
          subtitle: Text(item.email),
          onTap: onUserTap == null
            ? null
            : () async {
              await onUserTap!(item);
              if (!context.mounted) return;
              context
                .read<ProfileConnectionsCubit>()
                .loadConnections(profile.id, type);
              },
          );
                },
              );
          }
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback});

  final String? url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(url!));
    }

    return CircleAvatar(
      child: Text(
        fallback.isNotEmpty ? fallback[0].toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
