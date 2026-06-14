import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ControlPage extends StatefulWidget {
  final String siteId; // "A" or "B"

  const ControlPage({super.key, required this.siteId});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  bool _isAutoMode = true; // Default
  bool _manualHumidifier = false;
  bool _manualExhaust = false;
  bool _manualUV = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    String basePath = 'Site_${widget.siteId}';

    // Listen to Mode
    _dbRef.child('$basePath/settings/control_mode').onValue.listen((event) {
      final val = event.snapshot.value;
      if (mounted) {
        setState(() {
          _isAutoMode = (val == 'auto');
        });
      }
    });

    // Listen to Manual Button States (so UI stays in sync)
    _dbRef.child('$basePath/manual_controls').onValue.listen((event) {
      final val = event.snapshot.value as Map?;
      if (val != null && mounted) {
        setState(() {
          _manualHumidifier = val['humidifier'] ?? false;
          _manualExhaust = val['exhaust_fan'] ?? false;
          _manualUV = val['uv_light'] ?? false;
        });
      }
    });
  }

  void _toggleMode(bool isAuto) {
    String mode = isAuto ? 'auto' : 'manual';
    _dbRef.child('Site_${widget.siteId}/settings/control_mode').set(mode);
  }

  void _updateManualControl(String device, bool value) {
    _dbRef.child('Site_${widget.siteId}/manual_controls/$device').set(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Control Site ${widget.siteId}"),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- MASTER SWITCH ---
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "System Mode",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: Text(
                      _isAutoMode ? "Automation Active" : "Manual Control",
                    ),
                    subtitle: Text(
                      _isAutoMode
                          ? "System controls environment based on sensors."
                          : "You control the relays manually.",
                    ),
                    secondary: Icon(
                      _isAutoMode ? Icons.smart_toy : Icons.gamepad,
                    ),
                    value: _isAutoMode,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      _toggleMode(val);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- MANUAL CONTROLS (Only visible if Manual Mode) ---
          if (!_isAutoMode) ...[
            const Text(
              "Manual Overrides",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _buildControlTile("Humidifier & Blow Fan", _manualHumidifier, (
              val,
            ) {
              _updateManualControl('humidifier', val);
            }, Icons.water_drop),

            _buildControlTile("Exhaust Fan", _manualExhaust, (val) {
              _updateManualControl('exhaust_fan', val);
            }, Icons.wind_power),

            _buildControlTile("UV Light", _manualUV, (val) {
              _updateManualControl('uv_light', val);
            }, Icons.lightbulb),

            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Note: Water Pump is always automated for safety.",
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 50.0),
                child: Text(
                  "Switch to Manual Mode to enable buttons.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlTile(
    String title,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        secondary: Icon(icon, color: value ? Colors.blue : Colors.grey),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
