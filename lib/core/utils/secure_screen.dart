import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Active/désactive FLAG_SECURE côté natif : empêche réellement les captures
/// et enregistrements d'écran (Android). À appeler dans initState/dispose des
/// écrans sensibles (billet/QR). No-op sur les plateformes non supportées.
class SecureScreen {
  static const _channel = MethodChannel('happyn/secure_screen');

  static Future<void> enable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {
      // Best-effort : si le canal n'est pas dispo, on n'empêche pas l'écran.
    }
  }

  static Future<void> disable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}
  }
}
