import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/book_entity.dart';
import '../../domain/entities/chapter_entity.dart';

class BookModel extends BookEntity {
  BookModel({
    required super.id,
    required super.title,
    required super.category,
    required super.authorId,
    required super.authorName,
    required super.chapters,
    required super.createdAt,
    required super.updatedAt,
    required super.publishedChapterOrder,
    super.description,
    super.coverUrl,
    super.coverBase64,
    super.likes,
    super.dislikes,
    super.views,
  });

  factory BookModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final chaptersData =
        (data['chapters'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return BookModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Sin título',
      category: data['category'] as String? ?? 'General',
      description: data['description'] as String?,
      coverUrl: data['coverUrl'] as String?,
      coverBase64: data['coverBase64'] as String?,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Autor anónimo',
      chapters: chaptersData
          .map(
            (chapter) => ChapterEntity(
              title: chapter['title'] as String? ?? 'Capítulo',
              content: chapter['content'] as String? ?? '',
              order: chapter['order'] as int? ?? 0,
              isPublished: chapter['isPublished'] as bool? ?? false,
            ),
          )
          .toList(),
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
      publishedChapterOrder: data['publishedChapterOrder'] as int? ?? 0,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      dislikes: (data['dislikes'] as num?)?.toInt() ?? 0,
      views: (data['views'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'description': description,
      'coverUrl': coverUrl,
      'coverBase64': coverBase64,
      'authorId': authorId,
      'authorName': authorName,
      'chapters': chapters
          .map(
            (chapter) => {
              'title': chapter.title,
              'content': chapter.content,
              'order': chapter.order,
              'isPublished': chapter.isPublished,
            },
          )
          .toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'publishedChapterOrder': publishedChapterOrder,
      'likes': likes,
      'dislikes': dislikes,
      'views': views,
    };
  }

  static DateTime _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}
