enum BookReaction {
	like,
	dislike,
	none,
}

extension BookReactionX on BookReaction {
	static BookReaction fromString(String? value) {
		switch (value) {
			case 'like':
				return BookReaction.like;
			case 'dislike':
				return BookReaction.dislike;
			default:
				return BookReaction.none;
		}
	}

	String? toNullableString() {
		switch (this) {
			case BookReaction.like:
				return 'like';
			case BookReaction.dislike:
				return 'dislike';
			case BookReaction.none:
				return null;
		}
	}
}
