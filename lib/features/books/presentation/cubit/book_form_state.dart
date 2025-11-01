import 'package:equatable/equatable.dart';

class ChapterDraftState extends Equatable {
	const ChapterDraftState({
		required this.id,
		required this.order,
		this.title = '',
		this.content = '',
		this.isPublished = false,
	});

	final String id;
	final int order;
	final String title;
	final String content;
	final bool isPublished;

	ChapterDraftState copyWith({
		String? id,
		int? order,
		String? title,
		String? content,
		bool? isPublished,
	}) {
		return ChapterDraftState(
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

enum BookFormStatus { idle, submitting, success, failure }

class BookFormState extends Equatable {
	const BookFormState({
		this.title = '',
		this.category = 'Fantasia',
		this.description = '',
		this.coverPath,
		this.chapters = const [ChapterDraftState(id: 'chapter_1', order: 1)],
		this.publishIndex = 0,
		this.status = BookFormStatus.idle,
		this.errorMessage,
	});

	final String title;
	final String category;
	final String description;
	final String? coverPath;
	final List<ChapterDraftState> chapters;
	final int publishIndex;
	final BookFormStatus status;
	final String? errorMessage;

	BookFormState copyWith({
		String? title,
		String? category,
		String? description,
		String? coverPath,
		List<ChapterDraftState>? chapters,
		int? publishIndex,
		BookFormStatus? status,
		String? errorMessage,
		bool clearError = false,
	}) {
		return BookFormState(
			title: title ?? this.title,
			category: category ?? this.category,
			description: description ?? this.description,
			coverPath: coverPath ?? this.coverPath,
			chapters: chapters ?? this.chapters,
			publishIndex: publishIndex ?? this.publishIndex,
			status: status ?? this.status,
			errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
		);
	}

	@override
	List<Object?> get props => [
				title,
				category,
				description,
				coverPath,
				chapters,
				publishIndex,
				status,
				errorMessage,
			];
}
