enum BookSearchSort {
  recent,
  mostViewed,
  mostLiked,
}

extension BookSearchSortX on BookSearchSort {
  String get label {
    switch (this) {
      case BookSearchSort.recent:
        return 'Mas recientes';
      case BookSearchSort.mostViewed:
        return 'Mas vistos';
      case BookSearchSort.mostLiked:
        return 'Mas gustados';
    }
  }
}
