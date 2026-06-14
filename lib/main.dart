import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'sensordata.dart'; // Your Environment Page
import 'automation.dart'; // New Automation Page (code provided below)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Mushroom Farm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const LoginPage(), // Start at Login Page
    );
  }
}

// --- PAGE 1: LOGIN ---
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController userController = TextEditingController();
    final TextEditingController passController = TextEditingController();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.spa, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Smart Mushroom Farm",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: userController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
              onPressed: () {
                // Simple Dummy Login - Replace with real auth if needed
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SiteSelectionPage(),
                  ),
                );
              },
              child: const Text("LOGIN", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAGE 2: CHOOSE SITE (Site A / Site B) ---
class SiteSelectionPage extends StatelessWidget {
  const SiteSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Site"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed:
                () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _siteButton(context, "Site A", "Site_A"),
            const SizedBox(height: 20),
            _siteButton(context, "Site B", "Site_B"),
          ],
        ),
      ),
    );
  }

  Widget _siteButton(BuildContext context, String label, String dbNodeName) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    ModeSelectionPage(siteId: dbNodeName, siteName: label),
          ),
        );
      },
      child: Text(label, style: const TextStyle(fontSize: 20)),
    );
  }
}

// --- PAGE 3/4: CHOOSE MODE (Environment / Automation) ---
class ModeSelectionPage extends StatelessWidget {
  final String siteId; // e.g., "Site_A"
  final String siteName; // e.g., "Site A"

  const ModeSelectionPage({
    super.key,
    required this.siteId,
    required this.siteName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$siteName Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeButton(context, "Environment", Icons.thermostat, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SensorDataPage(siteId: siteId),
                ),
              );
            }),
            const SizedBox(height: 20),
            _modeButton(context, "Automation", Icons.settings_remote, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AutomationPage(siteId: siteId),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }
}
