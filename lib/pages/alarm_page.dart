import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class EmergencyAlarmPage extends StatefulWidget {
  const EmergencyAlarmPage({super.key});

  @override
  State<EmergencyAlarmPage> createState() => _EmergencyAlarmPageState();
}

class _EmergencyAlarmPageState extends State<EmergencyAlarmPage> {
  final TextEditingController _contact1Controller = TextEditingController();
  final TextEditingController _contact2Controller = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _loadSavedContacts();
  }

  Future<void> _loadSavedContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _contact1Controller.text = prefs.getString('contact1') ?? '';
    _contact2Controller.text = prefs.getString('contact2') ?? '';
  }

  Future<void> _saveContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('contact1', _contact1Controller.text.trim());
    await prefs.setString('contact2', _contact2Controller.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Contacts saved successfully")),
    );
    FocusScope.of(context).unfocus(); // Dismiss keyboard after saving
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _sendEmergencyMessage() async {
    await _flutterTts.speak("Sending alert to first contact");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String contact1 = prefs.getString('contact1') ?? '';
    String contact2 = prefs.getString('contact2') ?? '';

    List<String> contacts =
        [contact1, contact2].where((c) => c.isNotEmpty).toList();

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No valid contacts to send message.")),
      );
      return;
    }

    Position? position = await _getCurrentLocation();

    String locationUrl = position != null
        ? " I'm here: https://maps.google.com/?q=${position.latitude},${position.longitude}"
        : "";

    String message = Uri.encodeComponent(
      "🚨 Emergency! I need help.$locationUrl",
    );

    for (int i = 0; i < contacts.length; i++) {
      final uri = Uri.parse("sms:${contacts[i]}?body=$message");

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        // Wait for user to come back to the app
        if (i == 0 && contacts.length > 1) {
          await _flutterTts.speak("Sending alert to second contact.");
          await Future.delayed(const Duration(seconds: 5));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch SMS for ${contacts[i]}.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _contact1Controller.dispose();
    _contact2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Alarm'),
          backgroundColor: Colors.red[700],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Emergency Contacts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildContactInput(
                controller: _contact1Controller,
                label: "Contact 1",
              ),
              const SizedBox(height: 12),
              _buildContactInput(
                controller: _contact2Controller,
                label: "Contact 2",
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _saveContacts,
                  icon: const Icon(Icons.save),
                  label: const Text("Save Contacts"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              const Divider(thickness: 1.2),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _sendEmergencyMessage,
                  icon: const Icon(Icons.warning_amber_outlined, size: 32),
                  label: const Text("🚨 SEND ALARM"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 20),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactInput(
      {required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(), // hide keyboard
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }
}
