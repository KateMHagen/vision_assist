
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRPage extends StatefulWidget {
  const OCRPage({super.key});

  @override
  State<OCRPage> createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  String _extractText = '';
  File? _pickedImage;

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
                height:200,
                width: 200,
                fit: BoxFit.cover,
                ),
            ElevatedButton(
              onPressed: () async {
                final ImagePicker picker = ImagePicker();  // Correct usage
                final pickedFile = await picker.pickImage(source: ImageSource.gallery); // Use pickImage method
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
                }
              },
              child: const Text('Pick Image'),
            ),
            const SizedBox(height: 20),
            Text(_extractText.isEmpty ? 'No text detected' : _extractText),
          ],
        ),
      ),
    );
  }
}