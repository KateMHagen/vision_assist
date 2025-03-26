import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

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
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImageData = InputImageMetadata(
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
                color: Colors.black54,
                height: 200,
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
                      title: Text('Object: $label',
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text('Confidence: $confidence',
                          style: TextStyle(color: Colors.white70)),
                    );
                  },
                ),
              ),
            )
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
// import 'dart:io';

// class ObjectDetectionPage extends StatefulWidget {
//   const ObjectDetectionPage({super.key});

//   @override
//   State<ObjectDetectionPage> createState() => _ObjectDetectionPageState();
// }

// class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
//   File? _image;
//   List<DetectedObject> _detectedObjects = [];
//   final ImagePicker _picker = ImagePicker();
//   final ObjectDetector _objectDetector = ObjectDetector(
//     options: ObjectDetectorOptions(
//       mode: DetectionMode.single,
//       classifyObjects: true,
//       multipleObjects: true,
//     ),
//   );

//   // Function to pick an image from the gallery or camera
//   Future<void> _pickImage() async {
//     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);  // or ImageSource.camera

//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//       });
//       _detectObjects(_image!);
//     }
//   }

//   // Function to perform object detection on the selected image
//   Future<void> _detectObjects(File imageFile) async {
//     final inputImage = InputImage.fromFile(imageFile);
//     final objects = await _objectDetector.processImage(inputImage);

//     // Print the detected objects for debugging
//     print("Detected objects: ${objects.length}");

//     setState(() {
//       _detectedObjects = objects;
//     });
//   }

//   @override
//   void dispose() {
//     _objectDetector.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Object Detection Page"),
//       ),
//       body: SingleChildScrollView(  // Wrap the body with SingleChildScrollView for scrolling
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             children: [
//               // Show selected image if available
//               _image == null
//                   ? Text("No image selected")
//                   : Container(
//                       width: double.infinity,  // Ensure the image takes full width
//                       height: 300,  // Set a fixed height to prevent overflow
//                       child: Image.file(
//                         _image!,
//                         fit: BoxFit.contain,  // Ensure image scales proportionally
//                       ),
//                     ),
//               SizedBox(height: 20),
//               // Button to pick an image
//               ElevatedButton(
//                 onPressed: _pickImage,
//                 child: Text("Pick Image"),
//               ),
//               SizedBox(height: 20),
//               // Show detected objects info
//               if (_detectedObjects.isNotEmpty)
//                 Container(
//                   // Constrain the ListView to prevent overflow
//                   height: 300,  // Set a fixed height for the list view
//                   child: ListView.builder(
//                     itemCount: _detectedObjects.length,
//                     itemBuilder: (context, index) {
//                       final detectedObject = _detectedObjects[index];

//                       // Check if there are any labels and display them
//                       final labelText = detectedObject.labels.isNotEmpty
//                           ? detectedObject.labels[0].text
//                           : 'Unknown';

//                       final confidence = detectedObject.labels.isNotEmpty
//                           ? detectedObject.labels[0].confidence.toStringAsFixed(2)
//                           : 'N/A';

//                       return ListTile(
//                         title: Text("Object: $labelText"),
//                         subtitle: Text("Confidence: $confidence"),
//                       );
//                     },
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
