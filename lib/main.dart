import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const IDRApp());
}

class IDRApp extends StatelessWidget {
  const IDRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dhuruva INS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
