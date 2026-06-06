import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SavedEditedImage {
  final String label;
  final String path;
  final DateTime createdAt;

  const SavedEditedImage({
    required this.label,
    required this.path,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'path': path,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedEditedImage.fromJson(Map<String, dynamic> json) {
    return SavedEditedImage(
      label: json['label'] as String? ?? 'Sin nombre',
      path: json['path'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SavedImageStore {
  static final List<SavedEditedImage> _items = [];
  static bool _loaded = false;

  static List<SavedEditedImage> get items => List.unmodifiable(_items);

  static Future<Directory> getImagesDirectory() async {
    final Directory baseDirectory = await getApplicationDocumentsDirectory();
    final Directory imagesDirectory = Directory('${baseDirectory.path}/saved_images');

    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(recursive: true);
    }

    return imagesDirectory;
  }

  static Future<File> _metadataFile() async {
    final Directory baseDirectory = await getApplicationDocumentsDirectory();
    return File('${baseDirectory.path}/saved_images_history.json');
  }

  static Future<void> load() async {
    if (_loaded) return;

    final File file = await _metadataFile();
    if (!await file.exists()) {
      _loaded = true;
      return;
    }

    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        _items
          ..clear()
          ..addAll(
            decoded
                .whereType<Map>()
                .map((item) => SavedEditedImage.fromJson(
                      Map<String, dynamic>.from(item),
                    ))
                .where((item) => item.path.isNotEmpty),
          );
      }
    } catch (_) {
      // Si el historial se corrompe, no bloqueamos la app.
    }

    _loaded = true;
  }

  static Future<void> add(SavedEditedImage image) async {
    await load();
    _items.insert(0, image);
    await _save();
  }

  static Future<void> _save() async {
    final File file = await _metadataFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        _items.map((item) => item.toJson()).toList(),
      ),
    );
  }
}
