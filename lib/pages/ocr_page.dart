
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

class OCRPage extends StatefulWidget {
  const OCRPage({super.key});

  @override
  State<OCRPage> createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  String _extractText = '';
  File? _pickedImage;
  final FlutterTts _flutterTts = FlutterTts();  // Create an instance of FlutterTts

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage('en-US');  // Set the language for TTS (English)
  }

  // Function to speak the detected text
  Future<void> _speakText() async {
    if (_extractText.isNotEmpty) {
      await _flutterTts.speak(_extractText);  // Speak the detected text aloud
    }
  }

  // Function to stop speaking
  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();  // Stops the text-to-speech
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR with Google ML Kit'),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            _pickedImage == null
                ? const Text('No image selected.')
                : Image.file(_pickedImage!,
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                ),
            ElevatedButton(
              onPressed: () async {
                final ImagePicker picker = ImagePicker();  
                final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  setState(() {
                    _pickedImage = File(pickedFile.path);
                  });

                  // Initialize Google ML Kit's text recognizer
                  final inputImage = InputImage.fromFilePath(pickedFile.path);
                  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
                  final visionText = await textRecognizer.processImage(inputImage);

                  setState(() {
                    _extractText = visionText.text;
                  });

                  // Automatically speak the detected text
                  _speakText();
                }
              },
              child: const Text('Pick Image'),
            ),
            const SizedBox(height: 20),
            Text(_extractText.isEmpty ? 'No text detected' : _extractText),

            // Stop Speaking Button
            ElevatedButton(
              onPressed: _stopSpeaking,
              child: const Text('Stop Speaking'),
            ),
          ],
        ),
      ),
    );
  }
}