import 'package:app_settings/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

/// Seguridad de la cuenta + qué datos recolecta Veridia y para qué.
///
/// Antes este botón solo abría los ajustes del sistema operativo (que no
/// tienen nada que ver con "privacidad de la cuenta"). Aquí sí hace algo
/// real: dispara el correo de recuperación de contraseña de Firebase Auth
/// y explica honestamente el manejo de datos de la app.
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _enviandoCorreo = false;

  String? get _email => FirebaseAuth.instance.currentUser?.email;

  Future<void> _enviarCorreoDeCambioClave() async {
    final email = _email;
    if (email == null || email.isEmpty) {
      mostrarMensajeVeridia(
        context,
        'Tu cuenta no tiene un correo asociado (¿iniciaste con Google?).',
        esError: true,
      );
      return;
    }

    setState(() => _enviandoCorreo = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      mostrarMensajeVeridia(context, 'Te enviamos un correo a $email.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      mostrarMensajeVeridia(
        context,
        e.code == 'user-not-found'
            ? 'No encontramos una cuenta con ese correo.'
            : 'No se pudo enviar el correo: ${e.message}',
        esError: true,
      );
    } catch (e) {
      if (!mounted) return;
      mostrarMensajeVeridia(
        context,
        'No se pudo enviar el correo de recuperación.',
        esError: true,
      );
    } finally {
      if (mounted) setState(() => _enviandoCorreo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y seguridad')),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const VeridiaSectionTitle(
                title: 'Seguridad de la cuenta',
                subtitle: 'Correo asociado y cambio de contraseña',
              ),
              VeridiaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline,
                          size: 18,
                          color: VeridiaColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _email ?? 'Cuenta de Google (sin contraseña)',
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _email == null || _enviandoCorreo
                            ? null
                            : _enviarCorreoDeCambioClave,
                        icon: _enviandoCorreo
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_reset, size: 18),
                        label: Text(
                          _enviandoCorreo
                              ? 'Enviando...'
                              : 'Cambiar contraseña por correo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const VeridiaSectionTitle(
                title: 'Tus datos en Veridia',
                subtitle: 'Qué guardamos y para qué lo usamos',
              ),
              const VeridiaCard(
                child: Column(
                  children: [
                    _FilaDato(
                      icon: Icons.photo_camera_outlined,
                      titulo: 'Fotos de tus avistamientos',
                      detalle:
                          'Se guardan en almacenamiento en la nube (Supabase) '
                          'y se envían a la IA de Google (Gemini) solo para '
                          'identificar la especie. No se comparten con otros '
                          'usuarios más allá de tu diario y el mapa público '
                          'de avistamientos.',
                    ),
                    Divider(height: 24),
                    _FilaDato(
                      icon: Icons.my_location_outlined,
                      titulo: 'Ubicación aproximada',
                      detalle:
                          'Se usa para ubicar tus avistamientos en el mapa y '
                          'sugerir zonas de exploración cercanas. Puedes '
                          'negarla desde los permisos del sistema.',
                    ),
                    Divider(height: 24),
                    _FilaDato(
                      icon: Icons.badge_outlined,
                      titulo: 'Correo y nombre',
                      detalle:
                          'Identifican tu cuenta (Firebase Authentication) y '
                          'se muestran a los administradores para gestionar '
                          'desafíos y moderación.',
                    ),
                    Divider(height: 24),
                    _FilaDato(
                      icon: Icons.savings_outlined,
                      titulo: 'Veridiums y progreso',
                      detalle:
                          'Tu saldo y avance en desafíos se guardan en la '
                          'base de datos (Firestore) para el ranking y tu '
                          'perfil.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const VeridiaSectionTitle(
                title: 'Permisos del dispositivo',
                subtitle: 'Cámara, galería y ubicación',
              ),
              VeridiaCard(
                onTap: () => AppSettings.openAppSettings(),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VeridiaColors.secondary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(VeridiaRadii.sm),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: VeridiaColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Abrir ajustes del sistema',
                            style: text.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Revisa o revoca permisos de cámara y ubicación.',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: VeridiaColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.icon,
    required this.titulo,
    required this.detalle,
  });

  final IconData icon;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: VeridiaColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: text.titleSmall),
              const SizedBox(height: 4),
              Text(detalle, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
