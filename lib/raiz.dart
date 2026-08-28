import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_home.dart';
import 'banned_screen.dart';
import 'home.dart';
import 'login.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_logo.dart';
import 'widgets/veridia_montanas.dart';
import 'widgets/veridia_ui.dart';

/// Raíz de la app: decide entre bienvenida, home de explorador, panel admin o
/// pantalla de baneado según el estado de autenticación.
class RaizVeridia extends StatefulWidget {
  const RaizVeridia({super.key});

  @override
  State<RaizVeridia> createState() => _RaizVeridiaState();
}

class _RaizVeridiaState extends State<RaizVeridia> {
  /// Cacheado por uid: sin esto `initializeUser()` se relanzaría en cada
  /// rebuild del StreamBuilder, provocando reconstrucciones en bucle.
  String? _uidCargado;
  Future<void>? _cargaPerfil;

  /// Se pone en true cuando el propio usuario confirma "ya verifiqué" y el
  /// reload() de Firebase Auth lo confirma. authStateChanges() no vuelve a
  /// emitir solo porque `emailVerified` cambió, así que esta bandera es la
  /// única forma de que el StreamBuilder deje pasar a este uid sin esperar
  /// un nuevo evento del stream. Se reinicia al cerrar sesión para que la
  /// próxima cuenta sin verificar no se cuele heredando el valor anterior.
  bool _verificacionConfirmada = false;

  Future<void> _perfilDe(String uid) {
    if (_uidCargado != uid || _cargaPerfil == null) {
      _uidCargado = uid;
      _cargaPerfil = UserRepository.instance.initializeUser();
    }
    return _cargaPerfil!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          return const _PantallaCargando();
        }

        final usuario = snapshot.data;
        if (usuario == null) {
          _uidCargado = null;
          _cargaPerfil = null;
          _verificacionConfirmada = false;
          return const WelcomeScreen();
        }

        // Solo exige verificación a cuentas de correo/contraseña: quien
        // entra con Google ya lo trae verificado por Google mismo (ver
        // exigirSesion() en functions/index.js, misma regla del lado
        // servidor). Cubre tanto "recién registrado" como "reabrió la app
        // con una sesión vieja sin verificar" con la misma pantalla.
        final esCuentaConContrasena = usuario.providerData.any(
          (p) => p.providerId == 'password',
        );
        if (esCuentaConContrasena &&
            !usuario.emailVerified &&
            !_verificacionConfirmada) {
          return _VerificacionPendiente(
            onVerificado: () => setState(() => _verificacionConfirmada = true),
          );
        }

        return FutureBuilder<void>(
          future: _perfilDe(usuario.uid),
          builder: (context, initSnapshot) {
            if (initSnapshot.connectionState != ConnectionState.done) {
              return const _PantallaCargando();
            }

            final perfil = UserRepository.instance.currentUser.value;
            if (perfil?.isBanned == true) return const BannedScreen();

            return perfil?.role == 'Administrador'
                ? const AdminHomeScreen()
                : const HomeScreen();
          },
        );
      },
    );
  }
}

/// Bloquea el paso a la app mientras el correo no esté verificado.
/// Aparece justo después de registrarse y también si se reabre la app con
/// una sesión antigua que nunca llegó a confirmarse.
class _VerificacionPendiente extends StatefulWidget {
  const _VerificacionPendiente({required this.onVerificado});

  final VoidCallback onVerificado;

  @override
  State<_VerificacionPendiente> createState() => _VerificacionPendienteState();
}

class _VerificacionPendienteState extends State<_VerificacionPendiente> {
  bool _cargando = false;

  Future<void> _reenviarCorreo() async {
    setState(() => _cargando = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        mostrarMensajeVeridia(context, 'Correo de verificación reenviado.');
      }
    } catch (_) {
      if (mounted) {
        mostrarMensajeVeridia(
          context,
          'No se pudo reenviar el correo. Intenta más tarde.',
          esError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _yaVerifique() async {
    setState(() => _cargando = true);
    try {
      // reload() trae el emailVerified real desde Firebase Auth: el objeto
      // User en memoria no se actualiza solo cuando alguien hace clic en el
      // enlace del correo en otra pestaña/dispositivo.
      await FirebaseAuth.instance.currentUser?.reload();
      final actualizado = FirebaseAuth.instance.currentUser;
      if (actualizado != null && actualizado.emailVerified) {
        widget.onVerificado();
      } else if (mounted) {
        mostrarMensajeVeridia(
          context,
          'Todavía no detectamos la verificación. Revisa tu correo.',
          esError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final email = FirebaseAuth.instance.currentUser?.email ?? 'tu correo';

    return Scaffold(
      body: VeridiaMontanas(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const VeridiaSymbol(size: 92),
                    const SizedBox(height: 18),
                    Text('Verifica tu correo', style: text.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      'Te enviamos un enlace de confirmación a $email. '
                      'Ábrelo y luego vuelve aquí.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 26),
                    VeridiaCard(
                      padding: const EdgeInsets.all(20),
                      glow: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: _cargando ? null : _yaVerifique,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                            ),
                            child: _cargando
                                ? const VeridiaLoader()
                                : const Text('Ya verifiqué mi correo'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _cargando ? null : _reenviarCorreo,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                            ),
                            child: const Text('Reenviar correo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton.icon(
                      onPressed: _cargando
                          ? null
                          : () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PantallaCargando extends StatelessWidget {
  const _PantallaCargando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: VeridiaBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VeridiaSymbol(size: 92),
              SizedBox(height: 28),
              VeridiaLoader(),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: VeridiaMontanas(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 64,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const VeridiaMarcoLogo(
                        padding: EdgeInsets.fromLTRB(30, 26, 30, 22),
                        child: VeridiaLogo(size: 150),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Explora, conserva, protege',
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(
                          color: VeridiaColors.secondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 44),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.explore_outlined, size: 20),
                          label: const Text('Conocer Veridia'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 54),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Cundinamarca, Colombia',
                        style: text.labelSmall?.copyWith(
                          letterSpacing: 1.4,
                          color: VeridiaColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Identifica especies con IA y gana Veridiums.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
