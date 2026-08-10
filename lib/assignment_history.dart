import 'package:flutter/material.dart';
import 'models/asignacion.dart';
import 'services/repositorio_a.dart';
import 'theme/veridia_theme.dart';
import 'widgets/veridia_ui.dart';

class AssignmentHistoryScreen extends StatelessWidget {
  const AssignmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de asignaciones')),
      body: VeridiaBackground(
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<List<AssignmentRecord>>(
            valueListenable: AssignmentRepository.instance.records,
            builder: (context, records, child) {
              if (records.isEmpty) {
                return const VeridiaEmptyState(
                  icon: Icons.timeline_outlined,
                  title: 'Sin movimientos',
                  message:
                      'Aquí aparecerá cada desafío que crees o asignes a un '
                      'explorador.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final esGlobal = record.targetUserDisplayName == null;

                  return VeridiaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.challengeTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall,
                              ),
                            ),
                            const SizedBox(width: 10),
                            VeridiaTag(
                              label: record.eventType,
                              color: esGlobal
                                  ? VeridiaColors.secondary
                                  : VeridiaColors.primary,
                              dense: true,
                            ),
                          ],
                        ),
                        if (record.note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(record.note, style: text.bodySmall),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            VeridiaTag(
                              label: record.assignedByAdmin ?? 'Desconocido',
                              icon: Icons.admin_panel_settings_outlined,
                              color: VeridiaColors.tertiary,
                              dense: true,
                            ),
                            if (record.targetUserDisplayName != null)
                              VeridiaTag(
                                label: record.targetUserDisplayName!,
                                icon: Icons.person_outline,
                                dense: true,
                              ),
                            VeridiaTag(
                              label: record.formattedDate,
                              icon: Icons.event_outlined,
                              color: VeridiaColors.tertiary,
                              dense: true,
                            ),
                          ],
                        ),
                      ],
                    ),
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
