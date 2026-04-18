import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'theme.dart';
import 'widgets/marble_board.dart';

const bool _kDisablePhysics =
    bool.fromEnvironment('DISABLE_PHYSICS', defaultValue: false);

void main() {
  if (_kDisablePhysics) debugPauseMarblePhysics = true;
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
    final loaded = (prefs.getBool('dark_mode') ?? true)
        ? Brightness.dark
        : Brightness.light;
    if (loaded != _brightness) setState(() => _brightness = loaded);
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
