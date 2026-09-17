/// Freno a las fotos que no son especies.
///
/// Sin esto, rechazar una foto no cuesta nada: quien quiera llenar la base de
/// datos solo tiene que seguir disparando hasta que alguna cuele. El límite no
/// castiga al explorador que falla una foto borrosa —cinco seguidas es mucho
/// más de lo que falla alguien de verdad en campo—, sino a quien está probando
/// sistemáticamente qué acepta la IA.
///
/// NOTA: esto corre en el CLIENTE, igual que el resto de la lógica
/// anti-trampa mientras el proyecto no tenga el plan Blaze activo. Un APK
/// modificado se lo salta. La versión que de verdad no se puede evadir es el
/// límite por UID e IP que ya existe en `functions/middleware/rateLimit.js`,
/// esperando a que se puedan desplegar las Cloud Functions. Ver
/// [[project-veridia-backend]] en la memoria del proyecto.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Por qué se le negó al explorador un análisis nuevo.
enum MotivoBloqueo {
  /// Demasiadas fotos rechazadas seguidas.
  rachaDeRechazos,

  /// Tope de análisis del día. Protege la cuota gratuita de Gemini y, sobre
  /// todo, evita que una sola cuenta llene el mapa en una tarde.
  cuotaDiaria,
}

class LimiteIntentosException implements Exception {
  LimiteIntentosException(this.motivo, this.message);

  final MotivoBloqueo motivo;
  final String message;

  @override
  String toString() => message;
}

/// Cuántas fotos rechazadas seguidas se toleran antes de la espera.
const maxRechazosSeguidos = 5;

/// Lo que hay que esperar tras agotar la racha. Corta el ensayo y error sin
/// dejar fuera de juego a nadie que de verdad esté en campo.
const esperaTrasRacha = Duration(minutes: 3);

/// Tope de análisis por explorador y por día.
///
/// 40 es holgado para una salida de campo real (un avistamiento cada pocos
/// minutos durante horas) y a la vez pone un techo duro a lo que una sola
/// cuenta puede meter en la base de datos en 24 horas.
const maxAnalisisDiarios = 40;

/// Estado del limitador para UN explorador.
///
/// Inmutable y sin dependencias a propósito: toda la regla vive aquí, en
/// funciones puras, para poder probarla sin Firebase ni almacenamiento.
@immutable
class EstadoIntentos {
  const EstadoIntentos({
    this.rechazosSeguidos = 0,
    this.bloqueadoHasta,
    this.dia = '',
    this.analisisHoy = 0,
  });

  final int rechazosSeguidos;
  final DateTime? bloqueadoHasta;

  /// Día al que corresponde [analisisHoy], en formato `yyyy-mm-dd`.
  final String dia;
  final int analisisHoy;

  EstadoIntentos copyWith({
    int? rechazosSeguidos,
    DateTime? bloqueadoHasta,
    bool limpiarBloqueo = false,
    String? dia,
    int? analisisHoy,
  }) => EstadoIntentos(
    rechazosSeguidos: rechazosSeguidos ?? this.rechazosSeguidos,
    bloqueadoHasta: limpiarBloqueo
        ? null
        : (bloqueadoHasta ?? this.bloqueadoHasta),
    dia: dia ?? this.dia,
    analisisHoy: analisisHoy ?? this.analisisHoy,
  );
}

/// Clave del día en hora local. Local y no UTC: el explorador entiende "hoy"
/// como su día, no como el del meridiano de Greenwich.
String diaDe(DateTime momento) =>
    '${momento.year.toString().padLeft(4, '0')}-'
    '${momento.month.toString().padLeft(2, '0')}-'
    '${momento.day.toString().padLeft(2, '0')}';

/// Pone el contador diario a cero si cambió el día.
EstadoIntentos alDiaDe(EstadoIntentos estado, DateTime ahora) {
  final hoy = diaDe(ahora);
  if (estado.dia == hoy) return estado;
  return estado.copyWith(dia: hoy, analisisHoy: 0);
}

/// Qué impide analizar ahora mismo, o null si se puede.
MotivoBloqueo? bloqueoActual(EstadoIntentos estado, DateTime ahora) {
  final hasta = estado.bloqueadoHasta;
  if (hasta != null && ahora.isBefore(hasta)) {
    return MotivoBloqueo.rachaDeRechazos;
  }
  if (alDiaDe(estado, ahora).analisisHoy >= maxAnalisisDiarios) {
    return MotivoBloqueo.cuotaDiaria;
  }
  return null;
}

/// Cuánto falta para que se levante la espera.
Duration esperaRestante(EstadoIntentos estado, DateTime ahora) {
  final hasta = estado.bloqueadoHasta;
  if (hasta == null || !ahora.isBefore(hasta)) return Duration.zero;
  return hasta.difference(ahora);
}

/// Descuenta un análisis del cupo del día.
EstadoIntentos trasAnalisis(EstadoIntentos estado, DateTime ahora) {
  final alDia = alDiaDe(estado, ahora);
  return alDia.copyWith(analisisHoy: alDia.analisisHoy + 1);
}

/// Suma un rechazo y, si se agotó la racha, arranca la espera.
EstadoIntentos trasRechazo(EstadoIntentos estado, DateTime ahora) {
  final seguidos = estado.rechazosSeguidos + 1;
  if (seguidos < maxRechazosSeguidos) {
    return estado.copyWith(rechazosSeguidos: seguidos);
  }
  // Se reinicia el contador junto con la espera: al volver, el explorador
  // tiene otra racha completa y no queda bloqueado foto sí, foto también.
  return estado.copyWith(
    rechazosSeguidos: 0,
    bloqueadoHasta: ahora.add(esperaTrasRacha),
  );
}

/// Una foto válida borra la racha y cualquier espera pendiente.
EstadoIntentos trasExito(EstadoIntentos estado) =>
    estado.copyWith(rechazosSeguidos: 0, limpiarBloqueo: true);

/// Mensaje que ve el explorador cuando se le niega el análisis.
String mensajeDeBloqueo(MotivoBloqueo motivo, Duration restante) {
  switch (motivo) {
    case MotivoBloqueo.rachaDeRechazos:
      final minutos = restante.inMinutes;
      final falta = minutos >= 1
          ? '$minutos ${minutos == 1 ? 'minuto' : 'minutos'}'
          : '${restante.inSeconds} segundos';
      return 'Van $maxRechazosSeguidos fotos seguidas que no son una especie. '
          'Espera $falta antes de volver a analizar.';
    case MotivoBloqueo.cuotaDiaria:
      return 'Llegaste al máximo de $maxAnalisisDiarios análisis por hoy. '
          'Vuelve mañana.';
  }
}

/// Guarda el estado del limitador entre sesiones.
///
/// En `SharedPreferences` y por `userId`: cerrar la app no debe ser la forma
/// de saltarse la espera, y dos cuentas en el mismo celular no comparten
/// contador.
class LimiteIntentosService {
  LimiteIntentosService._();

  static final LimiteIntentosService instance = LimiteIntentosService._();

  /// Permite inyectar un reloj en las pruebas.
  @visibleForTesting
  DateTime Function() ahora = DateTime.now;

  String _clave(String userId, String campo) => 'limiteIA.$userId.$campo';

  Future<EstadoIntentos> _leer(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasta = prefs.getString(_clave(userId, 'bloqueadoHasta'));
      return EstadoIntentos(
        rechazosSeguidos: prefs.getInt(_clave(userId, 'rechazos')) ?? 0,
        bloqueadoHasta: hasta == null ? null : DateTime.tryParse(hasta),
        dia: prefs.getString(_clave(userId, 'dia')) ?? '',
        analisisHoy: prefs.getInt(_clave(userId, 'analisisHoy')) ?? 0,
      );
    } catch (e) {
      // Sin almacenamiento preferimos dejar pasar al explorador antes que
      // bloquearlo por un fallo que no es suyo.
      debugPrint('No se pudo leer el límite de intentos: $e');
      return const EstadoIntentos();
    }
  }

  Future<void> _guardar(String userId, EstadoIntentos estado) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_clave(userId, 'rechazos'), estado.rechazosSeguidos);
      await prefs.setString(_clave(userId, 'dia'), estado.dia);
      await prefs.setInt(_clave(userId, 'analisisHoy'), estado.analisisHoy);
      final hasta = estado.bloqueadoHasta;
      if (hasta == null) {
        await prefs.remove(_clave(userId, 'bloqueadoHasta'));
      } else {
        await prefs.setString(
          _clave(userId, 'bloqueadoHasta'),
          hasta.toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('No se pudo guardar el límite de intentos: $e');
    }
  }

  /// Lanza [LimiteIntentosException] si el explorador no puede analizar ahora.
  ///
  /// Solo comprueba: no descuenta nada. El cupo se gasta en [contarAnalisis],
  /// cuando la IA ya dio un veredicto. Si se descontara aquí, una tarde con
  /// mala señal dejaría al explorador sin sus 40 análisis del día sin haber
  /// llegado a identificar ni una foto.
  Future<void> revisar(String userId) async {
    final momento = ahora();
    final estado = await _leer(userId);

    final bloqueo = bloqueoActual(estado, momento);
    if (bloqueo != null) {
      throw LimiteIntentosException(
        bloqueo,
        mensajeDeBloqueo(bloqueo, esperaRestante(estado, momento)),
      );
    }
  }

  /// Gasta un análisis del cupo del día. Se llama cuando la IA respondió,
  /// diga lo que diga: lo que agota la cuota es la petición atendida, no el
  /// intento que se quedó sin red.
  Future<void> contarAnalisis(String userId) async {
    final momento = ahora();
    await _guardar(userId, trasAnalisis(await _leer(userId), momento));
  }

  Future<void> registrarRechazo(String userId) async {
    final momento = ahora();
    await _guardar(userId, trasRechazo(await _leer(userId), momento));
  }

  Future<void> registrarExito(String userId) async {
    await _guardar(userId, trasExito(await _leer(userId)));
  }

  /// Cuántos rechazos le quedan antes de la espera. Para avisarle antes de
  /// que se quede bloqueado sin entender por qué.
  Future<int> rechazosRestantes(String userId) async {
    final estado = await _leer(userId);
    return maxRechazosSeguidos - estado.rechazosSeguidos;
  }
}
