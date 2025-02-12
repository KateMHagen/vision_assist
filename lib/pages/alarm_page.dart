import 'package:flutter/material.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class AlarmPage extends StatefulWidget {
  @override
  _AlarmPageState createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {


  final AudioPlayer _audioPlayer = AudioPlayer();
  late TwilioFlutter twilioFlutter;

  @override
  void initState() {
    super.initState();
    twilioFlutter = TwilioFlutter(
      accountSid: dotenv.env['ACCOUNT_SID']!,
      authToken: dotenv.env['AUTH_TOKEN']!,
      twilioNumber: "+18556081521", // Ensure this matches your Twilio account
    );
  }

  void sendSms() async {
    try {
      await twilioFlutter.sendSMS(
        toNumber: "+18024889571",
        messageBody: 'Emergency rescue',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emergency SMS sent successfully!')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SMS: $error')),
      );
    }
  }

  void playAlarmSound() async {
    try {
      await _audioPlayer.play(AssetSource('alarm.mp3'));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play alarm sound: $error')),
      );
    }
  }

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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications),
              iconSize: 80,
              color: Colors.redAccent,
              onPressed: playAlarmSound,
            ),
            SizedBox(height: 50),
            ElevatedButton(
              onPressed: sendSms,
              child: Text("Send Emergency SMS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 243, 89, 33),
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Emergency Contact: Jane Smith')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 243, 89, 33),
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
