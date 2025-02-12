import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For WriteBuffer
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
  String _extractText = '';       // Latest OCR result for display
  String _lastSpokenText = '';    // The text that was last spoken
  bool _isSpeaking = false;       // Flag to track if TTS is speaking
  final FlutterTts _flutterTts = FlutterTts();
  late final TextRecognizer _textRecognizer;
  List<CameraDescription>? _cameras;

  // Aggregation variables:
  List<String> _textSamples = []; // Collected OCR texts over the aggregation period
  Timer? _aggregationTimer;
  final Duration aggregationDuration = const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
    // Start periodic aggregation of OCR results.
    _aggregationTimer =
        Timer.periodic(aggregationDuration, (_) => _analyzeTextSamples());
  }

  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    _flutterTts.awaitSpeakCompletion;

    _flutterTts.setCompletionHandler(() {
      print("TTS completed");
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    // Choose the back camera if available.
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

    // Start streaming images from the camera.
    _cameraController!.startImageStream(_processCameraImage);
  }

  /// Processes each camera image frame.
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;
    try {
      // Determine the correct rotation.
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

      // Determine the image format.
      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      // Concatenate the image planes into one buffer.
      final bytes = _concatenatePlanes(image.planes);

      // Create the metadata (plane data is no longer needed).
      final inputImageMetadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      // Create the InputImage.
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );

      // Process the image using ML Kit’s text recognizer.
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text.trim();

      // Update the UI with the latest recognized text.
      setState(() {
        _extractText = text;
      });

      // Add the full OCR text sample if it's not empty.
      if (text.isNotEmpty) {
        _textSamples.add(text);
      }
    } catch (e) {
      print("Error processing image: $e");
    } finally {
      _isDetecting = false;
    }
  }

  /// Concatenates the image planes into one byte buffer.
  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  /// Analyzes the collected OCR samples and speaks the most complete text.
  Future<void> _analyzeTextSamples() async {
    if (_textSamples.isEmpty) return;

    // Filter out samples that are too short (e.g. less than 30 characters).
    List<String> candidateTexts =
        _textSamples.where((sample) => sample.length >= 30).toList();
    if (candidateTexts.isEmpty) {
      candidateTexts = List.from(_textSamples);
    }

    // Clear the samples for the next aggregation window.
    _textSamples.clear();

    // Choose the candidate text with the maximum length (assumed to be the full text).
    String mostCompleteText = candidateTexts.reduce((a, b) =>
        a.length >= b.length ? a : b);

    print("Aggregated full text candidate: $mostCompleteText");

    // Trigger TTS if the candidate is nonempty, different from what was last spoken, and TTS is not busy.
    if (mostCompleteText.isNotEmpty &&
        mostCompleteText != _lastSpokenText &&
        !_isSpeaking) {
      _lastSpokenText = mostCompleteText;
      _isSpeaking = true;
      print("Stable aggregated text detected, speaking: $mostCompleteText");
      await _speakText(mostCompleteText);
    }
  }

  /// Speaks the given text aloud using Flutter TTS.
  Future<void> _speakText(String text) async {
    try {
      var result = await _flutterTts.speak(text);
      print("TTS speak result: $result");
    } catch (e) {
      print("Error during TTS speak: $e");
    }
  }

  /// Stops any ongoing speech.
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
      appBar: AppBar(
        title: const Text('Live OCR with ML Kit'),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _extractText.isEmpty ? 'No text detected.' : _extractText,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              print("Test TTS button pressed.");
              await _speakText("Hello, this is a test of the text-to-speech system.");
            },
            child: const Text('Test TTS'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _stopSpeaking,
            child: const Text('Stop Speaking'),
          ),
        ],
      ),
    );
  }
}
