import 'package:equatable/equatable.dart';

import 'chapter_entity.dart';

class BookEntity extends Equatable {
  final String id;
  final String title;
  final String category;
  final String? description;
  final String? coverUrl;
  final String? coverBase64;
  final String authorId;
  final String authorName;
  final List<ChapterEntity> chapters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int publishedChapterOrder;
  final int likes;
  final int dislikes;
  final int views;

  const BookEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.authorId,
    required this.authorName,
    required this.chapters,
    required this.createdAt,
    required this.updatedAt,
    this.publishedChapterOrder = 0,
    this.description,
    this.coverUrl,
    this.coverBase64,
    this.likes = 0,
    this.dislikes = 0,
    this.views = 0,
  });

  BookEntity copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    String? coverUrl,
    String? coverBase64,
    String? authorId,
    String? authorName,
    List<ChapterEntity>? chapters,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? publishedChapterOrder,
    int? likes,
    int? dislikes,
    int? views,
  }) {
    return BookEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      coverBase64: coverBase64 ?? this.coverBase64,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      chapters: chapters ?? this.chapters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedChapterOrder:
          publishedChapterOrder ?? this.publishedChapterOrder,
  likes: likes ?? this.likes,
  dislikes: dislikes ?? this.dislikes,
  views: views ?? this.views,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        description,
        coverUrl,
        coverBase64,
        authorId,
        authorName,
        chapters,
        createdAt,
        updatedAt,
        publishedChapterOrder,
        likes,
        dislikes,
        views,
      ];
}
