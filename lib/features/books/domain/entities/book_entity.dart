import 'package:equatable/equatable.dart';

import 'chapter_entity.dart';

enum BookReactionType { like, dislike }

class BookEntity extends Equatable {
	const BookEntity({
		required this.id,
		required this.authorId,
		required this.authorName,
		required this.title,
		required this.category,
		required this.description,
		required this.createdAt,
		this.coverPath,
		this.chapters = const [],
		this.viewCount = 0,
		this.likeCount = 0,
		this.dislikeCount = 0,
		this.publishedChapterIndex = 0,
		this.userReaction,
		this.favoritesCount = 0,
		this.isFavorited = false,
	});

	final String id;
	final String authorId;
	final String authorName;
	final String title;
	final String category;
	final String description;
	final DateTime createdAt;
	final String? coverPath;
	final List<ChapterEntity> chapters;
	final int publishedChapterIndex;
	final int viewCount;
	final int likeCount;
	final int dislikeCount;
	final BookReactionType? userReaction;
	final int favoritesCount;
	final bool isFavorited;

	ChapterEntity? get currentChapter => chapters.isEmpty
			? null
			: chapters[publishedChapterIndex.clamp(0, chapters.length - 1)];

	BookEntity copyWith({
		String? id,
		String? authorId,
		String? authorName,
		String? title,
		String? category,
		String? description,
		DateTime? createdAt,
		String? coverPath,
		List<ChapterEntity>? chapters,
		int? publishedChapterIndex,
		int? viewCount,
		int? likeCount,
		int? dislikeCount,
		BookReactionType? userReaction,
		int? favoritesCount,
		bool? isFavorited,
	}) {
		return BookEntity(
			id: id ?? this.id,
			authorId: authorId ?? this.authorId,
			authorName: authorName ?? this.authorName,
			title: title ?? this.title,
			category: category ?? this.category,
			description: description ?? this.description,
			createdAt: createdAt ?? this.createdAt,
			coverPath: coverPath ?? this.coverPath,
			chapters: chapters ?? this.chapters,
			publishedChapterIndex:
					publishedChapterIndex ?? this.publishedChapterIndex,
			viewCount: viewCount ?? this.viewCount,
			likeCount: likeCount ?? this.likeCount,
			dislikeCount: dislikeCount ?? this.dislikeCount,
			userReaction: userReaction ?? this.userReaction,
			favoritesCount: favoritesCount ?? this.favoritesCount,
			isFavorited: isFavorited ?? this.isFavorited,
		);
	}

	@override
	List<Object?> get props => [
				id,
				authorId,
				authorName,
				title,
				category,
				description,
				createdAt,
				coverPath,
				chapters,
				publishedChapterIndex,
				viewCount,
				likeCount,
				dislikeCount,
				userReaction,
				favoritesCount,
				isFavorited,
			];
}
