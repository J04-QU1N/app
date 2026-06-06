import 'dart:io';
import 'dart:math' as math;

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
    });
  }

  void addLash(String imagePath) {
    setState(() {
      lashes.add(
        LashElement(
          id: DateTime.now().microsecondsSinceEpoch,
          imagePath: imagePath,
          position: const Offset(90, 220),
        ),
      );
    });
  }

  void selectLash(int id) {
    setState(() {
      selectedLashId = id;
      isEditMenuOpen = false;
    });
  }

  void closeBottomMenus() {
    if (selectedLashId == null && !isEditMenuOpen) return;

    setState(() {
      selectedLashId = null;
      isEditMenuOpen = false;
    });
  }

  void moveSelectedLash(int id, DragUpdateDetails details) {
    final int index = lashes.indexWhere((element) => element.id == id);
    if (index == -1) return;

    setState(() {
      lashes[index] = lashes[index].copyWith(
        position: lashes[index].position + details.delta,
      );
    });
  }

  void deleteSelectedLash() {
    final int? id = selectedLashId;
    if (id == null) return;

    setState(() {
      lashes.removeWhere((element) => element.id == id);
      selectedLashId = null;
      isEditMenuOpen = false;
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
                          onTap: () => selectLash(lash.id),
                          onPanUpdate: (details) =>
                              moveSelectedLash(lash.id, details),
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
            });
          },
        ),
        MenuIconButton(
          icon: Icons.zoom_out_map,
          label: 'Achicar',
          onPressed: () {
            updateSelectedLash(
              (lash) => lash.copyWith(
                scale: math.max(0.2, lash.scale - 0.1),
              ),
            );
          },
        ),
        MenuIconButton(
          icon: Icons.open_in_full,
          label: 'Agrandar',
          onPressed: () {
            updateSelectedLash(
              (lash) => lash.copyWith(
                scale: math.min(4, lash.scale + 0.1),
              ),
            );
          },
        ),
        MenuIconButton(
          icon: Icons.rotate_left,
          label: 'Rotar -',
          onPressed: () {
            updateSelectedLash(
              (lash) => lash.copyWith(
                rotation: lash.rotation - 0.12,
              ),
            );
          },
        ),
        MenuIconButton(
          icon: Icons.rotate_right,
          label: 'Rotar +',
          onPressed: () {
            updateSelectedLash(
              (lash) => lash.copyWith(
                rotation: lash.rotation + 0.12,
              ),
            );
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

class LashElement {
  final int id;
  final String imagePath;
  final Offset position;
  final double scale;
  final double rotation;
  final bool isMirrored;

  const LashElement({
    required this.id,
    required this.imagePath,
    required this.position,
    this.scale = 1,
    this.rotation = 0,
    this.isMirrored = false,
  });

  LashElement copyWith({
    int? id,
    String? imagePath,
    Offset? position,
    double? scale,
    double? rotation,
    bool? isMirrored,
  }) {
    return LashElement(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isMirrored: isMirrored ?? this.isMirrored,
    );
  }
}

class EditableLashWidget extends StatelessWidget {
  final LashElement lash;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<DragUpdateDetails> onPanUpdate;

  const EditableLashWidget({
    super.key,
    required this.lash,
    required this.isSelected,
    required this.onTap,
    required this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: lash.position.dx,
      top: lash.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onPanStart: (_) => onTap(),
        onPanUpdate: onPanUpdate,
        child: Transform.rotate(
          angle: lash.rotation,
          child: Transform.scale(
            scaleX: lash.isMirrored ? -lash.scale : lash.scale,
            scaleY: lash.scale,
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
                width: 200,
              ),
            ),
          ),
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

  const MenuIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
