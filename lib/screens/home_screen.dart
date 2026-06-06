import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> pickImage(
      BuildContext context, ImageSource source) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: source,
    );

    if (image != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Text(
              "LashVision",
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 60),

            ElevatedButton(
              onPressed: () {
                pickImage(context, ImageSource.camera);
              },
              child: Text("Take Photo"),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                pickImage(context, ImageSource.gallery);
              },
              child: Text("Upload Photo"),
            ),
          ],
        ),
      ),
    );
  }
}
