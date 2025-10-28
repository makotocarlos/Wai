import 'package:equatable/equatable.dart';

class ChapterEntity extends Equatable {
  final String title;
  final String content;
  final int order;
  final bool isPublished;

  const ChapterEntity({
    required this.title,
    required this.content,
    required this.order,
    this.isPublished = false,
  });

  ChapterEntity copyWith({
    String? title,
    String? content,
    int? order,
    bool? isPublished,
  }) {
    return ChapterEntity(
      title: title ?? this.title,
      content: content ?? this.content,
      order: order ?? this.order,
      isPublished: isPublished ?? this.isPublished,
    );
  }

  @override
  List<Object?> get props => [title, content, order, isPublished];
}
