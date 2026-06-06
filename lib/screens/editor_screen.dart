import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditorScreen extends StatefulWidget {
  final String imagePath;

  const EditorScreen({super.key, required this.imagePath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool isPanelOpen = true;
  List<Widget> lashes = [];
  late String selectedImagePath;

  @override
  void initState() {
    super.initState();
    selectedImagePath = widget.imagePath;
  }

  Future<void> replaceImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: source,
    );

    if (image == null) return;

    setState(() {
      /// Se reemplaza la imagen base. No se acumulan varias fotos.
      selectedImagePath = image.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// AREA EDITOR (FOTO SELECCIONADA)
          Positioned.fill(
            child: DragTarget<String>(
              onAccept: (imagePath) {
                setState(() {
                  lashes.add(
                    LashDraggable(imagePath: imagePath),
                  );
                });
              },
              builder: (context, candidateData, rejectedData) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(selectedImagePath),
                      fit: BoxFit.cover,
                    ),
                    ...lashes,
                  ],
                );
              },
            ),
          ),

          /// BOTONES PARA REEMPLAZAR LA FOTO BASE
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 12,
            child: Column(
              children: [
                Material(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(24),
                  child: IconButton(
                    tooltip: 'Reemplazar con cámara',
                    icon: const Icon(
                      Icons.photo_camera,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      replaceImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(24),
                  child: IconButton(
                    tooltip: 'Reemplazar desde galería',
                    icon: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      replaceImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
          ),

          /// PANEL LATERAL DESPLEGABLE
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: isPanelOpen ? 0 : -120,
            top: 0,
            bottom: 0,
            child: Container(
              width: 120,
              color: Colors.black87,
              child: SafeArea(
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          isPanelOpen = false;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    Expanded(
                      child: ListView(
                        children: [
                          buildDraggableItem("assets/lashes/lash1.png"),
                          buildDraggableItem("assets/lashes/lash2.png"),
                          buildDraggableItem("assets/lashes/lash3.png"),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),

          /// BOTON PARA VOLVER A ABRIR EL PANEL
          if (!isPanelOpen)
            Positioned(
              left: 12,
              top: MediaQuery.of(context).padding.top + 12,
              child: Material(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
                child: IconButton(
                  icon: const Icon(
                    Icons.menu,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      isPanelOpen = true;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildDraggableItem(String imagePath) {
    return Draggable<String>(
      data: imagePath,
      feedback: Image.asset(imagePath, width: 80),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Image.asset(imagePath, width: 80),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(imagePath, width: 80),
      ),
    );
  }
}

/// =============================
/// WIDGET DE PESTAÑA EDITABLE
/// =============================

class LashDraggable extends StatefulWidget {
  final String imagePath;

  const LashDraggable({super.key, required this.imagePath});

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
      left: MediaQuery.of(context).size.width / 4 + position.dx,
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
