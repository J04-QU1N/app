import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class CropImageScreen extends StatefulWidget {
  final String imagePath;

  const CropImageScreen({super.key, required this.imagePath});

  @override
  State<CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<CropImageScreen> {
  static const double cropAspectRatio = 3 / 4; // 3 ancho x 4 alto.

  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();

  bool _isSaving = false;
  ui.Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final Uint8List bytes = await File(widget.imagePath).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();

    if (!mounted) return;
    setState(() {
      _imageSize = ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
  }

  Future<void> _saveCrop() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final RenderRepaintBoundary boundary =
          _cropKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        if (!mounted) return;
        Navigator.pop(context, null);
        return;
      }

      final Uint8List bytes = byteData.buffer.asUint8List();
      final String outputPath =
          '${Directory.systemTemp.path}/lashvision_crop_${DateTime.now().millisecondsSinceEpoch}.png';

      final File outputFile = File(outputPath);
      await outputFile.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context, outputPath);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context, null);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Encuadrar foto'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving || _imageSize == null ? null : _saveCrop,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Usar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'La foto mantiene su proporción original. Movela y hacé zoom para elegir qué parte queda dentro del encuadre vertical 3:4.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double availableWidth = constraints.maxWidth - 32;
                    final double availableHeight = constraints.maxHeight - 32;

                    double cropWidth = availableWidth;
                    double cropHeight = cropWidth / cropAspectRatio;

                    if (cropHeight > availableHeight) {
                      cropHeight = availableHeight;
                      cropWidth = cropHeight * cropAspectRatio;
                    }

                    if (_imageSize == null) {
                      return SizedBox(
                        width: cropWidth,
                        height: cropHeight,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final double imageAspectRatio =
                        _imageSize!.width / _imageSize!.height;

                    /// Tamaño base de la foto: cubre completamente el marco 3:4,
                    /// pero mantiene la proporción real de la imagen original.
                    double imageWidth = cropWidth;
                    double imageHeight = imageWidth / imageAspectRatio;

                    if (imageHeight < cropHeight) {
                      imageHeight = cropHeight;
                      imageWidth = imageHeight * imageAspectRatio;
                    }

                    return Container(
                      width: cropWidth,
                      height: cropHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        key: _cropKey,
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController:
                                _transformationController,
                            minScale: 1,
                            maxScale: 6,
                            boundaryMargin: EdgeInsets.zero,
                            constrained: false,
                            panEnabled: true,
                            scaleEnabled: true,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: imageWidth,
                              height: imageHeight,
                              child: Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving || _imageSize == null ? null : _saveCrop,
                  icon: const Icon(Icons.crop_portrait),
                  label: const Text('Confirmar encuadre 3:4'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
