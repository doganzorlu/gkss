import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/sandik_sayim_app.dart';
import 'features/election/application/election_service.dart';
import 'features/election/data/election_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final service = ElectionService(ElectionDatabase());
  await service.initialize();

  runApp(SandikSayimApp(service: service));
}
