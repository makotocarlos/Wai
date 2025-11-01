import 'package:equatable/equatable.dart';

class ChapterEntity extends Equatable {
	const ChapterEntity({
		required this.id,
		required this.order,
		required this.title,
		required this.content,
		this.isPublished = false,
	});

	final String id;
	final int order;
	final String title;
	final String content;
	final bool isPublished;

	ChapterEntity copyWith({
		String? id,
		int? order,
		String? title,
		String? content,
		bool? isPublished,
	}) {
		return ChapterEntity(
			id: id ?? this.id,
			order: order ?? this.order,
			title: title ?? this.title,
			content: content ?? this.content,
			isPublished: isPublished ?? this.isPublished,
		);
	}

	@override
	List<Object?> get props => [id, order, title, content, isPublished];
}
