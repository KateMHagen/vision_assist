import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:flutter/foundation.dart';

class ObjectDetectionPage extends StatefulWidget {
  const ObjectDetectionPage({super.key});

  @override
  State<ObjectDetectionPage> createState() => _ObjectDetectionPageState();
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  List<DetectedObject> _detectedObjects = [];
  late ObjectDetector _objectDetector;
  List<CameraDescription>? _cameras;

  final FlutterTts _flutterTts = FlutterTts();
  String? _lastSpokenLabel;
  DateTime _lastSpokenTime = DateTime.now().subtract(Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
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

      final detectedObjects = await _objectDetector.processImage(inputImage);

      setState(() {
        _detectedObjects = detectedObjects;
      });

      if (detectedObjects.isNotEmpty) {
        final firstLabel = detectedObjects.first.labels.isNotEmpty
            ? detectedObjects.first.labels.first.text
            : null;

        if (firstLabel != null &&
            (firstLabel != _lastSpokenLabel ||
                DateTime.now().difference(_lastSpokenTime).inSeconds > 2)) {
          await _flutterTts.speak(firstLabel);
          _lastSpokenLabel = firstLabel;
          _lastSpokenTime = DateTime.now();
        }
      }
    } catch (e) {
      print("Error detecting objects: $e");
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _objectDetector.close();
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
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          if (_detectedObjects.isNotEmpty)
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
                height: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Detected Objects",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _detectedObjects.length,
                        itemBuilder: (context, index) {
                          final obj = _detectedObjects[index];
                          final label = obj.labels.isNotEmpty
                              ? obj.labels.first.text
                              : 'Unknown';
                          final confidence = obj.labels.isNotEmpty
                              ? obj.labels.first.confidence.toStringAsFixed(2)
                              : 'N/A';
                          return ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(
                                vertical: -2, horizontal: -4),
                            leading: const Icon(Icons.label_outline,
                                color: Colors.deepPurple),
                            title: Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              'Confidence: $confidence',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
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
