import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Resultado de subir una foto.
///
/// Existe para distinguir "se subió" de "falló y por qué". Antes el servicio
/// devolvía `String?` y un `null` tapaba cualquier error: la observación se
/// guardaba sin foto y el explorador nunca se enteraba de que la había
/// perdido.
class ResultadoSubida {
  const ResultadoSubida.exito(String this.url) : error = null;
  const ResultadoSubida.fallo(String this.error) : url = null;

  /// URL pública de la foto, o null si la subida falló.
  final String? url;

  /// Motivo del fallo en lenguaje claro, o null si todo salió bien.
  final String? error;

  bool get exitosa => url != null;
}

/// Sube a Supabase Storage las fotos de la app (observaciones y perfiles) y
/// devuelve una URL pública.
///
/// Supabase es el único proveedor: Firebase Storage nunca llegó a
/// aprovisionarse en el proyecto (`firebasestorage.app` responde 404), así que
/// mantenerlo como respaldo solo servía para que los fallos pasaran
/// desapercibidos.
class FotoService {
  FotoService._();

  static final FotoService instance = FotoService._();

  /// Sin esto, una red lenta o bloqueada deja el botón de guardar girando
  /// para siempre en vez de mostrar un error.
  static const _uploadTimeout = Duration(seconds: 25);

  static bool _supabaseReady = false;

  /// URL base del proyecto de Supabase, ya saneada.
  ///
  /// En el panel de Supabase es fácil copiar por error la URL del endpoint
  /// REST (`https://xxx.supabase.co/rest/v1/`). El SDK construye las rutas de
  /// Storage encima de esta URL, así que ese sufijo generaba rutas inválidas
  /// y todas las fotos se perdían. Lo recortamos aquí en vez de confiar en
  /// que esté bien copiada.
  static String get _urlProyecto {
    var url = supabaseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    const sufijoRest = '/rest/v1';
    if (url.endsWith(sufijoRest)) {
      url = url.substring(0, url.length - sufijoRest.length);
    }
    return url;
  }

  static bool get isSupabaseConfigured =>
      _urlProyecto.isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static bool get usingSupabase => _supabaseReady;

  /// Llamado una sola vez desde main(). Seguro de llamar sin claves.
  static Future<void> initSupabase() async {
    if (!isSupabaseConfigured) return;
    try {
      await Supabase.initialize(
        url: _urlProyecto,
        publishableKey: supabaseAnonKey.trim(),
      ).timeout(_uploadTimeout);
      _supabaseReady = true;
      debugPrint('Supabase inicializado en $_urlProyecto');
    } catch (e) {
      _supabaseReady = false;
      debugPrint('Supabase no se pudo inicializar: $e');
    }
  }

  /// Foto de una observación. La ruta lleva el id del avistamiento, que ya es
  /// único, así que nunca pisa un archivo anterior.
  Future<ResultadoSubida> subirFotoObservacion({
    required Uint8List bytes,
    required String userId,
    required String observationId,
    String mimeType = 'image/jpeg',
  }) {
    return _subir(
      ruta: '$userId/$observationId.${_extension(mimeType)}',
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  /// Foto de perfil. Va al mismo bucket bajo el prefijo `perfiles/`, así no
  /// hace falta crear un segundo bucket ni otra política de acceso.
  ///
  /// El nombre incluye una marca de tiempo a propósito: la política del bucket
  /// permite crear objetos pero no reemplazarlos, así que cada cambio de foto
  /// debe escribir en una ruta nueva. La foto anterior queda huérfana, que es
  /// preferible a que el segundo cambio de foto falle.
  Future<ResultadoSubida> subirFotoPerfil({
    required Uint8List bytes,
    required String userId,
    String mimeType = 'image/jpeg',
  }) {
    final marca = DateTime.now().millisecondsSinceEpoch;
    return _subir(
      ruta: 'perfiles/$userId/$marca.${_extension(mimeType)}',
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  static String _extension(String mimeType) =>
      mimeType.contains('png') ? 'png' : 'jpg';

  /// Sube los bytes a [ruta] dentro del bucket configurado. Nunca lanza:
  /// devuelve un [ResultadoSubida] que la pantalla puede mostrar.
  Future<ResultadoSubida> _subir({
    required String ruta,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!_supabaseReady) {
      return ResultadoSubida.fallo(_motivoFallo());
    }

    try {
      final storage = Supabase.instance.client.storage.from(supabaseBucket);
      // upsert: false a propósito. Con `true` el SDK manda la cabecera
      // `x-upsert`, y entonces Supabase evalúa la política de UPDATE del
      // bucket en vez de la de INSERT: como el bucket solo permite crear
      // objetos, TODA subida era rechazada con "violates row-level security
      // policy". Las rutas ya son únicas, así que nunca hace falta reemplazar.
      await storage
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          )
          .timeout(_uploadTimeout);
      return ResultadoSubida.exito(storage.getPublicUrl(ruta));
    } catch (e) {
      debugPrint('Supabase upload falló ($ruta): $e');
      return ResultadoSubida.fallo(_motivoFallo());
    }
  }

  /// Mensaje accionable según en qué punto está fallando el almacenamiento.
  String _motivoFallo() {
    if (!isSupabaseConfigured) {
      return 'No hay almacenamiento de fotos configurado '
          '(revisa lib/config/supabase_config.dart).';
    }
    if (!_supabaseReady) {
      return 'No se pudo conectar con Supabase Storage. '
          'Revisa tu internet y las claves del proyecto.';
    }
    return 'El servidor rechazó la foto. Revisa que el bucket '
        '"$supabaseBucket" siga existiendo y permitiendo subidas (INSERT).';
  }
}
