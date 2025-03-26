import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

class OCRPage extends StatefulWidget {
  const OCRPage({Key? key}) : super(key: key);

  @override
  State<OCRPage> createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  String _lastSpokenText = '';
  bool _isSpeaking = false;
  final FlutterTts _flutterTts = FlutterTts();
  late final TextRecognizer _textRecognizer;
  List<CameraDescription>? _cameras;

  List<String> _textSamples = [];
  Timer? _aggregationTimer;
  final Duration aggregationDuration = const Duration(seconds: 2);
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
    _aggregationTimer =
        Timer.periodic(aggregationDuration, (_) => _analyzeTextSamples());
  }

  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.3);
    await _flutterTts.setPitch(1.0);
    _flutterTts.awaitSpeakCompletion;

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    final camera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});

    _cameraController!.startImageStream(_onCameraImage);
  }

  void _onCameraImage(CameraImage image) {
    if (_isDetecting) return;

    _frameCount++;
    if (_frameCount % 3 != 0) return;

    _processCameraImage(image);
  }

  void _processCameraImage(CameraImage image) async {
    _isDetecting = true;
    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text.trim();

      if (text.isNotEmpty) {
        _textSamples.add(text);
      }
    } catch (e) {
      print("Error processing image: $e");
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertToInputImage(CameraImage image) {
    try {
      final rotationDegrees = _cameraController!.description.sensorOrientation;
      InputImageRotation imageRotation = InputImageRotation.rotation0deg;
      switch (rotationDegrees) {
        case 90:
          imageRotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          imageRotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          imageRotation = InputImageRotation.rotation270deg;
          break;
        default:
          imageRotation = InputImageRotation.rotation0deg;
      }

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      final bytes = _concatenatePlanes(image.planes);

      final inputImageMetadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );
    } catch (e) {
      print("Error converting to InputImage: $e");
      return null;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Future<void> _analyzeTextSamples() async {
    if (_textSamples.length < 3) return;

    String bestCandidate = '';
    int bestCount = 0;

    for (var i = 0; i < _textSamples.length; i++) {
      int matchCount = 0;
      for (var j = 0; j < _textSamples.length; j++) {
        if (i == j) continue;
        double sim = _levenshteinSimilarity(_textSamples[i], _textSamples[j]);
        if (sim > 0.95) matchCount++;
      }
      if (matchCount > bestCount) {
        bestCandidate = _textSamples[i];
        bestCount = matchCount;
      }
    }

    _textSamples.clear();

    if (bestCandidate.isEmpty ||
        bestCandidate == _lastSpokenText ||
        _isSpeaking) return;

    print("--- Speaking: $bestCandidate");
    _lastSpokenText = bestCandidate;
    _isSpeaking = true;
    await _speakText(bestCandidate);
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<List<int>> matrix = List.generate(
        s.length + 1, (_) => List.filled(t.length + 1, 0),
        growable: false);

    for (int i = 0; i <= s.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= t.length; j++) matrix[0][j] = j;

    for (int i = 1; i <= s.length; i++) {
      for (int j = 1; j <= t.length; j++) {
        int cost = s[i - 1] == t[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s.length][t.length];
  }

  double _levenshteinSimilarity(String a, String b) {
    int dist = _levenshtein(a, b);
    int maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (dist / maxLen);
  }

  Future<void> _speakText(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print("Error during TTS speak: $e");
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  void dispose() {
    _aggregationTimer?.cancel();
    _cameraController?.dispose();
    _textRecognizer.close();
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton(
                  onPressed: _stopSpeaking,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Stop Speaking',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
