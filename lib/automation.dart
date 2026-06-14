import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AutomationPage extends StatefulWidget {
  final String siteId;
  const AutomationPage({super.key, required this.siteId});

  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // System Mode
  bool isAutoMode = true;

  // Device States
  bool humidifier = false;
  bool blowFan = false;
  bool exhaustFan = false;
  bool uvLight = false;
  bool waterPump = false;

  @override
  void initState() {
    super.initState();
    _listenToMode();
    _listenToDevices();
  }

  // 1. Listen to "Auto" vs "Manual" mode
  void _listenToMode() {
    String path = '${widget.siteId}/settings/control_mode';
    _databaseRef.child(path).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final val = event.snapshot.value.toString();
        if (mounted) {
          setState(() {
            isAutoMode = (val == "auto");
          });
        }
      }
    });
  }

  // 2. Listen to Sensor Status (Updates the UI when Pi responds)
  void _listenToDevices() {
    String path = '${widget.siteId}/sensor';
    _listenToSwitch('$path/humidifier_status', (val) => humidifier = val);
    _listenToSwitch('$path/blow_fan_status', (val) => blowFan = val);
    _listenToSwitch('$path/exhaust_fan_status', (val) => exhaustFan = val);
    _listenToSwitch('$path/uv_light_status', (val) => uvLight = val);
    _listenToSwitch('$path/water_pump_status', (val) => waterPump = val);
  }

  void _listenToSwitch(String path, Function(bool) updateVar) {
    _databaseRef.child(path).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final val = event.snapshot.value.toString();
        if (mounted) {
          setState(() {
            updateVar(val == "ON");
          });
        }
      }
    });
  }

  // 3. Update UI Locally then send to Firebase
  void _toggleDevice(
    String key,
    bool currentValue,
    Function(bool) updateLocal,
  ) {
    if (isAutoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Disable Automation to use Manual Control"),
          duration: Duration(milliseconds: 500),
        ),
      );
      return;
    }

    setState(() {
      updateLocal(!currentValue);
    });

    String path = '${widget.siteId}/manual_controls/$key';
    _databaseRef.child(path).set(!currentValue);
  }

  // 4. Change System Mode
  void _changeMode(bool newIsAuto) {
    String mode = newIsAuto ? "auto" : "manual";
    _databaseRef.child('${widget.siteId}/settings/control_mode').set(mode);
    Navigator.pop(context);
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "System Mode",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.smart_toy, color: Colors.green),
                title: const Text("Automation Mode"),
                subtitle: const Text("Sensors control relays"),
                trailing:
                    isAutoMode
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                onTap: () => _changeMode(true),
              ),
              ListTile(
                leading: const Icon(Icons.gamepad, color: Colors.blue),
                title: const Text("Manual Mode"),
                subtitle: const Text("You control switches"),
                trailing:
                    !isAutoMode
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () => _changeMode(false),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // This formats the siteId for the title (e.g., "site_a" -> "SITE A")
    String formattedSiteId = widget.siteId.replaceAll('_', ' ').toUpperCase();

    return Scaffold(
      appBar: AppBar(
        // DYNAMIC TITLE BASED ON siteId
        title: Text("Output Monitoring $formattedSiteId"),
        backgroundColor: isAutoMode ? Colors.green : Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: isAutoMode ? Colors.green.shade100 : Colors.blue.shade100,
            child: Text(
              isAutoMode
                  ? "AUTOMATION ACTIVE (Read Only)"
                  : "MANUAL CONTROL ACTIVE",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    isAutoMode ? Colors.green.shade900 : Colors.blue.shade900,
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSwitch("Humidifier", humidifier, (val) {
                  _toggleDevice(
                    "humidifier",
                    humidifier,
                    (v) => humidifier = v,
                  );
                }),

                _buildSwitch("Exhaust Fan", exhaustFan, (val) {
                  _toggleDevice(
                    "exhaust_fan",
                    exhaustFan,
                    (v) => exhaustFan = v,
                  );
                }),

                _buildSwitch("UV Light", uvLight, (val) {
                  _toggleDevice("uv_light", uvLight, (v) => uvLight = v);
                }),

                _buildSwitch("Blow Fan", blowFan, (val) {
                  _toggleDevice("blow_fan", blowFan, (v) => blowFan = v);
                }),

                const Divider(),
                ListTile(
                  leading: const Icon(Icons.water_drop, color: Colors.blue),
                  title: const Text("Water Pump Status"),
                  subtitle: Text(waterPump ? "PUMPING" : "IDLE"),
                  trailing: Switch(
                    value: waterPump,
                    onChanged: null,
                    activeColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, Function(bool) onChanged) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value ? "ON" : "OFF"),
        value: value,
        activeColor: isAutoMode ? Colors.green : Colors.blue,
        onChanged:
            isAutoMode
                ? (val) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Switch to Manual Mode first (Gear Icon)"),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
                : onChanged,
      ),
    );
  }
}
