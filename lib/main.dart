import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase.dart';
import 'raiz.dart';
import 'services/foto_service.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // `runApp` va PRIMERO y sin nada esperando delante: ver [_iniciarServicios].
  runApp(const VeridiaApp());
}

/// Arranca los servicios de los que depende la app. Devuelve `null` si todo
/// fue bien, o el motivo del fallo si no.
///
/// `Firebase.initializeApp` va dentro de un `try` a propósito. Antes se
/// esperaba suelto en `main()`, ANTES del `runApp`, y cualquier excepción
/// suya —el móvil sin red al abrir, un `firebase_options` que no case con el
/// proyecto, el plugin sin registrar en alguna plataforma— dejaba la app en
/// negro para siempre: `runApp` no llegaba a ejecutarse nunca, así que no
/// había ni interfaz ni mensaje, solo una pantalla muerta que parecía un
/// cuelgue. Ahora la app SIEMPRE pinta algo y, si falló, dice qué pasó y deja
/// reintentar sin tener que cerrarla.
///
/// `FotoService.initSupabase` ya se protege por dentro y nunca lanza: si
/// Supabase no levanta, lo único que se pierde son las fotos, y eso no puede
/// impedir entrar a la app.
Future<String?> _iniciarServicios() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, pila) {
    debugPrint('Veridia: Firebase no se pudo iniciar: $e\n$pila');
    return e.toString();
  }
  await FotoService.initSupabase();
  return null;
}

class VeridiaApp extends StatelessWidget {
  const VeridiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veridia',
      debugShowCheckedModeBanner: false,
      theme: buildVeridiaTheme(),
      home: const _Arranque(),
    );
  }
}

/// Espera a que los servicios estén listos y decide qué mostrar.
class _Arranque extends StatefulWidget {
  const _Arranque();

  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  late Future<String?> _inicio = _iniciarServicios();

  void _reintentar() => setState(() => _inicio = _iniciarServicios());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _inicio,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const VeridiaBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: VeridiaLoader(message: 'Preparando Veridia...'),
            ),
          );
        }

        final fallo = snapshot.data;
        if (fallo != null) {
          return _ArranqueFallido(detalle: fallo, onReintentar: _reintentar);
        }
        return const RaizVeridia();
      },
    );
  }
}

/// Lo que se ve cuando Firebase no levanta: un motivo y un botón, en vez de
/// una pantalla negra.
class _ArranqueFallido extends StatelessWidget {
  const _ArranqueFallido({required this.detalle, required this.onReintentar});

  final String detalle;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return VeridiaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: VeridiaColors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Veridia no pudo conectarse',
                    textAlign: TextAlign.center,
                    style: texto.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Revisa tu conexión a internet y vuelve a intentarlo. Si '
                    'sigue pasando, cierra la app y ábrela de nuevo.',
                    textAlign: TextAlign.center,
                    style: texto.bodyMedium?.copyWith(
                      color: VeridiaColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  VeridiaBotonTactil(
                    radius: VeridiaRadii.pill,
                    child: FilledButton.icon(
                      onPressed: onReintentar,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // El detalle técnico va al final y apagado: no le sirve a
                  // quien usa la app, pero es lo único que permite entender un
                  // fallo del que solo llega una captura de pantalla.
                  Text(
                    detalle,
                    textAlign: TextAlign.center,
                    style: texto.bodySmall?.copyWith(
                      fontSize: 11,
                      color: VeridiaColors.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
