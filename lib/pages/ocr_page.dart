import 'dart:async';
import 'dart:math';
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

    // (Optional) Debug: print available languages and voices.
    try {
      List<dynamic>? languages = await _flutterTts.getLanguages;
      print("Available languages: $languages");

      List<dynamic>? voices = await _flutterTts.getVoices;
      print("Available voices: $voices");
    } catch (e) {
      print("Error retrieving TTS languages/voices: $e");
    }
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

      // Always update the UI with the latest recognized text.
      setState(() {
        _extractText = text;
      });

      // Add the recognized text sample for aggregation.
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

  /// Analyzes the collected OCR samples and speaks the most common (and clean) line.
  Future<void> _analyzeTextSamples() async {
    if (_textSamples.isEmpty) return;

    // Build a list of individual lines from all samples.
    List<String> allLines = [];
    for (var sample in _textSamples) {
      // Split by newline and trim.
      List<String> lines = sample.split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      allLines.addAll(lines);
    }

    // Clear the samples for the next aggregation window.
    _textSamples.clear();

    // Define a blacklist of words we want to ignore.
    final Set<String> blacklist = {'ENERGY', 'ZERO SUGAR', 'SOUR', 'PATCH'};

    // Filter lines:
    List<String> candidateLines = allLines.where((line) {
      // Remove lines that are very short.
      if (line.length < 3) return false;

      // Optionally: Count occurrences of blacklisted words.
      int blacklistCount = 0;
      for (var word in blacklist) {
        if (line.toUpperCase().contains(word)) {
          blacklistCount++;
        }
      }
      // If the line contains more than one blacklisted word, treat it as noise.
      return blacklistCount < 2;
    }).toList();

    // If filtering removes everything, fall back to allLines.
    if (candidateLines.isEmpty) candidateLines = allLines;

    // Build frequency map for the candidate lines.
    Map<String, int> frequency = {};
    for (var line in candidateLines) {
      frequency[line] = (frequency[line] ?? 0) + 1;
    }

    if (frequency.isEmpty) return;

    // Pick the most common line.
    String mostCommonLine = frequency.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    ).key;

    print("Aggregated line frequency: $frequency");
    print("Most common line: $mostCommonLine");

    // Trigger TTS if the selected line is nonempty, different from the last spoken text,
    // and if TTS is not already busy.
    if (mostCommonLine.isNotEmpty &&
        mostCommonLine != _lastSpokenText &&
        !_isSpeaking) {
      _lastSpokenText = mostCommonLine;
      _isSpeaking = true;
      print("Stable aggregated text detected, speaking: $mostCommonLine");
      await _speakText(mostCommonLine);
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
          // Live camera preview.
          AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
          const SizedBox(height: 16),
          // Display the latest recognized text.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _extractText.isEmpty ? 'No text detected.' : _extractText,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          // Button to manually test TTS.
          ElevatedButton(
            onPressed: () async {
              print("Test TTS button pressed.");
              await _speakText("test of the text-to-speech system.");
            },
            child: const Text('Test TTS'),
          ),
          const SizedBox(height: 16),
          // Button to stop speaking.
          ElevatedButton(
            onPressed: _stopSpeaking,
            child: const Text('Stop Speaking'),
          ),
        ],
      ),
    );
  }
}
