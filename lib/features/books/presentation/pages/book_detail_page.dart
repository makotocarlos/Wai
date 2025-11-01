import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/books_repository.dart';
import '../../domain/usecases/add_comment.dart';
import '../../domain/usecases/add_view.dart';
import '../../domain/usecases/react_to_book.dart';
import '../../domain/usecases/reply_to_comment_usecase.dart';
import '../../domain/usecases/toggle_favorite.dart';
import '../../domain/usecases/watch_book.dart';
import '../../domain/usecases/watch_comments.dart';
import '../cubit/book_detail_cubit.dart';
import '../cubit/book_detail_state.dart';
import 'chapter_reader_page.dart';
import 'package:wappa_app/screens/profile/profile_screen.dart';

class BookDetailPage extends StatelessWidget {
	const BookDetailPage({super.key, required this.bookId});

	final String bookId;

	@override
	Widget build(BuildContext context) {
		final user = context.select((AuthBloc bloc) => bloc.state.user);

		if (user == null) {
			return Scaffold(
				appBar: AppBar(title: const Text('Detalle del libro')),
				body: const Center(
					child: Text('Debes iniciar sesion para ver los detalles.'),
				),
			);
		}

		return BlocProvider(
			create: (_) => BookDetailCubit(
				watchBook: sl<WatchBookUseCase>(),
				addView: sl<AddViewUseCase>(),
				reactToBook: sl<ReactToBookUseCase>(),
				addComment: sl<AddCommentUseCase>(),
				replyToComment: sl<ReplyToCommentUseCase>(),
				toggleFavorite: sl<ToggleFavoriteUseCase>(),
				watchComments: sl<WatchCommentsUseCase>(),
				repository: sl<BooksRepository>(),
				bookId: bookId,
				user: user,
			),
			child: const _BookDetailView(),
		);
	}
}

class _BookDetailView extends StatelessWidget {
	const _BookDetailView();

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: BlocBuilder<BookDetailCubit, BookDetailState>(
					builder: (context, state) {
						return Text(state.book?.title ?? 'Detalle del libro');
					},
				),
			),
			body: BlocBuilder<BookDetailCubit, BookDetailState>(
				builder: (context, state) {
					if (state.status == BookDetailStatus.loading) {
						return const Center(child: CircularProgressIndicator());
					}

					if (state.status == BookDetailStatus.failure) {
						return Center(
							child: Padding(
								padding: const EdgeInsets.all(24),
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										Text(
											state.errorMessage ?? 'Error al cargar el libro',
											textAlign: TextAlign.center,
										),
										const SizedBox(height: 16),
										ElevatedButton.icon(
											onPressed: () => Navigator.of(context).pop(),
											icon: const Icon(Icons.arrow_back),
											label: const Text('Volver'),
										),
									],
								),
							),
						);
					}

					final book = state.book;
					if (book == null) {
						return const Center(child: Text('Libro no encontrado'));
					}

					return SingleChildScrollView(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								_BookHeader(book: book),
								const SizedBox(height: 24),
								_BookMetrics(book: book),
								const SizedBox(height: 24),
								_BookDetails(book: book),
								const SizedBox(height: 32),
								_ChaptersList(book: book),
								const SizedBox(height: 32),
								_CommentsSection(
									bookId: book.id,
									comments: state.comments,
									isLoading: state.commentsLoading,
								),
								const SizedBox(height: 24),
							],
						),
					);
				},
			),
		);
	}
}

class _BookHeader extends StatelessWidget {
	const _BookHeader({required this.book});

	final BookEntity book;

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		return Padding(
			padding: const EdgeInsets.all(20),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					// Portada
					Container(
						width: 120,
						height: 180,
						decoration: BoxDecoration(
							color: theme.colorScheme.surface,
							borderRadius: BorderRadius.circular(12),
						),
						clipBehavior: Clip.antiAlias,
						child: _BookCover(path: book.coverPath),
					),
					const SizedBox(width: 16),
					// Información
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									book.title,
									style: theme.textTheme.headlineSmall?.copyWith(
										fontWeight: FontWeight.bold,
									),
								),
								const SizedBox(height: 8),
								Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Text(
											'Por ',
											style: theme.textTheme.bodyMedium?.copyWith(
												color: Colors.white70,
											),
										),
										InkWell(
											onTap: () => _openAuthorProfile(context),
											child: Text(
												book.authorName,
												style: theme.textTheme.bodyMedium?.copyWith(
													color: theme.colorScheme.primary,
													fontWeight: FontWeight.w600,
												),
											),
										),
									],
								),
								const SizedBox(height: 8),
								Container(
									padding: const EdgeInsets.symmetric(
										horizontal: 12,
										vertical: 4,
									),
									decoration: BoxDecoration(
										color: theme.colorScheme.primary,
										borderRadius: BorderRadius.circular(12),
									),
									child: Text(
										book.category,
										style: theme.textTheme.bodySmall?.copyWith(
											color: Colors.black,
											fontWeight: FontWeight.w600,
										),
									),
								),
								const SizedBox(height: 12),
								Text(
									book.description,
									style: theme.textTheme.bodyMedium,
									maxLines: 4,
									overflow: TextOverflow.ellipsis,
								),
							],
						),
					),
				],
			),
		);
	}

	void _openAuthorProfile(BuildContext context) {
		_navigateToProfile(context, book.authorId);
	}
}

class _BookMetrics extends StatelessWidget {
	const _BookMetrics({required this.book});

	final BookEntity book;

	@override
	Widget build(BuildContext context) {
		final cubit = context.read<BookDetailCubit>();

		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 20),
			child: Row(
				children: [
					_MetricButton(
						icon: Icons.thumb_up_outlined,
						selectedIcon: Icons.thumb_up,
						count: book.likeCount,
						isSelected: book.userReaction == BookReactionType.like,
						onTap: () => cubit.toggleReaction(BookReactionType.like),
					),
					const SizedBox(width: 16),
					_MetricButton(
						icon: Icons.thumb_down_outlined,
						selectedIcon: Icons.thumb_down,
						count: book.dislikeCount,
						isSelected: book.userReaction == BookReactionType.dislike,
						onTap: () => cubit.toggleReaction(BookReactionType.dislike),
					),
					const SizedBox(width: 16),
					_MetricButton(
						icon: Icons.visibility_outlined,
						selectedIcon: Icons.visibility_outlined,
						count: book.viewCount,
						isSelected: false,
						onTap: null,
					),
					const SizedBox(width: 16),
					_MetricButton(
						icon: Icons.outlined_flag,
						selectedIcon: Icons.flag,
						count: book.favoritesCount,
						isSelected: book.isFavorited,
						onTap: () => cubit.toggleFavorite(),
					),
				],
			),
		);
	}
}

class _MetricButton extends StatelessWidget {
	const _MetricButton({
		required this.icon,
		required this.selectedIcon,
		required this.count,
		required this.isSelected,
		this.onTap,
	});

	final IconData icon;
	final IconData selectedIcon;
	final int count;
	final bool isSelected;
	final VoidCallback? onTap;

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		return InkWell(
			onTap: onTap,
			borderRadius: BorderRadius.circular(20),
			child: Container(
				padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
				decoration: BoxDecoration(
					color: isSelected
						? theme.colorScheme.primary.withOpacity(0.2)
						: theme.colorScheme.surface,
					borderRadius: BorderRadius.circular(20),
					border: isSelected
						? Border.all(color: theme.colorScheme.primary, width: 2)
						: null,
				),
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(
							isSelected ? selectedIcon : icon,
							size: 20,
							color: isSelected ? theme.colorScheme.primary : Colors.white70,
						),
						const SizedBox(width: 8),
						Text(
							'$count',
							style: theme.textTheme.bodyMedium?.copyWith(
								color: isSelected ? theme.colorScheme.primary : Colors.white,
								fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
							),
						),
					],
				),
			),
		);
	}
}

class _BookDetails extends StatelessWidget {
	const _BookDetails({required this.book});

	final BookEntity book;

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final dateFormat = DateFormat('dd/MM/yyyy');

		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 20),
			child: Container(
				width: double.infinity,
				padding: const EdgeInsets.all(16),
				decoration: BoxDecoration(
					color: theme.colorScheme.surface,
					borderRadius: BorderRadius.circular(12),
					border: Border.all(
						color: theme.colorScheme.primary.withOpacity(0.3),
						width: 1,
					),
				),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(
							'Detalles del libro',
							style: theme.textTheme.titleMedium?.copyWith(
								fontWeight: FontWeight.bold,
							),
						),
						const SizedBox(height: 8),
						Text(
							'Publicado el ${dateFormat.format(book.createdAt)}',
							style: theme.textTheme.bodyMedium?.copyWith(
								color: Colors.white70,
							),
						),
					],
				),
			),
		);
	}
}

class _ChaptersList extends StatelessWidget {
	const _ChaptersList({required this.book});

	final BookEntity book;

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		// Usar publishedChapterIndex como fallback si is_published no está disponible
		final publishedChapters = book.chapters
			.where((chapter) => 
				chapter.isPublished || // Usar is_published si está disponible
				chapter.order <= book.publishedChapterIndex + 1 // Fallback al método antiguo
			)
			.toList();

		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 20),
					child: Text(
						'Capitulos',
						style: theme.textTheme.titleLarge?.copyWith(
							fontWeight: FontWeight.bold,
						),
					),
				),
				const SizedBox(height: 12),
				if (publishedChapters.isEmpty)
					Padding(
						padding: const EdgeInsets.all(20),
						child: Text(
							'No hay capitulos disponibles',
							style: theme.textTheme.bodyMedium?.copyWith(
								color: Colors.white70,
							),
						),
					)
				else
					ListView.separated(
						shrinkWrap: true,
						physics: const NeverScrollableScrollPhysics(),
						padding: const EdgeInsets.symmetric(horizontal: 20),
						itemCount: publishedChapters.length,
						separatorBuilder: (_, __) => const SizedBox(height: 8),
						itemBuilder: (context, index) {
							final chapter = publishedChapters[index];
							return InkWell(
								onTap: () {
									Navigator.of(context).push(
										MaterialPageRoute<void>(
											builder: (_) => ChapterReaderPage(
												book: book,
												initialChapterIndex: index,
											),
										),
									);
								},
								borderRadius: BorderRadius.circular(12),
								child: Container(
									padding: const EdgeInsets.all(16),
									decoration: BoxDecoration(
										color: theme.colorScheme.surface,
										borderRadius: BorderRadius.circular(12),
									),
									child: Row(
										children: [
											Expanded(
												child: Text(
													'Capitulo ${chapter.order}: ${chapter.title}',
													style: theme.textTheme.bodyLarge?.copyWith(
														fontWeight: FontWeight.w600,
													),
												),
											),
											Icon(
												Icons.chevron_right,
												color: theme.colorScheme.primary,
											),
										],
									),
								),
							);
						},
					),
			],
		);
	}
}

class _CommentsSection extends StatefulWidget {
	const _CommentsSection({
		required this.bookId,
		required this.comments,
		required this.isLoading,
	});

	final String bookId;
	final List<CommentEntity> comments;
	final bool isLoading;

	@override
	State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
	final _controller = TextEditingController();
	final _focusNode = FocusNode();
	bool _showAllComments = false; // Control para mostrar todos los comentarios

	@override
	void dispose() {
		_controller.dispose();
		_focusNode.dispose();
		super.dispose();
	}

	void _submitComment() {
		final text = _controller.text.trim();
		if (text.isEmpty) return;

		context.read<BookDetailCubit>().addComment(text);
		_controller.clear();
		_focusNode.unfocus();
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 20),
					child: Row(
						children: [
							Text(
								'Comentarios',
								style: theme.textTheme.titleLarge?.copyWith(
									fontWeight: FontWeight.bold,
								),
							),
							const SizedBox(width: 8),
							if (widget.isLoading)
								SizedBox(
									width: 16,
									height: 16,
									child: CircularProgressIndicator(
										strokeWidth: 2,
										valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
									),
								)
							else
								Text(
									'(${widget.comments.length})',
									style: theme.textTheme.titleMedium?.copyWith(
										color: Colors.white70,
									),
								),
						],
					),
				),
				const SizedBox(height: 16),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 20),
					child: Row(
						children: [
							Expanded(
								child: TextField(
									controller: _controller,
									focusNode: _focusNode,
									decoration: InputDecoration(
										hintText: 'Escribe un comentario...',
										filled: true,
										fillColor: theme.colorScheme.surface,
										border: OutlineInputBorder(
											borderRadius: BorderRadius.circular(24),
											borderSide: BorderSide.none,
										),
										contentPadding: const EdgeInsets.symmetric(
											horizontal: 20,
											vertical: 12,
										),
									),
									maxLines: null,
									textInputAction: TextInputAction.send,
									onSubmitted: (_) => _submitComment(),
								),
							),
							const SizedBox(width: 8),
							IconButton(
								onPressed: _submitComment,
								icon: Icon(
									Icons.send,
									color: theme.colorScheme.primary,
								),
							),
						],
					),
				),
				const SizedBox(height: 16),
				if (widget.isLoading)
					Padding(
						padding: const EdgeInsets.all(20),
						child: Center(
							child: CircularProgressIndicator(
								valueColor: AlwaysStoppedAnimation<Color>(
									theme.colorScheme.primary,
								),
							),
						),
					)
				else if (widget.comments.isEmpty)
					Padding(
						padding: const EdgeInsets.all(20),
						child: Text(
							'Aun no hay comentarios aqui. Se el primero en opinar.',
							style: theme.textTheme.bodyMedium?.copyWith(
								color: Colors.white70,
							),
							textAlign: TextAlign.center,
						),
					)
				else ...[
					// Mostrar solo el primer comentario o todos según el estado
					ListView.separated(
						shrinkWrap: true,
						physics: const NeverScrollableScrollPhysics(),
						padding: const EdgeInsets.symmetric(horizontal: 20),
						itemCount: _showAllComments ? widget.comments.length : 1,
						separatorBuilder: (_, __) => const SizedBox(height: 12),
						itemBuilder: (context, index) {
							final comment = widget.comments[index];
							return _CommentCard(comment: comment);
						},
					),
					// Botón "Ver más" si hay más de 1 comentario
					if (widget.comments.length > 1) ...[
						const SizedBox(height: 12),
						Center(
							child: TextButton.icon(
								onPressed: () {
									setState(() {
										_showAllComments = !_showAllComments;
									});
								},
								icon: Icon(
									_showAllComments 
										? Icons.expand_less 
										: Icons.expand_more,
									color: theme.colorScheme.primary,
								),
								label: Text(
									_showAllComments 
										? 'Ver menos' 
										: 'Ver todos los comentarios (${widget.comments.length})',
									style: TextStyle(
										color: theme.colorScheme.primary,
										fontWeight: FontWeight.w600,
									),
								),
							),
						),
					],
				],
			],
		);
	}
}

class _CommentCard extends StatefulWidget {
	const _CommentCard({required this.comment});

	final CommentEntity comment;

	@override
	State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
	bool _showReplyField = false;
	bool _showReplies = false;
	final _replyController = TextEditingController();

	@override
	void dispose() {
		_replyController.dispose();
		super.dispose();
	}

	void _toggleReplyField() {
		setState(() {
			_showReplyField = !_showReplyField;
			if (!_showReplyField) {
				_replyController.clear();
			}
		});
	}

	void _toggleReplies() {
		setState(() {
			_showReplies = !_showReplies;
		});
	}

	void _openCommentAuthorProfile() {
		_navigateToProfile(context, widget.comment.userId);
	}

	Future<void> _submitReply() async {
		final content = _replyController.text.trim();
		if (content.isEmpty) return;

		final cubit = context.read<BookDetailCubit>();
		await cubit.replyToComment(
			parentCommentId: widget.comment.id,
			content: content,
		);

		_replyController.clear();
		setState(() {
			_showReplyField = false;
			_showReplies = true; // Expandir para mostrar la nueva respuesta
		});
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final timeAgo = _formatTimeAgo(widget.comment.createdAt);

		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: theme.colorScheme.surface,
				borderRadius: BorderRadius.circular(12),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_UserAvatar(
								avatarUrl: widget.comment.userAvatarUrl,
								userName: widget.comment.userName,
								radius: 20,
							),
							const SizedBox(width: 12),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										InkWell(
											onTap: _openCommentAuthorProfile,
											child: Text(
												widget.comment.userName,
												style: theme.textTheme.bodyMedium?.copyWith(
													fontWeight: FontWeight.w600,
													color: theme.colorScheme.primary,
												),
											),
										),
										Text(
											timeAgo,
											style: theme.textTheme.bodySmall?.copyWith(
												color: Colors.white60,
											),
										),
										const SizedBox(height: 8),
										Text(
											widget.comment.content,
											style: theme.textTheme.bodyMedium,
										),
									],
								),
							),
							// Botón de like (corazón verde)
							Column(
								children: [
									IconButton(
										onPressed: () {
											context.read<BookDetailCubit>().toggleCommentLike(widget.comment.id);
										},
										icon: Icon(
											widget.comment.userHasLiked
												? Icons.favorite
												: Icons.favorite_border,
											color: widget.comment.userHasLiked
												? Colors.green
												: Colors.white60,
											size: 20,
										),
										padding: EdgeInsets.zero,
										constraints: const BoxConstraints(),
									),
									if (widget.comment.likeCount > 0)
										Text(
											'${widget.comment.likeCount}',
											style: theme.textTheme.labelSmall?.copyWith(
												color: Colors.white60,
											),
										),
								],
							),
						],
					),
					const SizedBox(height: 8),
					// Botones de acción
					Row(
						children: [
							// Botón "Responder"
							TextButton.icon(
								onPressed: _toggleReplyField,
								icon: Icon(
									_showReplyField ? Icons.close : Icons.reply,
									size: 16,
								),
								label: Text(_showReplyField ? 'Cancelar' : 'Responder'),
								style: TextButton.styleFrom(
									padding: const EdgeInsets.symmetric(horizontal: 8),
									minimumSize: const Size(0, 32),
									tapTargetSize: MaterialTapTargetSize.shrinkWrap,
								),
							),
							// Botón "Ver respuestas" (solo si tiene replies)
							if (widget.comment.hasReplies) ...[
								const SizedBox(width: 8),
								TextButton.icon(
									onPressed: _toggleReplies,
									icon: Icon(
										_showReplies ? Icons.expand_less : Icons.expand_more,
										size: 16,
									),
									label: Text(
										'${widget.comment.replyCount} respuesta${widget.comment.replyCount > 1 ? 's' : ''}',
									),
									style: TextButton.styleFrom(
										padding: const EdgeInsets.symmetric(horizontal: 8),
										minimumSize: const Size(0, 32),
										tapTargetSize: MaterialTapTargetSize.shrinkWrap,
									),
								),
							],
						],
					),
					// Campo para responder
					if (_showReplyField) ...[
						const SizedBox(height: 12),
						Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								_UserAvatar(
									avatarUrl: context.read<AuthBloc>().state.user?.avatarUrl,
									userName: context.read<AuthBloc>().state.user?.username ?? 'U',
									radius: 16,
								),
								const SizedBox(width: 8),
								Expanded(
									child: TextField(
										controller: _replyController,
										decoration: InputDecoration(
											hintText: 'Escribe una respuesta...',
											border: OutlineInputBorder(
												borderRadius: BorderRadius.circular(8),
											),
											contentPadding: const EdgeInsets.symmetric(
												horizontal: 12,
												vertical: 8,
											),
										),
										maxLines: 3,
										minLines: 1,
										textInputAction: TextInputAction.send,
										onSubmitted: (_) => _submitReply(),
									),
								),
								const SizedBox(width: 8),
								IconButton(
									onPressed: _submitReply,
									icon: const Icon(Icons.send),
									tooltip: 'Enviar respuesta',
								),
							],
						),
					],
					// Lista de respuestas
					if (_showReplies && widget.comment.replies.isNotEmpty) ...[
						const SizedBox(height: 12),
						Container(
							margin: const EdgeInsets.only(left: 32),
							padding: const EdgeInsets.only(left: 12),
							decoration: BoxDecoration(
								border: Border(
									left: BorderSide(
										color: theme.colorScheme.outline.withOpacity(0.3),
										width: 2,
									),
								),
							),
							child: Column(
								children: widget.comment.replies
									.map((reply) => Padding(
										padding: const EdgeInsets.only(bottom: 8),
										child: _ReplyCard(reply: reply),
									))
									.toList(),
							),
						),
					],
				],
			),
		);
	}

	String _formatTimeAgo(DateTime dateTime) {
		final now = DateTime.now();
		final difference = now.difference(dateTime);

		if (difference.inDays > 0) {
			return 'hace ${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
		} else if (difference.inHours > 0) {
			return 'hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
		} else if (difference.inMinutes > 0) {
			return 'hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
		} else {
			return 'hace un momento';
		}
	}
}

class _ReplyCard extends StatelessWidget {
	const _ReplyCard({required this.reply});

	final CommentEntity reply;

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final timeAgo = _formatTimeAgo(reply.createdAt);

		return Container(
			padding: const EdgeInsets.all(8),
			decoration: BoxDecoration(
				color: theme.colorScheme.surface.withOpacity(0.5),
				borderRadius: BorderRadius.circular(8),
			),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					_UserAvatar(
						avatarUrl: reply.userAvatarUrl,
						userName: reply.userName,
						radius: 16,
					),
					const SizedBox(width: 8),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Row(
									children: [
										InkWell(
											onTap: () => _navigateToProfile(context, reply.userId),
											child: Text(
												reply.userName,
												style: theme.textTheme.bodySmall?.copyWith(
													fontWeight: FontWeight.w600,
													color: theme.colorScheme.primary,
												),
											),
										),
										const SizedBox(width: 8),
										Text(
											timeAgo,
											style: theme.textTheme.bodySmall?.copyWith(
												color: Colors.white60,
												fontSize: 11,
											),
										),
									],
								),
								const SizedBox(height: 4),
								Text(
									reply.content,
									style: theme.textTheme.bodySmall,
								),
							],
						),
					),
					// Botón de like (corazón verde)
					Column(
						children: [
							IconButton(
								onPressed: () {
									context.read<BookDetailCubit>().toggleCommentLike(reply.id);
								},
								icon: Icon(
									reply.userHasLiked
										? Icons.favorite
										: Icons.favorite_border,
									color: reply.userHasLiked
										? Colors.green
										: Colors.white60,
									size: 16,
								),
								padding: EdgeInsets.zero,
								constraints: const BoxConstraints(),
							),
							if (reply.likeCount > 0)
								Text(
									'${reply.likeCount}',
									style: theme.textTheme.labelSmall?.copyWith(
										color: Colors.white60,
										fontSize: 10,
									),
								),
						],
					),
				],
			),
		);
	}

	String _formatTimeAgo(DateTime dateTime) {
		final now = DateTime.now();
		final difference = now.difference(dateTime);

		if (difference.inDays > 0) {
			return '${difference.inDays}d';
		} else if (difference.inHours > 0) {
			return '${difference.inHours}h';
		} else if (difference.inMinutes > 0) {
			return '${difference.inMinutes}m';
		} else {
			return 'ahora';
		}
	}
}

class _UserAvatar extends StatelessWidget {
	const _UserAvatar({
		required this.userName,
		this.avatarUrl,
		this.radius = 16,
	});

	final String? avatarUrl;
	final String userName;
	final double radius;

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

		if (avatarUrl != null && avatarUrl!.isNotEmpty) {
			return CircleAvatar(
				radius: radius,
				backgroundImage: NetworkImage(avatarUrl!),
				onBackgroundImageError: (_, __) {},
				child: Container(), // Evita mostrar el texto si la imagen carga
			);
		}

		return CircleAvatar(
			radius: radius,
			backgroundColor: theme.colorScheme.primary,
			child: Text(
				initial,
				style: TextStyle(
					color: Colors.black,
					fontWeight: FontWeight.bold,
					fontSize: radius * 0.6,
				),
			),
		);
	}
}

class _BookCover extends StatelessWidget {
	const _BookCover({this.path});

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
				size: 48,
				color: Colors.white60,
			),
		);
	}
}

void _navigateToProfile(BuildContext context, String userId) {
	if (userId.isEmpty) {
		return;
	}

	final currentUserId = context.read<AuthBloc>().state.user?.id;
	if (currentUserId != null && currentUserId == userId) {
		Navigator.of(context).push(
			MaterialPageRoute<void>(
				builder: (_) => const ProfileScreen(),
			),
		);
		return;
	}

	Navigator.of(context).push(
		MaterialPageRoute<void>(
			builder: (_) => ProfileScreen(userId: userId),
		),
	);
}

bool _looksLikeUrl(String value) {
	final uri = Uri.tryParse(value);
	return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

