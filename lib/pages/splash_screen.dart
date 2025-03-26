import 'package:flutter/material.dart';
import 'package:vision_assist/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _curtainOpened = false;

  void _onTap() {
    setState(() {
      _curtainOpened = true;
    });

    // After animation ends, navigate to main app
    Future.delayed(const Duration(milliseconds: 1200), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MyApp()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: _onTap,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 109, 94, 144),
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icon.png', height: 120),
                  const SizedBox(height: 20),
                  const Text(
                    "Vision Assist",
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 60),
                  if (!_curtainOpened)
                    const Text(
                      "Tap to enter",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            // Left curtain
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
              left: _curtainOpened ? -screenWidth / 2 : 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: screenWidth / 2,
                color: const Color.fromARGB(255, 81, 66, 145),
              ),
            ),

            // Right curtain
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
              right: _curtainOpened ? -screenWidth / 2 : 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: screenWidth / 2,
                color: const Color.fromARGB(255, 81, 66, 145),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
