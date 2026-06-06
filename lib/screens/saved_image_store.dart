class SavedEditedImage {
  final String label;
  final String path;
  final DateTime createdAt;

  const SavedEditedImage({
    required this.label,
    required this.path,
    required this.createdAt,
  });
}

class SavedImageStore {
  static final List<SavedEditedImage> _items = [];

  static List<SavedEditedImage> get items => List.unmodifiable(_items);

  static void add(SavedEditedImage image) {
    _items.insert(0, image);
  }
}
