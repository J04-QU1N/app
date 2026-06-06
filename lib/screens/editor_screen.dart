import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'crop_image_screen.dart';

class EditorScreen extends StatefulWidget {
  final String imagePath;

  const EditorScreen({super.key, required this.imagePath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool isPanelOpen = true;
  late String selectedImagePath;

  final List<LashElement> lashes = [];
  int? selectedLashId;
  bool isEditMenuOpen = false;
  LashEditMode lashEditMode = LashEditMode.move;

  int? _gestureLashId;
  Offset _gestureStartPosition = Offset.zero;
  double _gestureStartScale = 1;
  double _gestureStartRotation = 0;
  double _gestureStartStretchX = 1;
  double _gestureStartStretchY = 1;

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
    if (!mounted) return;

    final String? croppedImagePath = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CropImageScreen(
          imagePath: image.path,
        ),
      ),
    );

    if (croppedImagePath == null) return;

    setState(() {
      /// Se reemplaza la imagen base. No se acumulan varias fotos.
      selectedImagePath = croppedImagePath;
      selectedLashId = null;
      isEditMenuOpen = false;
      lashEditMode = LashEditMode.move;
    });
  }

  void addLash(String imagePath) {
    final int id = DateTime.now().microsecondsSinceEpoch;

    setState(() {
      lashes.add(
        LashElement(
          id: id,
          imagePath: imagePath,
          position: const Offset(90, 220),
        ),
      );
      selectedLashId = id;
      isEditMenuOpen = false;
      lashEditMode = LashEditMode.move;
    });
  }

  void selectLash(int id) {
    setState(() {
      selectedLashId = id;
      isEditMenuOpen = false;
      lashEditMode = LashEditMode.move;
    });
  }

  void closeBottomMenus() {
    if (selectedLashId == null && !isEditMenuOpen) return;

    setState(() {
      selectedLashId = null;
      isEditMenuOpen = false;
      lashEditMode = LashEditMode.move;
    });
  }

  void deleteSelectedLash() {
    final int? id = selectedLashId;
    if (id == null) return;

    setState(() {
      lashes.removeWhere((element) => element.id == id);
      selectedLashId = null;
      isEditMenuOpen = false;
      lashEditMode = LashEditMode.move;
    });
  }

  void duplicateSelectedLash() {
    final LashElement? selected = getSelectedLash();
    if (selected == null) return;

    final LashElement duplicated = selected.copyWith(
      id: DateTime.now().microsecondsSinceEpoch,
      position: selected.position + const Offset(24, 24),
    );

    setState(() {
      lashes.add(duplicated);
      selectedLashId = duplicated.id;
      isEditMenuOpen = false;
      lashEditMode = LashEditMode.move;
    });
  }

  LashElement? getSelectedLash() {
    final int? id = selectedLashId;
    if (id == null) return null;

    for (final LashElement lash in lashes) {
      if (lash.id == id) return lash;
    }

    return null;
  }

  void updateSelectedLash(LashElement Function(LashElement lash) update) {
    final int? id = selectedLashId;
    if (id == null) return;

    final int index = lashes.indexWhere((element) => element.id == id);
    if (index == -1) return;

    setState(() {
      lashes[index] = update(lashes[index]);
    });
  }

  void startLashGesture(int id, ScaleStartDetails details) {
    final int index = lashes.indexWhere((element) => element.id == id);
    if (index == -1) return;

    final LashElement lash = lashes[index];

    setState(() {
      selectedLashId = id;
    });

    _gestureLashId = id;
    _gestureStartPosition = lash.position;
    _gestureStartScale = lash.scale;
    _gestureStartRotation = lash.rotation;
    _gestureStartStretchX = lash.stretchX;
    _gestureStartStretchY = lash.stretchY;
  }

  void updateLashGesture(int id, ScaleUpdateDetails details) {
    if (_gestureLashId != id) return;

    final int index = lashes.indexWhere((element) => element.id == id);
    if (index == -1) return;

    final LashElement current = lashes[index];
    LashElement updated;

    switch (lashEditMode) {
      case LashEditMode.move:
        updated = current.copyWith(
          position: current.position + details.focalPointDelta,
        );
        break;
      case LashEditMode.resize:
        updated = current.copyWith(
          scale: (_gestureStartScale * details.scale).clamp(0.15, 5).toDouble(),
        );
        break;
      case LashEditMode.rotate:
        updated = current.copyWith(
          position: current.position + details.focalPointDelta,
          rotation: _gestureStartRotation + details.rotation,
        );
        break;
      case LashEditMode.stretch:
        updated = current.copyWith(
          stretchX: (_gestureStartStretchX * details.horizontalScale)
              .clamp(0.25, 4)
              .toDouble(),
          stretchY: (_gestureStartStretchY * details.verticalScale)
              .clamp(0.25, 4)
              .toDouble(),
        );
        break;
    }

    setState(() {
      lashes[index] = updated;
    });
  }

  void finishLashGesture(int id) {
    if (_gestureLashId == id) {
      _gestureLashId = null;
    }
  }

  String currentEditModeLabel() {
    switch (lashEditMode) {
      case LashEditMode.move:
        return 'Mover';
      case LashEditMode.resize:
        return 'Redimensionar';
      case LashEditMode.rotate:
        return 'Rotar';
      case LashEditMode.stretch:
        return 'Estirar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelectedLash = selectedLashId != null;

    return Scaffold(
      body: Stack(
        children: [
          /// AREA EDITOR (FOTO SELECCIONADA)
          Positioned.fill(
            child: DragTarget<String>(
              onAccept: addLash,
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: closeBottomMenus,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(selectedImagePath),
                        fit: BoxFit.cover,
                      ),
                      ...lashes.map(
                        (lash) => EditableLashWidget(
                          lash: lash,
                          isSelected: selectedLashId == lash.id,
                          editMode: selectedLashId == lash.id
                              ? lashEditMode
                              : LashEditMode.move,
                          onTap: () => selectLash(lash.id),
                          onScaleStart: (details) =>
                              startLashGesture(lash.id, details),
                          onScaleUpdate: (details) =>
                              updateLashGesture(lash.id, details),
                          onScaleEnd: (_) => finishLashGesture(lash.id),
                        ),
                      ),
                    ],
                  ),
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
                          buildDraggableItem('assets/lashes/lash1.png'),
                          buildDraggableItem('assets/lashes/lash2.png'),
                          buildDraggableItem('assets/lashes/lash3.png'),
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

          /// MENU INFERIOR DEL ELEMENTO SELECCIONADO
          if (hasSelectedLash)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.all(12),
                child: isEditMenuOpen
                    ? buildTransformMenu()
                    : buildMainElementMenu(),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildMainElementMenu() {
    return BottomEditorMenu(
      children: [
        MenuIconButton(
          icon: Icons.edit,
          label: 'Editar',
          onPressed: () {
            setState(() {
              isEditMenuOpen = true;
              lashEditMode = LashEditMode.move;
            });
          },
        ),
        MenuIconButton(
          icon: Icons.copy,
          label: 'Duplicar',
          onPressed: duplicateSelectedLash,
        ),
        MenuIconButton(
          icon: Icons.delete,
          label: 'Borrar',
          onPressed: deleteSelectedLash,
        ),
      ],
    );
  }

  Widget buildTransformMenu() {
    return BottomEditorMenu(
      children: [
        MenuIconButton(
          icon: Icons.arrow_back,
          label: 'Volver',
          onPressed: () {
            setState(() {
              isEditMenuOpen = false;
              lashEditMode = LashEditMode.move;
            });
          },
        ),
        MenuIconButton(
          icon: Icons.zoom_out_map,
          label: 'Redimensionar',
          isSelected: lashEditMode == LashEditMode.resize,
          onPressed: () {
            setState(() {
              lashEditMode = LashEditMode.resize;
            });
          },
        ),
        MenuIconButton(
          icon: Icons.rotate_right,
          label: 'Rotar',
          isSelected: lashEditMode == LashEditMode.rotate,
          onPressed: () {
            setState(() {
              lashEditMode = LashEditMode.rotate;
            });
          },
        ),
        MenuIconButton(
          icon: Icons.swap_horiz,
          label: 'Estirar',
          isSelected: lashEditMode == LashEditMode.stretch,
          onPressed: () {
            setState(() {
              lashEditMode = LashEditMode.stretch;
            });
          },
        ),
        MenuIconButton(
          icon: Icons.flip,
          label: 'Espejar',
          onPressed: () {
            updateSelectedLash(
              (lash) => lash.copyWith(
                isMirrored: !lash.isMirrored,
              ),
            );
          },
        ),
      ],
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

enum LashEditMode {
  move,
  resize,
  rotate,
  stretch,
}

class LashElement {
  final int id;
  final String imagePath;
  final Offset position;
  final double scale;
  final double rotation;
  final double stretchX;
  final double stretchY;
  final bool isMirrored;

  const LashElement({
    required this.id,
    required this.imagePath,
    required this.position,
    this.scale = 1,
    this.rotation = 0,
    this.stretchX = 1,
    this.stretchY = 1,
    this.isMirrored = false,
  });

  LashElement copyWith({
    int? id,
    String? imagePath,
    Offset? position,
    double? scale,
    double? rotation,
    double? stretchX,
    double? stretchY,
    bool? isMirrored,
  }) {
    return LashElement(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      stretchX: stretchX ?? this.stretchX,
      stretchY: stretchY ?? this.stretchY,
      isMirrored: isMirrored ?? this.isMirrored,
    );
  }
}

class EditableLashWidget extends StatelessWidget {
  static const double baseWidth = 200;

  final LashElement lash;
  final bool isSelected;
  final LashEditMode editMode;
  final VoidCallback onTap;
  final ValueChanged<ScaleStartDetails> onScaleStart;
  final ValueChanged<ScaleUpdateDetails> onScaleUpdate;
  final ValueChanged<ScaleEndDetails> onScaleEnd;

  const EditableLashWidget({
    super.key,
    required this.lash,
    required this.isSelected,
    required this.editMode,
    required this.onTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
  });

  @override
  Widget build(BuildContext context) {
    String hintText;
    switch (editMode) {
      case LashEditMode.resize:
        hintText = 'Pellizcá para redimensionar';
        break;
      case LashEditMode.rotate:
        hintText = 'Usá dos dedos para rotar';
        break;
      case LashEditMode.stretch:
        hintText = 'Separá los dedos horizontal o verticalmente';
        break;
      case LashEditMode.move:
        hintText = 'Arrastrá para mover';
        break;
    }

    return Positioned(
      left: lash.position.dx,
      top: lash.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        onScaleEnd: onScaleEnd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: lash.rotation,
              child: Transform.scale(
                scaleX: (lash.isMirrored ? -1 : 1) * lash.scale * lash.stretchX,
                scaleY: lash.scale * lash.stretchY,
                child: Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        )
                      : null,
                  child: Image.asset(
                    lash.imagePath,
                    width: baseWidth,
                  ),
                ),
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hintText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BottomEditorMenu extends StatelessWidget {
  final List<Widget> children;

  const BottomEditorMenu({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: child,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class MenuIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isSelected;

  const MenuIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? Colors.white24 : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
