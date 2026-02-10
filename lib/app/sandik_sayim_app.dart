import 'package:flutter/material.dart';

import '../features/election/application/election_service.dart';
import '../features/election/presentation/election_screen.dart';

class SandikSayimApp extends StatelessWidget {
  const SandikSayimApp({super.key, required this.service});

  final ElectionService service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOSB Genel Kurul Sayım Sistemi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A4A68)),
        useMaterial3: true,
      ),
      home: ElectionScreen(service: service),
    );
  }
}
