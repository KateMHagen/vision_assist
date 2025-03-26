import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:flutter/foundation.dart';

class ObjectClassificationPage extends StatefulWidget {
  const ObjectClassificationPage({super.key});

  @override
  State<ObjectClassificationPage> createState() =>
      _ObjectClassificationPageState();
}

class _ObjectClassificationPageState extends State<ObjectClassificationPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  List<ImageLabel> _labels = [];
  late ImageLabeler _imageLabeler;
  List<CameraDescription>? _cameras;

  final FlutterTts _flutterTts = FlutterTts();
  String? _lastSpokenLabel;
  DateTime _lastSpokenTime =
      DateTime.now().subtract(const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeTTS();
    _imageLabeler = ImageLabeler(options: ImageLabelerOptions());
  }

  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.35); // slower
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    final backCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});
    _cameraController!.startImageStream(_processCameraImage);
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());

      final InputImageRotation rotation = InputImageRotation.rotation0deg;
      final InputImageFormat format =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );

      final labels = await _imageLabeler.processImage(inputImage);
      final filteredLabels = labels.where((l) => l.confidence > 0.75).toList();

      setState(() {
        _labels = filteredLabels;
      });

      if (filteredLabels.isNotEmpty) {
        final label = filteredLabels.first.label;

        if (label != _lastSpokenLabel ||
            DateTime.now().difference(_lastSpokenTime).inSeconds > 2) {
          await _flutterTts.speak(label);
          _lastSpokenLabel = label;
          _lastSpokenTime = DateTime.now();
        }
      }
    } catch (e) {
      print("Image classification error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _imageLabeler.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_cameraController!)),
          if (_labels.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                height: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Detected Labels",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _labels.length,
                        itemBuilder: (context, index) {
                          final label = _labels[index];
                          return ListTile(
                            dense: true,
                            leading:
                                const Icon(Icons.tag, color: Colors.deepPurple),
                            title: Text(
                              label.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Confidence: ${label.confidence.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black54),
                            ),
                          );
                        },
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
}
