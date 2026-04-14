import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const PensineApp());
}

class PensineApp extends StatefulWidget {
  const PensineApp({super.key});

  static PensineAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<PensineAppState>();

  @override
  State<PensineApp> createState() => PensineAppState();
}

class PensineAppState extends State<PensineApp> {
  Brightness _brightness = Brightness.dark;

  Brightness get brightness => _brightness;

  @override
  void initState() {
    super.initState();
    _loadBrightness();
  }

  Future<void> _loadBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? true;
    setState(() => _brightness = isDark ? Brightness.dark : Brightness.light);
  }

  void toggleBrightness() async {
    final next = _brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    setState(() => _brightness = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', next == Brightness.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pensine',
      theme: pensineTheme(brightness: _brightness),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
