import 'package:flutter/material.dart';

import 'models/recompensa.dart';
import 'models/user.dart';
import 'navegacion.dart';
import 'services/repositorio_r.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

/// Tienda de Veridiums: responde a "¿para qué sirven las monedas?".
///
/// Muestra el saldo, cómo se gana, qué se puede canjear y qué ya se canjeó.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recompensas'),
        actions: [
          ValueListenableBuilder<UserProfile?>(
            valueListenable: UserRepository.instance.currentUser,
            builder: (context, perfil, _) =>
                VeridiaTokenBadge(tokens: perfil?.tokens ?? 0),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<UserProfile?>(
            valueListenable: UserRepository.instance.currentUser,
            builder: (context, perfil, _) {
              final saldo = perfil?.tokens ?? 0;
              return ValueListenableBuilder<List<Canje>>(
                valueListenable: RewardRepository.instance.misCanjes,
                builder: (context, canjes, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _CabeceraSaldo(saldo: saldo, canjes: canjes.length),
                    const SizedBox(height: 24),
                    const VeridiaSectionTitle(
                      title: 'Catálogo',
                      subtitle: 'Cambia tus Veridiums por reconocimientos',
                    ),
                    ...catalogoRecompensas.map(
                      (recompensa) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TarjetaRecompensa(
                          recompensa: recompensa,
                          saldo: saldo,
                          yaCanjeada: RewardRepository.instance.yaCanjeada(
                            recompensa.id,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const VeridiaSectionTitle(
                      title: 'Mis canjes',
                      subtitle: 'Historial de lo que has reclamado',
                    ),
                    if (canjes.isEmpty)
                      const VeridiaEmptyState(
                        icon: Icons.card_giftcard_outlined,
                        title: 'Todavía no has canjeado nada',
                        message:
                            'Verifica fotos con la IA y completa desafíos para '
                            'ganar Veridiums.',
                      )
                    else
                      ...canjes.map(
                        (canje) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _FilaCanje(canje: canje),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CabeceraSaldo extends StatelessWidget {
  const _CabeceraSaldo({required this.saldo, required this.canjes});

  final int saldo;
  final int canjes;

  /// Siguiente recompensa que el explorador todavía no puede pagar: da una
  /// meta concreta en vez de un saldo suelto.
  Recompensa? get _siguiente {
    for (final recompensa in catalogoRecompensas) {
      if (recompensa.costo > saldo) return recompensa;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final siguiente = _siguiente;

    return VeridiaCard(
      glow: true,
      padding: const EdgeInsets.all(20),
      borderColor: VeridiaColors.veridium.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VeridiaColors.veridium.withValues(alpha: 0.16),
                  border: Border.all(
                    color: VeridiaColors.veridium.withValues(alpha: 0.6),
                  ),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: VeridiaColors.veridium,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu saldo', style: text.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      '$saldo Veridiums',
                      style: text.headlineSmall?.copyWith(
                        color: VeridiaColors.veridium,
                      ),
                    ),
                  ],
                ),
              ),
              VeridiaTag(
                label: '$canjes canjes',
                icon: Icons.redeem_rounded,
                color: VeridiaColors.secondary,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ganas 1 Veridium por cada foto que la IA verifica y un bono extra '
            'al completar un desafío.',
            style: text.bodySmall,
          ),
          if (siguiente != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Siguiente: ${siguiente.nombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge,
                  ),
                ),
                Text(
                  'faltan ${siguiente.costo - saldo}',
                  style: text.labelSmall?.copyWith(
                    color: VeridiaColors.veridium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            VeridiaProgressBar(
              value: siguiente.costo == 0 ? 1 : saldo / siguiente.costo,
              color: VeridiaColors.veridium,
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaRecompensa extends StatefulWidget {
  const _TarjetaRecompensa({
    required this.recompensa,
    required this.saldo,
    required this.yaCanjeada,
  });

  final Recompensa recompensa;
  final int saldo;
  final bool yaCanjeada;

  @override
  State<_TarjetaRecompensa> createState() => _TarjetaRecompensaState();
}

class _TarjetaRecompensaState extends State<_TarjetaRecompensa> {
  bool _procesando = false;

  Future<void> _confirmarCanje() async {
    final recompensa = widget.recompensa;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(recompensa.icono, color: recompensa.color, size: 28),
        title: Text('Canjear ${recompensa.nombre}'),
        content: Text(
          '${recompensa.descripcion}\n\n'
          'Se descontarán ${recompensa.costo} Veridiums de tu saldo '
          '(${widget.saldo} a ${widget.saldo - recompensa.costo}) y la '
          'recibes al instante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          VeridiaBotonTactil(
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Canjear'),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _procesando = true);
    final resultado = await RewardRepository.instance.canjear(recompensa);
    if (!mounted) return;
    setState(() => _procesando = false);

    switch (resultado) {
      case ResultadoCanje.exito:
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: VeridiaColors.primaryContainer,
            content: Text(
              recompensa.tipo.cambiaElPerfil
                  ? '¡Listo! "${recompensa.nombre}" ya aparece en tu perfil.'
                  : '¡Listo! "${recompensa.nombre}" quedó reclamada.',
            ),
          ),
        );
      case ResultadoCanje.sinSaldo:
        messenger.showSnackBar(
          veridiaSnackBarError('No te alcanzan los Veridiums para esto.'),
        );
      case ResultadoCanje.yaLaTienes:
        messenger.showSnackBar(
          veridiaSnackBarError('Ya tienes esta recompensa.'),
        );
      case ResultadoCanje.sinSesion:
        messenger.showSnackBar(
          veridiaSnackBarError('Inicia sesión para canjear.'),
        );
      case ResultadoCanje.error:
        messenger.showSnackBar(
          veridiaSnackBarError(
            'No se pudo completar el canje. Intenta de nuevo.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final recompensa = widget.recompensa;
    final alcanza = widget.saldo >= recompensa.costo;
    final bloqueada = widget.yaCanjeada;

    return VeridiaCard(
      borderColor: bloqueada
          ? VeridiaColors.primary.withValues(alpha: 0.45)
          : alcanza
          ? recompensa.color.withValues(alpha: 0.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: recompensa.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(VeridiaRadii.md),
                  border: Border.all(
                    color: recompensa.color.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  recompensa.icono,
                  color: recompensa.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recompensa.nombre, style: text.titleSmall),
                    const SizedBox(height: 4),
                    Text(recompensa.descripcion, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              VeridiaTag(
                label: recompensa.tipo.etiqueta,
                color: recompensa.color,
                dense: true,
              ),
              const SizedBox(width: 8),
              VeridiaTokenBadge(tokens: recompensa.costo),
              const Spacer(),
              if (bloqueada)
                const VeridiaTag(
                  label: 'Obtenida',
                  icon: Icons.check_rounded,
                  dense: true,
                )
              else
                VeridiaBotonTactil(
                  child: FilledButton(
                    onPressed: alcanza && !_procesando ? _confirmarCanje : null,
                    child: _procesando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            alcanza
                                ? 'Canjear'
                                : 'Faltan ${recompensa.costo - widget.saldo}',
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaCanje extends StatelessWidget {
  const _FilaCanje({required this.canje});

  final Canje canje;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final recompensa = canje.recompensa;

    return VeridiaCard(
      child: Row(
        children: [
          Icon(
            recompensa?.icono ?? Icons.redeem_rounded,
            color: recompensa?.color ?? VeridiaColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(canje.nombre, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${formatoFecha(canje.fecha)} · '
                  '-${canje.costo} Veridiums',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          VeridiaTag(
            label: canje.estado.etiqueta,
            color: canje.estado.color,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Atajo para abrir la tienda desde cualquier pantalla del explorador.
void abrirRecompensas(BuildContext context) {
  VeridiaNav.abrir(context, const RewardsScreen());
}
