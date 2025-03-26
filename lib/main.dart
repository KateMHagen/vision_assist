import 'package:flutter/material.dart';
import 'package:vision_assist/pages/alarm_page.dart';
import 'package:vision_assist/pages/gps_page.dart';
import 'package:vision_assist/pages/object_detection_page.dart';
import 'package:vision_assist/pages/ocr_page.dart';
import 'package:vision_assist/pages/splash_screen.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Assist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Vision Assist'),
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
    ObjectClassificationPage(),
    OCRPage(),
    GPSPage(),
    EmergencyAlarmPage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _pages[selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 75,
          backgroundColor: Colors.deepPurple[50],
          indicatorColor: Colors.deepPurple[200],
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          iconTheme: MaterialStateProperty.all(
            const IconThemeData(size: 28),
          ),
        ),
        child: NavigationBar(
          onDestinationSelected: (int index) {
            setState(() {
              selectedIndex = index;
            });
          },
          selectedIndex: selectedIndex,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              label: 'Objects',
            ),
            NavigationDestination(
              icon: Icon(Icons.font_download),
              label: 'TTS',
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
        ),
      ),
    );
  }
}
