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
          return const WelcomeScreen();
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
