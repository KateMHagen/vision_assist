import 'package:flutter/material.dart';

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emergency Alarm',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.red,
        elevation: 5,
      ),
      body: Center( // Ensures the Column is centered in the parent
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrinks the column to fit its children
          mainAxisAlignment: MainAxisAlignment.center, // Centers items along the vertical axis
          children: [
            // Bell Icon Button
            IconButton(
              icon: Icon(Icons.notifications), // Bell notification icon
              iconSize: 80,
              color: Colors.redAccent,
              onPressed: () {
                print('Alarm triggered!');
              },
            ),
            SizedBox(height: 50), // Space between bell icon and buttons

            // Emergency Contact Button 1
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Emergency Contact: John Doe')),
                );
                print('Contact 1');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 243, 89, 33), // Background color
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text('Contac 1'),
            ),
            SizedBox(height: 20), // Space between the buttons

            // Emergency Contact Button 2
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Emergency Contact: Jane Smith')),
                );
                print('Contact 2');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 243, 89, 33), // Background color
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text('Contact 2'),
            ),
          ],
        ),
      ),
    );
  }
}
