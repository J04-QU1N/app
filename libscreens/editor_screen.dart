import 'dart:io';
import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  final String imagePath;

  const EditorScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool isPanelOpen = true;
  final List<Widget> lashes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: DragTarget<String>(
              onAcceptWithDetails: (details) {
                setState(() {
                  lashes.add(
                    LashDraggable(imagePath: details.data),
                  );
                });
              },
              builder: (context, candidateData, rejectedData) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                    ...lashes,
                  ],
                );
              },
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            right: isPanelOpen ? 0 : -130,
            top: 0,
            bottom: 0,
            child: Container(
              width: 130,
              color: Colors.black87,
              child: Column(
                children: [
                  const SizedBox(height: 45),

                  IconButton(
                    icon: Icon(
                      isPanelOpen ? Icons.arrow_forward : Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        isPanelOpen = !isPanelOpen;
                      });
                    },
                  ),

                  const Text(
                    "Designs",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: ListView(
                      children: [
                        buildDraggableItem("assets/lashes/lash1.png", "Classic"),
                        buildDraggableItem("assets/lashes/lash2.png", "Volume"),
                        buildDraggableItem("assets/lashes/lash3.png", "Cat Eye"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDraggableItem(String imagePath, String name) {
    return Draggable<String>(
      data: imagePath,
      feedback: Material(
        color: Colors.transparent,
        child: Image.asset(
          imagePath,
          width: 100,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: lashMenuItem(imagePath, name),
      ),
      child: lashMenuItem(imagePath, name),
    );
  }

  Widget lashMenuItem(String imagePath, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        children: [
          Image.asset(
            imagePath,
            width: 95,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class LashDraggable extends StatefulWidget {
  final String imagePath;

  const LashDraggable({
    super.key,
    required this.imagePath,
  });

  @override
  State<LashDraggable> createState() => _LashDraggableState();
}

class _LashDraggableState extends State<LashDraggable> {
  Offset position = Offset.zero;
  Offset initialFocalPoint = Offset.zero;
  Offset initialPosition = Offset.zero;

  double scale = 1.0;
  double initialScale = 1.0;

  double rotation = 0.0;
  double initialRotation = 0.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: MediaQuery.of(context).size.width / 3 + position.dx,
      top: MediaQuery.of(context).size.height / 3 + position.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          initialFocalPoint = details.focalPoint;
          initialPosition = position;
          initialScale = scale;
          initialRotation = rotation;
        },
        onScaleUpdate: (details) {
          setState(() {
            position =
                initialPosition + (details.focalPoint - initialFocalPoint);

            scale = initialScale * details.scale;
            rotation = initialRotation + details.rotation;
          });
        },
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              widget.imagePath,
              width: 200,
            ),
          ),
        ),
      ),
    );
  }
}