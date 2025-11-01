import 'package:equatable/equatable.dart';

import 'book_entity.dart';

class BookReaction extends Equatable {
	const BookReaction({
		required this.userId,
		required this.type,
	});

	final String userId;
	final BookReactionType type;

	@override
	List<Object?> get props => [userId, type];
}
