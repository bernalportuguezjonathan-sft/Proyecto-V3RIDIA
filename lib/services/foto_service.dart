import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Sube las fotos de las observaciones y devuelve una URL pública.
///
/// Usa Supabase Storage si hay claves configuradas; si no, cae de vuelta a
/// Firebase Storage. Nunca lanza: si ambos fallan devuelve null y la
/// observación se guarda igual (solo sin foto).
class FotoService {
  FotoService._();

  static final FotoService instance = FotoService._();

  static bool _supabaseReady = false;

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get usingSupabase => _supabaseReady;

  /// Llamado una sola vez desde main(). Seguro de llamar sin claves.
  static Future<void> initSupabase() async {
    if (!isSupabaseConfigured) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _supabaseReady = true;
      debugPrint('Supabase inicializado.');
    } catch (e) {
      _supabaseReady = false;
      debugPrint('Supabase no se pudo inicializar: $e');
    }
  }

  Future<String?> subirFotoObservacion({
    required Uint8List bytes,
    required String userId,
    required String observationId,
    String mimeType = 'image/jpeg',
  }) async {
    final extension = mimeType.contains('png') ? 'png' : 'jpg';
    final path = '$userId/$observationId.$extension';

    if (_supabaseReady) {
      try {
        final storage = Supabase.instance.client.storage.from(supabaseBucket);
        await storage.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
        return storage.getPublicUrl(path);
      } catch (e) {
        debugPrint('Supabase upload falló, usando Firebase Storage: $e');
      }
    }

    try {
      final ref = FirebaseStorage.instance.ref().child('observaciones/$path');
      await ref.putData(bytes, SettableMetadata(contentType: mimeType));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase Storage upload falló: $e');
      return null;
    }
  }
}
