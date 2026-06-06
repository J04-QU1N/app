import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LashVisionApp());
}

class LashVisionApp extends StatelessWidget {
  const LashVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LashVision',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

