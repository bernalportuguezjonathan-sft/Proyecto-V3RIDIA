import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase.dart';
import 'raiz.dart';
import 'services/foto_service.dart';
import 'theme/veridia_theme.dart';

// Convertimos el main en 'async' porque iniciar Firebase toma un instante
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FotoService.initSupabase();

  runApp(const VeridiaApp());
}

class VeridiaApp extends StatelessWidget {
  const VeridiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veridia',
      debugShowCheckedModeBanner: false,
      theme: buildVeridiaTheme(),
      home: const RaizVeridia(),
    );
  }
}
