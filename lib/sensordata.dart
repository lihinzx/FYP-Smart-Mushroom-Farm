import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'settings.dart'; // <--- Import the settings page

class SensorDataPage extends StatefulWidget {
  final String siteId; // e.g., "Site_A"

  const SensorDataPage({super.key, required this.siteId});

  @override
  State<SensorDataPage> createState() => _SensorDataPageState();
}

class _SensorDataPageState extends State<SensorDataPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  String _temperature = 'Loading...';
  String _humidity = 'Loading...';
  String _co2 = 'Loading...';
  String _lux = 'Loading...';
  String _waterLevel = 'Loading...';

  @override
  void initState() {
    super.initState();
    _listenToSensorData();
  }

  void _listenToSensorData() {
    String basePath = '${widget.siteId}/sensor';

    _databaseRef.child('$basePath/temperature').onValue.listen((event) {
      setState(() => _temperature = '${event.snapshot.value ?? 0} °C');
    });

    _databaseRef.child('$basePath/humidity').onValue.listen((event) {
      setState(() => _humidity = '${event.snapshot.value ?? 0} %');
    });

    _databaseRef.child('$basePath/co2').onValue.listen((event) {
      setState(() => _co2 = '${event.snapshot.value ?? 0} ppm');
    });

    _databaseRef.child('$basePath/lux').onValue.listen((event) {
      setState(() => _lux = '${event.snapshot.value ?? 0} lx');
    });

    _databaseRef.child('$basePath/water_level_status').onValue.listen((event) {
      setState(() => _waterLevel = '${event.snapshot.value ?? "Unknown"}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Environment (${widget.siteId.replaceAll('_', ' ')})'),
        backgroundColor: Colors.green.shade600,
        actions: [
          // --- SETTINGS BUTTON (Change Growth Mode) ---
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Growth Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(siteId: widget.siteId),
                ),
              );
            },
          ),
          // --- GRAPH BUTTON (Placeholder) ---
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'View Graphs',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Graph Page Coming Soon!")),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildSensorCard(
              title: 'Temperature',
              value: _temperature,
              icon: Icons.thermostat,
              color1: Colors.orangeAccent,
              color2: Colors.deepOrange,
            ),
            const SizedBox(height: 16),
            _buildSensorCard(
              title: 'Humidity',
              value: _humidity,
              icon: Icons.water_drop,
              color1: Colors.lightBlueAccent,
              color2: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildSensorCard(
              title: 'CO2 Level',
              value: _co2,
              icon: Icons.eco,
              color1: Colors.greenAccent,
              color2: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildSensorCard(
              title: 'Lux',
              value: _lux,
              icon: Icons.wb_sunny,
              color1: Colors.yellow.shade700,
              color2: Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildSensorCard(
              title: 'Water Level',
              value: _waterLevel,
              icon: Icons.water,
              color1: Colors.cyanAccent,
              color2: Colors.cyan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color1,
    required Color color2,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
