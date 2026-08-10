import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/desafio.dart';
import 'models/user.dart';
import 'services/especie_ia_service.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_u.dart';
import 'theme/veridia_theme.dart';
import 'navegacion.dart';
import 'widgets/veridia_ui.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final EspecieIAService _especieIAService = EspecieIAService();
  final Set<String> _analizando = {};
  void _cerrarSesion() {
    VeridiaNav.cerrarSesion(context);
  }

  void _showChallengeForm({Challenge? challenge}) {
    final titleController = TextEditingController(text: challenge?.title ?? '');
    final descriptionController = TextEditingController(
      text: challenge?.description ?? '',
    );
    final speciesController = TextEditingController(
      text: challenge?.targetSpecies ?? '',
    );
    final goalController = TextEditingController(
      text: challenge?.targetGoal.toString() ?? '5',
    );
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate =
        challenge?.dueDate ?? DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(challenge == null ? 'Nuevo Desafío' : 'Editar Desafío'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título del desafío',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: speciesController,
                  decoration: const InputDecoration(
                    labelText: 'Especie objetivo',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                TextFormField(
                  controller: goalController,
                  decoration: const InputDecoration(
                    labelText: 'Meta (cantidad)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fecha límite: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          selectedDate = picked;
                        }
                      },
                      child: const Text('Cambiar'),
                    ),
                  ],
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
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  if (challenge == null) {
                    await ChallengeRepository.instance.addChallenge(
                      Challenge(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        targetSpecies: speciesController.text.trim(),
                        targetGoal: int.parse(goalController.text),
                        dueDate: selectedDate,
                        createdDate: DateTime.now(),
                        currentProgress: 0,
                        isCompleted: false,
                      ),
                    );
                  } else {
                    await ChallengeRepository.instance.updateChallenge(
                      Challenge(
                        id: challenge.id,
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        targetSpecies: speciesController.text.trim(),
                        targetGoal: int.parse(goalController.text),
                        dueDate: selectedDate,
                        createdDate: challenge.createdDate,
                        currentProgress: challenge.currentProgress,
                        isCompleted: challenge.isCompleted,
                      ),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('No se pudo guardar: $e')),
                  );
                  return;
                }
                navigator.pop();
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Sube una foto y solo cuenta como progreso si la IA confirma que
  /// muestra la especie objetivo del desafío. Ya no basta con subir
  /// cualquier imagen.
  Future<void> _pickImageFromGallery(Challenge challenge) async {
    if (_analizando.contains(challenge.id)) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted || pickedFile == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _analizando.add(challenge.id));

    try {
      final bytes = await pickedFile.readAsBytes();
      final mimeType = pickedFile.mimeType ?? 'image/jpeg';

      final SpeciesIdentification resultado;
      try {
        resultado = await _especieIAService.identify(bytes, mimeType);
      } on SpeciesIdentificationException catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: VeridiaColors.error,
          ),
        );
        return;
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('No se pudo analizar la foto con IA.'),
            backgroundColor: VeridiaColors.error,
          ),
        );
        return;
      }

      final coincide =
          resultado.identified &&
          especieCoincide(challenge.targetSpecies, resultado);

      if (!coincide) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              resultado.identified
                  ? 'La IA detectó "${resultado.commonName}", no "${challenge.targetSpecies}". No cuenta para este desafío.'
                  : 'La IA no identificó ninguna especie en esta foto.',
            ),
            backgroundColor: VeridiaColors.error,
          ),
        );
        return;
      }

      final newProgress = (challenge.currentProgress + 1).clamp(
        0,
        challenge.targetGoal,
      );
      try {
        await ChallengeRepository.instance.updateProgress(
          challenge.id,
          newProgress,
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el progreso: $e')),
        );
        return;
      }

      final message = newProgress >= challenge.targetGoal
          ? '¡Desafío completado! Bono entregado.'
          : 'IA confirmó "${resultado.commonName}". Progreso: $newProgress/${challenge.targetGoal}';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _analizando.remove(challenge.id));
    }
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar desafío'),
        content: const Text('¿Deseas eliminar este desafío?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ChallengeRepository.instance.deleteChallenge(id);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('No se pudo eliminar: $e')),
                );
                return;
              }
              navigator.pop();
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: VeridiaColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Desafíos Mensuales',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: VeridiaColors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<UserProfile?>(
            valueListenable: UserRepository.instance.currentUser,
            builder: (context, userProfile, child) =>
                VeridiaTokenBadge(tokens: userProfile?.tokens ?? 0),
          ),
          const SizedBox(width: 10),
          VeridiaAppBarAction(
            icon: Icons.logout_rounded,
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ValueListenableBuilder<List<Challenge>>(
        valueListenable: ChallengeRepository.instance.challenges,
        builder: (context, allChallenges, child) {
          final profile = UserRepository.instance.currentUser.value;
          // Un explorador solo ve los desafíos globales y los suyos.
          final challenges = profile?.role == 'Administrador'
              ? allChallenges
              : ChallengeRepository.instance.challengesForUser(profile?.userId);
          return Stack(
            children: [
              Container(color: VeridiaColors.background),
              SafeArea(
                child: challenges.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              size: 64,
                              color: VeridiaColors.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay desafíos aún',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: VeridiaColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Crea tu primer desafío mensual',
                              style: TextStyle(color: VeridiaColors.outline),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: challenges.length,
                        itemBuilder: (context, index) {
                          final challenge = challenges[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: VeridiaColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                const BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.35),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              challenge.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: VeridiaColors.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Objetivo: ${challenge.targetSpecies}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: VeridiaColors
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (challenge.isCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                VeridiaColors.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.emoji_events,
                                                size: 12,
                                                color: VeridiaColors.secondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${challenge.tokensReward}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: VeridiaColors
                                                      .onPrimaryContainer,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    challenge.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: VeridiaColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Progreso: ${challenge.currentProgress}/${challenge.targetGoal}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Vence: ${challenge.dueDate.day}/${challenge.dueDate.month}/${challenge.dueDate.year}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: VeridiaColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: challenge.targetGoal <= 0
                                          ? 0
                                          : (challenge.currentProgress /
                                                    challenge.targetGoal)
                                                .clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor:
                                          VeridiaColors.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        challenge.isCompleted
                                            ? VeridiaColors.secondary
                                            : VeridiaColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              _analizando.contains(challenge.id)
                                              ? null
                                              : () => _pickImageFromGallery(
                                                  challenge,
                                                ),
                                          icon:
                                              _analizando.contains(challenge.id)
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: VeridiaColors
                                                            .onSurface,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.photo_library,
                                                  size: 18,
                                                ),
                                          label: Text(
                                            _analizando.contains(challenge.id)
                                                ? 'Analizando...'
                                                : 'Subir foto',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                VeridiaColors.primary,
                                            foregroundColor:
                                                VeridiaColors.onPrimary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (UserRepository
                                              .instance
                                              .currentUser
                                              .value
                                              ?.role ==
                                          'Administrador')
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () =>
                                                  _showChallengeForm(
                                                    challenge: challenge,
                                                  ),
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
                                              color: VeridiaColors.primary,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _showDeleteConfirm(
                                                    challenge.id,
                                                  ),
                                              icon: const Icon(
                                                Icons.delete,
                                                size: 18,
                                              ),
                                              color: VeridiaColors.error,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: VeridiaBottomNav(
        currentIndex: 0,
        onTap: (i) => VeridiaNav.ir(context, VeridiaSeccion.values[i], 0),
      ),
    );
  }
}
