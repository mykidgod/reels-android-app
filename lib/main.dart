import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/settings_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent settings (API keys, templates, custom prompts)
  final settingsService = SettingsService();
  await settingsService.init();

  // Request storage / gallery permissions on launch
  await _requestPermissions();

  runApp(RayworksReelsApp(settings: settingsService));
}

Future<void> _requestPermissions() async {
  await [
    Permission.storage,
    Permission.photos,
    Permission.videos,
  ].request();
}

class RayworksReelsApp extends StatelessWidget {
  final SettingsService settings;

  const RayworksReelsApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rayworks Reels Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1626),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0284C7),
          secondary: Color(0xFF2DD4BF),
          surface: Color(0xFF131D31),
          background: Color(0xFF0E1626),
        ),
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(settings: settings),
    );
  }
}
