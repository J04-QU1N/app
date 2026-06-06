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
  final GlobalKey _cropKey = GlobalKey();
  bool _isSaving = false;

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Encuadrar foto'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveCrop,
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
                'Mové y hacé zoom para encuadrar la foto.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: RepaintBoundary(
                      key: _cropKey,
                      child: ClipRect(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          child: SizedBox.expand(
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveCrop,
                  icon: const Icon(Icons.crop),
                  label: const Text('Confirmar encuadre'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
