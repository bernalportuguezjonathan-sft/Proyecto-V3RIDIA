import 'package:flutter/material.dart';

class Observation {
  Observation({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.location,
    required this.notes,
  });

  final String id;
  final String commonName;
  final String scientificName;
  final String location;
  final String notes;
}

class ObservationsScreen extends StatefulWidget {
  const ObservationsScreen({super.key});

  @override
  State<ObservationsScreen> createState() => _ObservationsScreenState();
}

class _ObservationsScreenState extends State<ObservationsScreen> {
  final List<Observation> _observations = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _commonNameController = TextEditingController();
  final TextEditingController _scientificNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  void _showForm({Observation? observation}) {
    if (observation != null) {
      _commonNameController.text = observation.commonName;
      _scientificNameController.text = observation.scientificName;
      _locationController.text = observation.location;
      _notesController.text = observation.notes;
    } else {
      _commonNameController.clear();
      _scientificNameController.clear();
      _locationController.clear();
      _notesController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(observation == null ? 'Nueva observación' : 'Editar observación'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('commonNameField'),
                  controller: _commonNameController,
                  decoration: const InputDecoration(labelText: 'Nombre común'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  key: const Key('scientificNameField'),
                  controller: _scientificNameController,
                  decoration: const InputDecoration(labelText: 'Nombre científico'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  key: const Key('locationField'),
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Ubicación'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  key: const Key('notesField'),
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                setState(() {
                  if (observation == null) {
                    _observations.add(
                      Observation(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        commonName: _commonNameController.text.trim(),
                        scientificName: _scientificNameController.text.trim(),
                        location: _locationController.text.trim(),
                        notes: _notesController.text.trim(),
                      ),
                    );
                  } else {
                    final index = _observations.indexWhere((item) => item.id == observation.id);
                    if (index >= 0) {
                      _observations[index] = Observation(
                        id: observation.id,
                        commonName: _commonNameController.text.trim(),
                        scientificName: _scientificNameController.text.trim(),
                        location: _locationController.text.trim(),
                        notes: _notesController.text.trim(),
                      );
                    }
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deleteObservation(String id) {
    setState(() {
      _observations.removeWhere((item) => item.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Observaciones'),
        backgroundColor: const Color(0xFF1E5631),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar observación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5631),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _observations.isEmpty
                  ? const Center(
                      child: Text('No hay observaciones todavía'),
                    )
                  : ListView.builder(
                      itemCount: _observations.length,
                      itemBuilder: (context, index) {
                        final observation = _observations[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(observation.commonName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(observation.scientificName),
                                Text(observation.location),
                                Text(observation.notes),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showForm(observation: observation),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteObservation(observation.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
