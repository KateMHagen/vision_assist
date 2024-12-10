import 'package:flutter/material.dart';

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return scaffold();
  }

  Scaffold scaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emergency Alarm',
          style: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.red,
        elevation: 5,
      ),
      body: bellicon(),
    );
  }

  Center bellicon() {
    return Center(
      child: IconButton(
        icon: Icon(Icons.notifications), //bell notification
        iconSize: 80,
        color: Colors.redAccent,
        onPressed: () {
          // Action to perform on press
          print('Bell button pressed!');
        },
      ),
    );
  }
}
