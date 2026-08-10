import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

/// Ranking de exploradores por Veridiums. Solo accesible para administradores
/// desde el panel de administración. Se actualiza en vivo: cuando un explorador
/// gana Veridiums su posición cambia sin recargar la pantalla.
class UsersStatusScreen extends StatefulWidget {
  const UsersStatusScreen({super.key});

  @override
  State<UsersStatusScreen> createState() => _UsersStatusScreenState();
}

class _UsersStatusScreenState extends State<UsersStatusScreen> {
  late final Stream<List<UserProfile>> _ranking = UserRepository.instance
      .streamAllUsers(role: 'Explorador', porVeridiums: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking de exploradores'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: VeridiaTag(
                label: 'En vivo',
                icon: Icons.bolt,
                color: VeridiaColors.secondary,
                dense: true,
              ),
            ),
          ),
        ],
      ),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<UserProfile>>(
            stream: _ranking,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return VeridiaEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'No se pudo cargar el ranking',
                  message: '${snapshot.error}',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const VeridiaLoader(message: 'Calculando posiciones...');
              }

              final users = snapshot.data ?? const <UserProfile>[];
              if (users.isEmpty) {
                return const VeridiaEmptyState(
                  icon: Icons.leaderboard_outlined,
                  title: 'Ranking vacío',
                  message: 'Todavía no hay exploradores registrados.',
                );
              }

              final lider = users.first;
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: users.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) return _Podio(lider: lider);
                  final i = index - 1;
                  return _FilaRanking(
                    posicion: i,
                    user: users[i],
                    maximo: lider.tokens,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Destaca al primer puesto para que sea inequívoco quién va ganando.
class _Podio extends StatelessWidget {
  const _Podio({required this.lider});

  final UserProfile lider;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VeridiaCard(
        glow: true,
        borderColor: VeridiaColors.veridium.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VeridiaColors.veridium.withValues(alpha: 0.16),
                border: Border.all(
                  color: VeridiaColors.veridium.withValues(alpha: 0.6),
                ),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: VeridiaColors.veridium,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Líder actual', style: text.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    lider.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  VeridiaTokenBadge(tokens: lider.tokens),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaRanking extends StatelessWidget {
  const _FilaRanking({
    required this.posicion,
    required this.user,
    required this.maximo,
  });

  final int posicion;
  final UserProfile user;
  final int maximo;

  Color get _colorPuesto => switch (posicion) {
    0 => VeridiaColors.veridium,
    1 => const Color(0xFFCBD5C0),
    2 => const Color(0xFFD08C4A),
    _ => VeridiaColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final proporcion = maximo <= 0 ? 0.0 : user.tokens / maximo;

    return VeridiaCard(
      borderColor: posicion < 3 ? _colorPuesto.withValues(alpha: 0.45) : null,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorPuesto.withValues(alpha: 0.16),
                  border: Border.all(
                    color: _colorPuesto.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  '${posicion + 1}',
                  style: text.labelLarge?.copyWith(color: _colorPuesto),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                        ),
                        if (user.isBanned) ...[
                          const SizedBox(width: 8),
                          const VeridiaTag(
                            label: 'Suspendido',
                            color: VeridiaColors.error,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              VeridiaTokenBadge(tokens: user.tokens),
            ],
          ),
          const SizedBox(height: 12),
          VeridiaProgressBar(value: proporcion, height: 6, color: _colorPuesto),
        ],
      ),
    );
  }
}
