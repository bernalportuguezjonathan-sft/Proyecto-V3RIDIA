import 'package:flutter/material.dart';
import 'models/asignacion.dart';
import 'services/repositorioA.dart';

class AssignmentHistoryScreen extends StatelessWidget {
  const AssignmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5631),
        title: const Text('Historial de asignaciones'),
      ),
      body: ValueListenableBuilder<List<AssignmentRecord>>(
        valueListenable: AssignmentRepository.instance.records,
        builder: (context, records, child) {
          if (records.isEmpty) {
            return const Center(
              child: Text('No hay registros de asignaciones aún.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final record = records[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.06),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.eventType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(record.challengeTitle),
                    const SizedBox(height: 6),
                    Text(record.note),
                    const SizedBox(height: 6),
                    Text('Admin: ${record.assignedByAdmin ?? 'Desconocido'}'),
                    if (record.targetUserDisplayName != null) ...[
                      const SizedBox(height: 6),
                      Text('Jugador: ${record.targetUserDisplayName}'),
                    ],
                    const SizedBox(height: 6),
                    Text('Fecha: ${record.formattedDate}'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
