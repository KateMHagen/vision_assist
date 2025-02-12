import 'package:flutter/material.dart';
import 'package:vision_assist/pages/alarm_page.dart';
import 'package:vision_assist/pages/gps_page.dart';
import 'package:vision_assist/pages/object_detection_page.dart';
import 'package:vision_assist/pages/ocr_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void  main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures the app initializes properly
  await dotenv.load(fileName: ".env"); // Load environment variables
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
      
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int selectedIndex = 0; 

  final List<Widget> _pages = [
    ObjectDetectionPage(),
    OCRPage(),
    GPSPage(),
    AlarmPage(),
  ];

  @override
   Widget build(BuildContext context) {
    
    return Scaffold(
      body: _pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            selectedIndex = index;
          });
        },
        indicatorColor: Colors.amber,
        selectedIndex: selectedIndex,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            label: 'Object Detection',
          ),
          NavigationDestination(
            icon: Icon(Icons.font_download),
            label: 'Text to Speech',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'GPS',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm),
            label: 'Alarm',
          ),
        ],
      )
    );
      
  
  
  }
}




