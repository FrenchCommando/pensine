import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const PensineApp());
}

class PensineApp extends StatelessWidget {
  const PensineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pensine',
      theme: pensineTheme(),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
