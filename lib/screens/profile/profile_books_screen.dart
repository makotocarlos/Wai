import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wappa_app/core/di/injection.dart';
import 'package:wappa_app/features/books/domain/entities/book_entity.dart';
import 'package:wappa_app/features/books/presentation/pages/book_detail_page.dart';
import 'package:wappa_app/features/profile/domain/entities/profile_entity.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_books_cubit.dart';
import 'package:wappa_app/features/profile/presentation/cubit/profile_books_state.dart';

class ProfileBooksScreen extends StatelessWidget {
  const ProfileBooksScreen({super.key, required this.profile});

  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    final isLocked = !profile.isCurrentUser && profile.privacy.booksPrivate;
    if (isLocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Libros publicados')),
        body: const _LockedSectionMessage(
          message: 'Este usuario mantiene sus libros en privado.',
        ),
      );
    }

    return BlocProvider<ProfileBooksCubit>(
      create: (_) => sl<ProfileBooksCubit>()..watchAuthorBooks(profile.id),
      child: _ProfileBooksView(profile: profile),
    );
  }
}

class _ProfileBooksView extends StatelessWidget {
  const _ProfileBooksView({required this.profile});

  final ProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Libros publicados')),
      body: BlocBuilder<ProfileBooksCubit, ProfileBooksState>(
        builder: (context, state) {
          switch (state.status) {
            case ProfileBooksStatus.initial:
            case ProfileBooksStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ProfileBooksStatus.error:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.errorMessage ??
                            'Hubo un problema al cargar los libros publicados.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context
                            .read<ProfileBooksCubit>()
                            .watchAuthorBooks(profile.id),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            case ProfileBooksStatus.loaded:
              if (state.books.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      profile.isCurrentUser
                          ? 'Aun no tienes libros publicados.'
                          : 'Este usuario aun no tiene libros publicados.',
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
                          .read<ProfileBooksCubit>()
                          .watchAuthorBooks(profile.id);
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

class _LockedSectionMessage extends StatelessWidget {
  const _LockedSectionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
