import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SettingsPage extends StatefulWidget {
  final String siteId; // e.g., "Site_A"
  const SettingsPage({super.key, required this.siteId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  String _currentMode = "unknown"; // "spawn_run", "pin_head", or "cropping"

  @override
  void initState() {
    super.initState();
    _listenToMode();
  }

  void _listenToMode() {
    // Listen to the currently selected mode in Firebase
    _databaseRef.child('${widget.siteId}/settings/growth_mode').onValue.listen((
      event,
    ) {
      final val = event.snapshot.value.toString();
      setState(() {
        _currentMode = val;
      });
    });
  }

  void _setMode(String modeCode) {
    // Write the selected mode to Firebase
    _databaseRef.child('${widget.siteId}/settings/growth_mode').set(modeCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Growth Mode Settings"),
        backgroundColor: Colors.green.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Select Current Growth Stage:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildModeButton(
              "Spawn-Run Mode",
              "spawn_run",
              Icons.catching_pokemon,
            ),
            const SizedBox(height: 20),
            _buildModeButton("Pin Head Initiation", "pin_head", Icons.grain),
            const SizedBox(height: 20),
            _buildModeButton("Cropping Mode", "cropping", Icons.local_florist),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, String modeCode, IconData icon) {
    bool isActive = _currentMode == modeCode;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.green : Colors.white,
        foregroundColor: isActive ? Colors.white : Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.green, width: 2),
      ),
      onPressed: () => _setMode(modeCode),
      icon: Icon(icon, size: 30),
      label: Text(label, style: const TextStyle(fontSize: 22)),
    );
  }
}
