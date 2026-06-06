import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'crop_image_screen.dart';
import 'editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> pickImage(
    BuildContext context,
    ImageSource source,
  ) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: source,
    );

    if (image == null) return;
    if (!context.mounted) return;

    final String? croppedImagePath = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CropImageScreen(
          imagePath: image.path,
        ),
      ),
    );

    if (croppedImagePath == null) return;
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          imagePath: croppedImagePath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "LashVision",
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () {
                pickImage(context, ImageSource.camera);
              },
              child: const Text("Take Photo"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                pickImage(context, ImageSource.gallery);
              },
              child: const Text("Upload Photo"),
            ),
          ],
        ),
      ),
    );
  }
}
