import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/books/domain/entities/book_entity.dart';
import '../../features/books/domain/entities/book_search_sort.dart';
import '../../features/books/presentation/cubit/search_cubit.dart';
import '../../features/books/presentation/cubit/search_state.dart';
import '../../features/books/presentation/pages/book_detail_page.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  late final SearchCubit _cubit;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _cubit = sl<SearchCubit>();
    _searchController = TextEditingController();
    final user = context.read<AuthBloc>().state.user;
    _cubit.initialize(user: user);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider<SearchCubit>.value(
      value: _cubit,
      child: BlocConsumer<SearchCubit, SearchState>(
        listener: (context, state) {
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          final categories = ['Todas', ...state.categories];
          String? dropdownValue = state.selectedCategory;
          if (dropdownValue != null && !categories.contains(dropdownValue)) {
            categories.add(dropdownValue);
          }
          dropdownValue ??= categories.contains('Todas') ? 'Todas' : null;

          if (_searchController.text != state.query) {
            _searchController.value = _searchController.value.copyWith(
              text: state.query,
              selection: TextSelection.collapsed(offset: state.query.length),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explorar',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: context.read<SearchCubit>().updateQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Busca por titulo, autor o categoria',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: state.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () =>
                                context.read<SearchCubit>().clearSearch(),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: dropdownValue,
                            items: categories
                                .map(
                                  (category) => DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null || value == 'Todas') {
                                context
                                    .read<SearchCubit>()
                                    .changeCategory(null);
                                return;
                              }
                              context.read<SearchCubit>().changeCategory(value);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AvailableSorts(
                        selected: state.sort,
                        onSelected: context.read<SearchCubit>().changeSort,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _IAButton(
                    state: state, onPressed: () => _openAiAssistant(context)),
                const SizedBox(height: 16),
                Expanded(
                  child: _SearchResultsView(state: state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openAiAssistant(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: _cubit,
        child: const _AiSearchSheet(),
      ),
    );
  }
}

class _AvailableSorts extends StatelessWidget {
  const _AvailableSorts({
    required this.selected,
    required this.onSelected,
  });

  final BookSearchSort selected;
  final ValueChanged<BookSearchSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = BookSearchSort.values;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options
            .map(
              (option) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(option.label),
                  selected: selected == option,
                  onSelected: (_) => onSelected(option),
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: selected == option
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _IAButton extends StatelessWidget {
  const _IAButton({required this.state, required this.onPressed});

  final SearchState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = state.isGeminiAvailable;
    return Tooltip(
      message: enabled
          ? 'Describe lo que buscas y deja que la IA te sugiera libros.'
          : 'Configura GEMINI_API_KEY para habilitar la busqueda con IA.',
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Buscar con IA'),
      ),
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  const _SearchResultsView({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SearchStatus.initial:
        return const _PlaceholderMessage(
          'Te recomendamos buscar por titulo, autor o categoria.',
        );
      case SearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SearchStatus.failure:
        return const _PlaceholderMessage(
          'No se pudo completar la busqueda. Intenta nuevamente.',
        );
      case SearchStatus.empty:
        return const _PlaceholderMessage(
          'No encontramos libros con esos filtros. Prueba con otro termino.',
        );
      case SearchStatus.success:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isAiResult)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Resultados generados por IA'),
                  ],
                ),
              ),
            _buildList(state.results),
          ],
        );
    }
  }

  Widget _buildList(List<BookEntity> books) {
    return Expanded(
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _SearchResultTile(book: books[index]),
      ),
    );
  }
}

class _PlaceholderMessage extends StatelessWidget {
  const _PlaceholderMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.book});

  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookDetailPage(bookId: book.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookCoverThumbnail(path: book.coverPath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AUTOR: ${book.authorName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _RowInfo(
                          icon: Icons.category_rounded, label: book.category),
                      _RowInfo(
                          icon: Icons.visibility_rounded,
                          label: '${book.viewCount}'),
                      _RowInfo(
                          icon: Icons.favorite_rounded,
                          label: '${book.likeCount}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _RowInfo extends StatelessWidget {
  const _RowInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
        ),
      ],
    );
  }
}

class _BookCoverThumbnail extends StatelessWidget {
  const _BookCoverThumbnail({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 96,
        width: 72,
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (path == null || path!.isEmpty) {
      return Container(
        color: Colors.grey.shade800,
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book_rounded, color: Colors.white60),
      );
    }

    if (_looksLikeUrl(path!)) {
      return Image.network(
        path!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade800,
          alignment: Alignment.center,
          child: const Icon(Icons.menu_book_rounded, color: Colors.white60),
        ),
      );
    }

    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade800,
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book_rounded, color: Colors.white60),
      ),
    );
  }
}

bool _looksLikeUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

class _AiSearchSheet extends StatefulWidget {
  const _AiSearchSheet();

  @override
  State<_AiSearchSheet> createState() => _AiSearchSheetState();
}

class _AiSearchSheetState extends State<_AiSearchSheet> {
  late final TextEditingController _messageController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Asistente de busqueda',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: _AiMessageList(
                    messages: state.aiMessages,
                    scrollController: _scrollController,
                  ),
                ),
                if (state.isAiProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: state.isAiProcessing
                            ? null
                            : (_) => _sendMessage(context),
                        decoration: const InputDecoration(
                          labelText: 'Describe lo que buscas',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: state.isAiProcessing
                          ? null
                          : () => _sendMessage(context),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendMessage(BuildContext context) {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }
    context.read<SearchCubit>().sendAiPrompt(text);
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}

class _AiMessageList extends StatelessWidget {
  const _AiMessageList({
    required this.messages,
    required this.scrollController,
  });

  final List<SearchAiMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _PlaceholderMessage(
        'Pide recomendaciones basadas en tus favoritos, genero o cantidad de capitulos.',
      );
    }

    return ListView.separated(
      controller: scrollController,
      shrinkWrap: true,
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = messages[index];
        final alignment = message.role == SearchAiRole.user
            ? Alignment.centerRight
            : Alignment.centerLeft;
        final colorScheme = Theme.of(context).colorScheme;
        final color = message.role == SearchAiRole.user
            ? colorScheme.primary.withValues(alpha: 0.2)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message.content),
                    if (message.role == SearchAiRole.assistant &&
                        message.books.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: message.books
                              .map(
                                (book) => ActionChip(
                                  label: Text(book.title),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            BookDetailPage(bookId: book.id),
                                      ),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
