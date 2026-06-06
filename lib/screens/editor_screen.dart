import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import 'crop_image_screen.dart';
import 'saved_image_store.dart';

class EditorScreen extends StatefulWidget {
  final String imagePath;

  const EditorScreen({super.key, required this.imagePath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const double editorAspectRatio = 3 / 4;
  static const double _bottomActionsHeight = 64;
  static const double _elementMenuHeight = 58;

  final GlobalKey _editorCaptureKey = GlobalKey();

  bool isPanelOpen = true;
  late String selectedImagePath;

  final List<LashElement> lashes = [];
  int? selectedLashId;
  bool isEditMenuOpen = false;
  LashEditMode lashEditMode = LashEditMode.move;

  final List<EditorSnapshot> _undoStack = [];
  final List<EditorSnapshot> _redoStack = [];

  int? _gestureLashId;
  double _gestureStartRotation = 0;
  bool _gestureHistorySaved = false;

  @override
  void initState() {
    super.initState();
    selectedImagePath = widget.imagePath;
  }

  EditorSnapshot _snapshot() {
    return EditorSnapshot(
      imagePath: selectedImagePath,
      lashes: lashes.map((lash) => lash.copyWith()).toList(),
      selectedLashId: selectedLashId,
      isEditMenuOpen: isEditMenuOpen,
      lashEditMode: lashEditMode,
    );
  }

  void _restoreSnapshot(EditorSnapshot snapshot) {
    selectedImagePath = snapshot.imagePath;
    lashes
      ..clear()
      ..addAll(snapshot.lashes.map((lash) => lash.copyWith()));
    selectedLashId = snapshot.selectedLashId;
    isEditMenuOpen = snapshot.isEditMenuOpen;
    lashEditMode = snapshot.lashEditMode;
  }

  void _saveHistory() {
    _undoStack.add(_snapshot());
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_snapshot());
      _restoreSnapshot(_undoStack.removeLast());
      _gestureLashId = null;
      _gestureHistorySaved = false;
    });
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_snapshot());
      _restoreSnapshot(_redoStack.removeLast());
      _gestureLashId = null;
      _gestureHistorySaved = false;
    });
  }

  Future<void> replaceImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null || !mounted) return;

    final String? croppedImagePath = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CropImageScreen(imagePath: image.path),
      ),
    );

    if (croppedImagePath == null) return;

    setState(() {
      _saveHistory();
      selectedImagePath = croppedImagePath;
      selectedLashId = null;
      isEditMenuOpen = false;
      lashEditMode = LashEditMode.move;
    });
  }

  Future<void> showReplaceImageOptions() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cambiar imagen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Colors.white),
                  title: const Text('Cámara', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.white),
                  title: const Text('Galería', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;
    await replaceImage(source);
  }

  Future<void> saveEditedImage() async {
    final TextEditingController controller = TextEditingController();

    final String? label = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Guardar imagen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre o etiqueta',
              hintText: 'Ej: Cliente 01',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final String value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(context, value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (label == null || label.trim().isEmpty) return;

    try {
      final RenderRepaintBoundary boundary = _editorCaptureKey.currentContext!
          .findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return;

      final Uint8List bytes = byteData.buffer.asUint8List();
      final String safeLabel = label.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
      final Directory saveDirectory = await SavedImageStore.getImagesDirectory();
      final String outputPath =
          '${saveDirectory.path}/lashvision_${safeLabel}_${DateTime.now().millisecondsSinceEpoch}.png';

      await File(outputPath).writeAsBytes(bytes);

      await SavedImageStore.add(
        SavedEditedImage(
          label: label,
          path: outputPath,
          createdAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imagen guardada como "$label"')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la imagen.')),
      );
    }
  }

  void addLash(String imagePath) {
    final int id = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _saveHistory();
      lashes.add(
        LashElement(
          id: id,
          imagePath: imagePath,
          position: const Offset(210, 280),
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
      _saveHistory();
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
      _saveHistory();
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
      _saveHistory();
      lashes[index] = update(lashes[index]);
    });
  }

  void startLashGesture(int id, ScaleStartDetails details) {
    final int index = lashes.indexWhere((element) => element.id == id);
    if (index == -1) return;

    setState(() => selectedLashId = id);
    _gestureLashId = id;
    _gestureStartRotation = lashes[index].rotation;
    _gestureHistorySaved = false;
  }

  void _saveGestureHistoryIfNeeded() {
    if (_gestureHistorySaved) return;
    _saveHistory();
    _gestureHistorySaved = true;
  }

  void updateLashGesture(int id, ScaleUpdateDetails details) {
    if (_gestureLashId != id) return;
    final int index = lashes.indexWhere((element) => element.id == id);
    if (index == -1) return;

    final LashElement current = lashes[index];
    LashElement updated;

    switch (lashEditMode) {
      case LashEditMode.move:
      case LashEditMode.resize:
        if (details.focalPointDelta == Offset.zero) return;
        _saveGestureHistoryIfNeeded();
        updated = current.copyWith(
          position: current.position + details.focalPointDelta,
        );
        break;
      case LashEditMode.rotate:
        if (details.rotation.abs() < 0.001) {
          return;
        }
        _saveGestureHistoryIfNeeded();
        updated = current.copyWith(
          rotation: _gestureStartRotation + details.rotation,
        );
        break;
    }

    setState(() => lashes[index] = updated);
  }

  void finishLashGesture(int id) {
    if (_gestureLashId == id) {
      _gestureLashId = null;
      _gestureHistorySaved = false;
    }
  }

  void updateLashHandleDrag(
    int id,
    LashResizeHandle handle,
    DragUpdateDetails details,
  ) {
    final int index = lashes.indexWhere((element) => element.id == id);
    if (index == -1) return;

    _saveGestureHistoryIfNeeded();

    final LashElement current = lashes[index];

    // Convertimos el arrastre global del dedo al eje local del elemento.
    // Así los pads siguen funcionando aunque el elemento esté rotado.
    final double cosR = math.cos(-current.rotation);
    final double sinR = math.sin(-current.rotation);
    final Offset localDelta = Offset(
      details.delta.dx * cosR - details.delta.dy * sinR,
      details.delta.dx * sinR + details.delta.dy * cosR,
    );

    final double visualWidth = EditableLashWidget.baseWidth * current.scale * current.stretchX;
    final double visualHeight = EditableLashWidget.baseHeight * current.scale * current.stretchY;

    double nextScale = current.scale;
    double nextStretchX = current.stretchX;
    double nextStretchY = current.stretchY;
    Offset nextPosition = current.position;

    Offset localCenterShift = Offset.zero;

    switch (handle) {
      case LashResizeHandle.left:
        final double newWidth = (visualWidth - localDelta.dx).clamp(28.0, 900.0);
        final double widthDelta = newWidth - visualWidth;
        nextStretchX = (newWidth / (EditableLashWidget.baseWidth * current.scale)).clamp(0.18, 6).toDouble();
        localCenterShift = Offset(-widthDelta / 2, 0);
        break;
      case LashResizeHandle.right:
        final double newWidth = (visualWidth + localDelta.dx).clamp(28.0, 900.0);
        final double widthDelta = newWidth - visualWidth;
        nextStretchX = (newWidth / (EditableLashWidget.baseWidth * current.scale)).clamp(0.18, 6).toDouble();
        localCenterShift = Offset(widthDelta / 2, 0);
        break;
      case LashResizeHandle.top:
        final double newHeight = (visualHeight - localDelta.dy).clamp(18.0, 700.0);
        final double heightDelta = newHeight - visualHeight;
        nextStretchY = (newHeight / (EditableLashWidget.baseHeight * current.scale)).clamp(0.18, 6).toDouble();
        localCenterShift = Offset(0, -heightDelta / 2);
        break;
      case LashResizeHandle.bottom:
        final double newHeight = (visualHeight + localDelta.dy).clamp(18.0, 700.0);
        final double heightDelta = newHeight - visualHeight;
        nextStretchY = (newHeight / (EditableLashWidget.baseHeight * current.scale)).clamp(0.18, 6).toDouble();
        localCenterShift = Offset(0, heightDelta / 2);
        break;
      case LashResizeHandle.corner:
        final double factor = 1 + ((localDelta.dx + localDelta.dy) / 260);
        nextScale = (current.scale * factor).clamp(0.15, 5).toDouble();
        break;
    }

    if (localCenterShift != Offset.zero) {
      final double cosForward = math.cos(current.rotation);
      final double sinForward = math.sin(current.rotation);
      nextPosition = current.position + Offset(
        localCenterShift.dx * cosForward - localCenterShift.dy * sinForward,
        localCenterShift.dx * sinForward + localCenterShift.dy * cosForward,
      );
    }

    setState(() {
      lashes[index] = current.copyWith(
        position: nextPosition,
        scale: nextScale,
        stretchX: nextStretchX,
        stretchY: nextStretchY,
      );
    });
  }

  void finishHandleDrag() {
    _gestureHistorySaved = false;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelectedLash = selectedLashId != null;
    final double topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            top: topPadding + 86,
            bottom: _bottomActionsHeight + _elementMenuHeight + 18,
            child: Align(
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: editorAspectRatio,
                child: RepaintBoundary(
                  key: _editorCaptureKey,
                  child: DragTarget<String>(
                    onAccept: addLash,
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: closeBottomMenus,
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            Image.file(
                              File(selectedImagePath),
                              fit: BoxFit.fill,
                            ),
                            ...lashes.map(
                              (lash) => EditableLashWidget(
                                lash: lash,
                                isSelected: selectedLashId == lash.id,
                                editMode: selectedLashId == lash.id
                                    ? lashEditMode
                                    : LashEditMode.move,
                                onTap: () => selectLash(lash.id),
                                onScaleStart: (details) => startLashGesture(lash.id, details),
                                onScaleUpdate: (details) => updateLashGesture(lash.id, details),
                                onScaleEnd: (_) => finishLashGesture(lash.id),
                                onHandleDrag: (handle, details) =>
                                    updateLashHandleDrag(lash.id, handle, details),
                                onHandleDragEnd: finishHandleDrag,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            top: topPadding + 8,
            child: Row(
              children: [
                if (!isPanelOpen)
                  LabeledTopButton(
                    icon: Icons.menu,
                    label: 'Menú',
                    onPressed: () => setState(() => isPanelOpen = true),
                  )
                else
                  const SizedBox(width: 88),
                const Spacer(),
                LabeledTopButton(
                  icon: Icons.save,
                  label: 'Guardar',
                  onPressed: saveEditedImage,
                ),
              ],
            ),
          ),

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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => setState(() => isPanelOpen = false),
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
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (hasSelectedLash)
            Positioned(
              left: 0,
              right: 0,
              bottom: _bottomActionsHeight,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: isEditMenuOpen ? buildTransformMenu() : buildMainElementMenu(),
              ),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: BottomEditorMenu(
                children: [
                  MenuIconButton(
                    icon: Icons.undo,
                    label: 'Deshacer',
                    onPressed: _undoStack.isEmpty ? null : undo,
                  ),
                  MenuIconButton(
                    icon: Icons.redo,
                    label: 'Rehacer',
                    onPressed: _redoStack.isEmpty ? null : redo,
                  ),
                  MenuIconButton(
                    icon: Icons.photo_camera_back,
                    label: 'Imagen',
                    onPressed: showReplaceImageOptions,
                  ),
                ],
              ),
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
              lashEditMode = LashEditMode.resize;
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
          icon: Icons.control_camera,
          label: 'Ajustar',
          isSelected: lashEditMode == LashEditMode.resize,
          onPressed: () => setState(() => lashEditMode = LashEditMode.resize),
        ),
        MenuIconButton(
          icon: Icons.rotate_right,
          label: 'Rotar',
          isSelected: lashEditMode == LashEditMode.rotate,
          onPressed: () => setState(() => lashEditMode = LashEditMode.rotate),
        ),
        MenuIconButton(
          icon: Icons.flip,
          label: 'Espejar',
          onPressed: () {
            updateSelectedLash(
              (lash) => lash.copyWith(
                isMirrored: !lash.isMirrored,
                rotation: -lash.rotation,
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
        padding: const EdgeInsets.all(8),
        child: Image.asset(imagePath, width: 80),
      ),
    );
  }
}

enum LashEditMode {
  move,
  resize,
  rotate,
}

enum LashResizeHandle {
  left,
  right,
  top,
  bottom,
  corner,
}

class EditorSnapshot {
  final String imagePath;
  final List<LashElement> lashes;
  final int? selectedLashId;
  final bool isEditMenuOpen;
  final LashEditMode lashEditMode;

  const EditorSnapshot({
    required this.imagePath,
    required this.lashes,
    required this.selectedLashId,
    required this.isEditMenuOpen,
    required this.lashEditMode,
  });
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
  static const double baseHeight = 90;

  final LashElement lash;
  final bool isSelected;
  final LashEditMode editMode;
  final VoidCallback onTap;
  final ValueChanged<ScaleStartDetails> onScaleStart;
  final ValueChanged<ScaleUpdateDetails> onScaleUpdate;
  final ValueChanged<ScaleEndDetails> onScaleEnd;
  final void Function(LashResizeHandle handle, DragUpdateDetails details) onHandleDrag;
  final VoidCallback onHandleDragEnd;

  const EditableLashWidget({
    super.key,
    required this.lash,
    required this.isSelected,
    required this.editMode,
    required this.onTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onHandleDrag,
    required this.onHandleDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final String hintText = switch (editMode) {
      LashEditMode.resize => 'Arrastrá los puntos para ajustar',
      LashEditMode.rotate => 'Usá dos dedos para rotar',
      LashEditMode.move => 'Arrastrá para mover',
    };

    final double transformedWidth = baseWidth * lash.scale * lash.stretchX;
    final double transformedHeight = baseHeight * lash.scale * lash.stretchY;
    final double boxWidth = transformedWidth + 96;
    final double boxHeight = transformedHeight + 74;
    final Offset elementCenter = Offset(boxWidth / 2, boxHeight / 2);

    final Widget transformedElement = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(lash.rotation)
        ..scale(
          (lash.isMirrored ? -1.0 : 1.0) * lash.scale * lash.stretchX,
          lash.scale * lash.stretchY,
        ),
      child: SizedBox(
        width: baseWidth,
        height: baseHeight,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              lash.imagePath,
              fit: BoxFit.contain,
            ),
            if (isSelected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Positioned(
      left: lash.position.dx - boxWidth / 2,
      top: lash.position.dy - boxHeight / 2,
      width: boxWidth,
      height: boxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onTap,
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              onScaleEnd: onScaleEnd,
              child: transformedElement,
            ),
          ),
          if (isSelected && editMode == LashEditMode.resize)
            ..._buildHandles(
              elementCenter: elementCenter,
              width: transformedWidth,
              height: transformedHeight,
            ),
          if (isSelected)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hintText,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildHandles({
    required Offset elementCenter,
    required double width,
    required double height,
  }) {
    Offset rotatePoint(Offset point) {
      final double cosR = math.cos(lash.rotation);
      final double sinR = math.sin(lash.rotation);
      final Offset fromCenter = point;
      return Offset(
        elementCenter.dx + fromCenter.dx * cosR - fromCenter.dy * sinR,
        elementCenter.dy + fromCenter.dx * sinR + fromCenter.dy * cosR,
      );
    }

    Widget handleAt({
      required Offset localPoint,
      required LashResizeHandle handle,
      required IconData icon,
      bool isCorner = false,
    }) {
      final Offset point = rotatePoint(localPoint);
      final double size = isCorner ? 36 : 30;
      return Positioned(
        left: point.dx - size / 2,
        top: point.dy - size / 2,
        child: _Handle(
          size: size,
          icon: icon,
          isCorner: isCorner,
          onPanUpdate: (details) => onHandleDrag(handle, details),
          onPanEnd: onHandleDragEnd,
        ),
      );
    }

    return [
      handleAt(
        localPoint: Offset(-width / 2, 0),
        handle: LashResizeHandle.left,
        icon: Icons.drag_indicator,
      ),
      handleAt(
        localPoint: Offset(width / 2, 0),
        handle: LashResizeHandle.right,
        icon: Icons.drag_indicator,
      ),
      handleAt(
        localPoint: Offset(0, -height / 2),
        handle: LashResizeHandle.top,
        icon: Icons.drag_handle,
      ),
      handleAt(
        localPoint: Offset(0, height / 2),
        handle: LashResizeHandle.bottom,
        icon: Icons.drag_handle,
      ),
      handleAt(
        localPoint: Offset(width / 2, height / 2),
        handle: LashResizeHandle.corner,
        icon: Icons.open_in_full,
        isCorner: true,
      ),
    ];
  }
}

class _Handle extends StatelessWidget {
  final double size;
  final IconData icon;
  final bool isCorner;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final VoidCallback onPanEnd;

  const _Handle({
    required this.size,
    required this.icon,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.isCorner = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onPanEnd(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: isCorner ? 18 : 15),
      ),
    );
  }
}

class LabeledTopButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const LabeledTopButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? Colors.black38 : Colors.black87,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: onPressed == null ? Colors.white38 : Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: onPressed == null ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children
              .map(
                (child) => Expanded(
                  child: Center(child: child),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class MenuIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
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
    final Color foreground = onPressed == null ? Colors.white38 : Colors.white;

    return Material(
      color: isSelected ? Colors.white24 : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
