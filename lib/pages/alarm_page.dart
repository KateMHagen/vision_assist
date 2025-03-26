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

class _EmergencyAlarmPageState extends State<EmergencyAlarmPage>
    with WidgetsBindingObserver {
  final TextEditingController _contact1Controller = TextEditingController();
  final TextEditingController _contact2Controller = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _secondContactPending = false;
  bool _firstTTSPending = false;

  @override
  void initState() {
    super.initState();
    _loadSavedContacts();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contact1Controller.dispose();
    _contact2Controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_firstTTSPending) {
        _flutterTts.speak("Alert sent to first contact");
        _firstTTSPending = false;
      }
      if (_secondContactPending) {
        _sendSecondContact();
      }
    }
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
    FocusScope.of(context).unfocus();
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String contact1 = prefs.getString('contact1') ?? '';
    String contact2 = prefs.getString('contact2') ?? '';

    Position? position = await _getCurrentLocation();
    String locationUrl = position != null
        ? " I'm here: https://maps.google.com/?q=${position.latitude},${position.longitude}"
        : "";

    String message = Uri.encodeComponent(
      "🚨 Emergency! I need help.$locationUrl",
    );

    if (contact1.isNotEmpty) {
      final uri1 = Uri.parse("sms:$contact1?body=$message");

      if (await canLaunchUrl(uri1)) {
        _secondContactPending = contact2.isNotEmpty;
        _firstTTSPending = true;
        await launchUrl(uri1);
      }
    } else if (contact2.isNotEmpty) {
      final uri2 = Uri.parse("sms:$contact2?body=$message");

      if (await canLaunchUrl(uri2)) {
        await launchUrl(uri2);
        await _flutterTts.speak("Alert sent to first contact");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No valid contacts to send message.")),
      );
    }
  }

  Future<void> _sendSecondContact() async {
    _secondContactPending = false;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String contact2 = prefs.getString('contact2') ?? '';
    if (contact2.isEmpty) return;

    Position? position = await _getCurrentLocation();
    String locationUrl = position != null
        ? " I'm here: https://maps.google.com/?q=${position.latitude},${position.longitude}"
        : "";

    String message = Uri.encodeComponent(
      "🚨 Emergency! I need help.$locationUrl",
    );

    final uri2 = Uri.parse("sms:$contact2?body=$message");
    if (await canLaunchUrl(uri2)) {
      await launchUrl(uri2);
      await _flutterTts.speak("Alert sent to second contact");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color alarmRed = Colors.red.shade600;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              title: const Text(
                'Emergency Alarm',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 4,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Emergency Contacts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.shade100,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildContactInput(
                      controller: _contact1Controller,
                      label: "Contact 1",
                    ),
                    const SizedBox(height: 16),
                    _buildContactInput(
                      controller: _contact2Controller,
                      label: "Contact 2",
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _saveContacts,
                      icon: const Icon(Icons.save),
                      label: const Text("Save Contacts"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Divider(thickness: 1.2),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _sendEmergencyMessage,
                  icon: const Icon(Icons.warning_amber_outlined, size: 32),
                  label: const Text("🚨 SEND ALARM"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: alarmRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 20),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
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

  Widget _buildContactInput({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.phone),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }
}
