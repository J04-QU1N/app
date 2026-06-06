import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool isPanelOpen = true;
  List<Widget> lashes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// AREA EDITOR (CARA)
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
                  children: [
                    Image.asset(
                      "assets/sample_face.jpg",
                      fit: BoxFit.cover,
                    ),
                    ...lashes,
                  ],
                );
              },
            ),
          ),

          /// PANEL LATERAL DESPLEGABLE
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
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

  LashDraggable({required this.imagePath});

  @override
  _LashDraggableState createState() => _LashDraggableState();
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