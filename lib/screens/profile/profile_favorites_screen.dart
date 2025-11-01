import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wappa_app/core/di/injection.dart';
import 'package:wappa_app/features/books/domain/entities/book_entity.dart';
import 'package:wappa_app/features/profile/domain/entities/profile_entity.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_favorites_cubit.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_favorites_state.dart';
import 'package:wappa_app/features/books/presentation/pages/book_detail_page.dart';

class ProfileFavoritesScreen extends StatelessWidget {
  const ProfileFavoritesScreen({super.key, required this.profile});

  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileFavoritesCubit>(
      create: (_) => sl<ProfileFavoritesCubit>()..watchFavorites(profile.id),
      child: _FavoriteBooksView(profile: profile),
    );
  }
}

class _FavoriteBooksView extends StatelessWidget {
  const _FavoriteBooksView({required this.profile});

  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: BlocBuilder<ProfileFavoritesCubit, ProfileFavoritesState>(
        builder: (context, state) {
          switch (state.status) {
            case ProfileFavoritesStatus.initial:
            case ProfileFavoritesStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ProfileFavoritesStatus.error:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.errorMessage ??
                            'Hubo un problema al cargar los favoritos.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context
                            .read<ProfileFavoritesCubit>()
                            .watchFavorites(profile.id),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            case ProfileFavoritesStatus.loaded:
              if (state.books.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      profile.isCurrentUser
                          ? 'Marca libros como favoritos para verlos aquí.'
                          : 'Este usuario aún no tiene libros favoritos.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: state.books.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final BookEntity book = state.books[index];
                  return ListTile(
                    leading: _BookCoverThumbnail(path: book.coverPath),
                    title: Text(book.title),
                    subtitle: Text('Por ${book.authorName}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BookDetailPage(bookId: book.id),
                        ),
                      );
                      if (!context.mounted) return;
                      context
                          .read<ProfileFavoritesCubit>()
                          .watchFavorites(profile.id);
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

class _BookCoverThumbnail extends StatelessWidget {
  const _BookCoverThumbnail({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return const _PlaceholderCover();
    }

    if (_looksLikeUrl(path!)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          path!,
          width: 48,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _PlaceholderCover(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path!),
        width: 48,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PlaceholderCover(),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.menu_book_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

bool _looksLikeUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}
