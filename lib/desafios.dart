import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/desafio.dart';
import 'models/user.dart';
import 'recompensas.dart';
import 'services/especie_ia_service.dart';
import 'services/foto_service.dart';
import 'services/repositorio_d.dart';
import 'services/repositorio_o.dart';
import 'services/repositorio_u.dart';
import 'services/ubicacion_foto.dart';
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
      // StatefulBuilder: sin él, cambiar la fecha límite no repinta el
      // diálogo y el administrador seguía viendo la fecha anterior.
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                          'Fecha límite: ${formatoFecha(selectedDate)}',
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
                            setDialogState(() => selectedDate = picked);
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
            VeridiaBotonTactil(
              child: ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      if (challenge == null) {
                        await ChallengeRepository.instance.addChallenge(
                          Challenge(
                            id: ChallengeRepository.instance.nuevoId(),
                            title: titleController.text.trim(),
                            description: descriptionController.text.trim(),
                            targetSpecies: speciesController.text.trim(),
                            targetGoal: int.parse(goalController.text),
                            dueDate: selectedDate,
                            createdDate: DateTime.now(),
                          ),
                        );
                      } else {
                        // copyWith y no un Challenge nuevo: construirlo a
                        // mano perdía a quién estaba asignado y si el bono ya
                        // se había pagado, y el desafío se volvía global y
                        // volvía a pagar bono al cerrarse.
                        await ChallengeRepository.instance.updateChallenge(
                          challenge.copyWith(
                            title: titleController.text.trim(),
                            description: descriptionController.text.trim(),
                            targetSpecies: speciesController.text.trim(),
                            targetGoal: int.parse(goalController.text),
                            dueDate: selectedDate,
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 24,
                  ),
                ),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Deja elegir entre cámara y galería. En web la cámara del picker no está
  /// disponible, así que allí se va directo a la galería.
  Future<ImageSource?> _elegirOrigen() async {
    if (kIsWeb) return ImageSource.gallery;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: VeridiaColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: VeridiaColors.primary,
              ),
              title: const Text('Tomar foto ahora'),
              subtitle: const Text('Lo más rápido y no se puede repetir'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: VeridiaColors.secondary,
              ),
              title: const Text('Elegir de la galería'),
              subtitle: const Text('Debe ser una foto que no hayas usado'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Registra una foto para un desafío.
  ///
  /// La identificación con Gemini Y el otorgamiento de Veridiums corren en
  /// el servidor (Cloud Functions `identificarEspecie` + `guardarObservacion`
  /// — ver functions/index.js): el cliente solo manda la foto, nunca puede
  /// inventarse un resultado de IA ni escribir el progreso él mismo. La
  /// comparación local de especie es solo para dar feedback inmediato sin
  /// esperar una ida y vuelta a la nube; la que de verdad paga Veridiums es
  /// la del servidor.
  Future<void> _capturarParaDesafio(Challenge challenge) async {
    if (_analizando.contains(challenge.id)) return;

    final perfil = UserRepository.instance.currentUser.value;
    if (perfil == null) return;

    final origen = await _elegirOrigen();
    if (origen == null || !mounted) return;

    // Sin `imageQuality`: recomprimir borra el EXIF y con él la ubicación
    // real de la foto (ver services/ubicacion_foto.dart).
    final pickedFile = await ImagePicker().pickImage(source: origen);
    if (!mounted || pickedFile == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _analizando.add(challenge.id));

    try {
      final bytes = await pickedFile.readAsBytes();
      final mimeType = pickedFile.mimeType ?? 'image/jpeg';

      final SpeciesIdentification resultado;
      try {
        resultado = await _especieIAService.identify(
          bytes,
          mimeType,
          origen: 'el desafío "${challenge.title}"',
        );
      } on FotoDuplicadaException catch (e) {
        messenger.showSnackBar(veridiaSnackBarError(e.message));
        return;
      } on SpeciesIdentificationException catch (e) {
        messenger.showSnackBar(veridiaSnackBarError(e.message));
        return;
      } catch (_) {
        messenger.showSnackBar(
          veridiaSnackBarError('No se pudo analizar la foto con IA.'),
        );
        return;
      }

      final coincide =
          resultado.identified &&
          especieCoincide(challenge.targetSpecies, resultado);

      if (!coincide) {
        messenger.showSnackBar(
          veridiaSnackBarError(
            resultado.identified
                ? 'La IA detectó "${resultado.commonName}", no "${challenge.targetSpecies}". No cuenta para este desafío.'
                : 'La IA no identificó ninguna especie en esta foto.',
          ),
        );
        return;
      }

      // La ubicación sale del EXIF de la foto y solo cae al GPS del celular
      // si la imagen no la trae: así una foto de casa subida desde otro
      // sitio no queda marcada en el sitio equivocado.
      final ubicacion = await ubicacionDeObservacion(bytes);
      final observationId = ObservationRepository.instance.nuevoId();
      final subida = await FotoService.instance.subirFotoObservacion(
        bytes: bytes,
        userId: perfil.userId,
        observationId: observationId,
        mimeType: mimeType,
      );

      final ResultadoGuardarObservacion resultadoGuardado;
      try {
        resultadoGuardado = await ObservationRepository.instance.guardarConIA(
          identificacion: resultado,
          observationId: observationId,
          imageUrl: subida.url,
          latitude: ubicacion.latitude,
          longitude: ubicacion.longitude,
          location: ubicacion.etiqueta,
        );
      } on GuardarObservacionException catch (e) {
        messenger.showSnackBar(veridiaSnackBarError(e.message));
        return;
      }

      // Una sola foto puede coincidir con más de un desafío activo a la
      // vez; el servidor los avanza todos, no solo el de esta tarjeta.
      final avances = resultadoGuardado.avances;
      final propio = avances.where((a) => a.challengeId == challenge.id);
      final otros = avances.where((a) => a.challengeId != challenge.id).length;

      final String message;
      if (propio.isEmpty) {
        // Ya estaba completo antes de esta foto, o algo lo bloqueó server-
        // side pese al chequeo local: se avisa sin fingir un progreso falso.
        message =
            'La IA confirmó "${resultado.commonName}", pero este '
            'desafío ya no aceptaba más progreso.';
      } else {
        final avance = propio.first;
        final palabra = avance.veridiumsGanados == 1 ? 'Veridium' : 'Veridiums';
        message = avance.completado
            ? '¡Desafío completado! +${avance.veridiumsGanados} $palabra.'
            : 'IA confirmó "${resultado.commonName}". '
                  'Progreso: ${avance.progreso}/${avance.meta} '
                  '(+${avance.veridiumsGanados} $palabra)'
                  '${otros > 0 ? ' · también avanzó $otros desafío(s) más' : ''}';
      }
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
            builder: (context, userProfile, child) => VeridiaTokenBadge(
              tokens: userProfile?.tokens ?? 0,
              onTap: () => abrirRecompensas(context),
            ),
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
      body: ValueListenableBuilder<Map<String, ProgresoDesafio>>(
        valueListenable: ChallengeRepository.instance.misProgresos,
        builder: (context, _, _) => ValueListenableBuilder<List<Challenge>>(
          valueListenable: ChallengeRepository.instance.challenges,
          builder: (context, allChallenges, child) {
            final profile = UserRepository.instance.currentUser.value;
            // Un explorador solo ve los desafíos globales y los suyos.
            final challenges = profile?.role == 'Administrador'
                ? allChallenges
                : ChallengeRepository.instance.challengesForUser(
                    profile?.userId,
                  );
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
                            final avance = ChallengeRepository.instance
                                .progreso(challenge.id);
                            final completado = avance.completado;

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
                                                  color:
                                                      VeridiaColors.onSurface,
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
                                        if (completado)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: VeridiaColors
                                                  .primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.emoji_events,
                                                  size: 12,
                                                  color:
                                                      VeridiaColors.secondary,
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
                                          'Mi progreso: ${avance.progreso}/${challenge.targetGoal}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Vence: ${formatoFecha(challenge.dueDate)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                VeridiaColors.onSurfaceVariant,
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
                                            : (avance.progreso /
                                                      challenge.targetGoal)
                                                  .clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: VeridiaColors
                                            .surfaceContainerHighest,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              completado
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
                                        // El administrador modera: no captura
                                        // fotos ni gana Veridiums.
                                        if (UserRepository
                                                .instance
                                                .currentUser
                                                .value
                                                ?.role !=
                                            'Administrador')
                                          Expanded(
                                            child: VeridiaBotonTactil(
                                              child: completado
                                                  ? OutlinedButton.icon(
                                                      onPressed: () =>
                                                          abrirRecompensas(
                                                            context,
                                                          ),
                                                      icon: const Icon(
                                                        Icons
                                                            .card_giftcard_rounded,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Canjear Veridiums',
                                                      ),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor:
                                                            VeridiaColors
                                                                .veridium,
                                                        side: const BorderSide(
                                                          color: VeridiaColors
                                                              .veridium,
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 14,
                                                            ),
                                                      ),
                                                    )
                                                  : ElevatedButton.icon(
                                                      onPressed:
                                                          _analizando.contains(
                                                            challenge.id,
                                                          )
                                                          ? null
                                                          : () =>
                                                                _capturarParaDesafio(
                                                                  challenge,
                                                                ),
                                                      icon:
                                                          _analizando.contains(
                                                            challenge.id,
                                                          )
                                                          ? const SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: VeridiaColors
                                                                    .onSurface,
                                                              ),
                                                            )
                                                          : const Icon(
                                                              Icons
                                                                  .add_a_photo_outlined,
                                                              size: 18,
                                                            ),
                                                      label: Text(
                                                        _analizando.contains(
                                                              challenge.id,
                                                            )
                                                            ? 'Analizando...'
                                                            : 'Registrar foto',
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            VeridiaColors
                                                                .primary,
                                                        foregroundColor:
                                                            VeridiaColors
                                                                .onPrimary,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 14,
                                                            ),
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
      ),
      bottomNavigationBar: VeridiaBottomNav(
        currentIndex: 0,
        onTap: (i) => VeridiaNav.ir(context, VeridiaSeccion.values[i], 0),
      ),
    );
  }
}
