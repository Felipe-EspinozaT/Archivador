import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class QuickActionPayload {
  final String action;
  final String text;
  final String portada;

  QuickActionPayload({
    required this.action,
    this.text = '',
    this.portada = '',
  });

  factory QuickActionPayload.fromMap(Map<dynamic, dynamic> map) {
    return QuickActionPayload(
      action: map['action']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      portada: map['portada']?.toString() ?? '',
    );
  }
}

/// Servicio que comunica Flutter con el servicio nativo de Android (XiaomiOverlayService)
class OverlayService {
  static const MethodChannel _channel = MethodChannel('simplista/overlay');

  static bool get soportaOverlayNativo => !kIsWeb && Platform.isAndroid;

  static Future<bool> tienePermiso() async {
    if (!soportaOverlayNativo) return false;
    try {
      final res = await _channel.invokeMethod<bool>('checkPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> solicitarPermiso() async {
    if (!soportaOverlayNativo) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> iniciarBarraSegundoPlano({String lado = 'derecha'}) async {
    if (!soportaOverlayNativo) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startOverlay', {'lado': lado});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> detenerBarraSegundoPlano() async {
    if (!soportaOverlayNativo) return;
    try {
      await _channel.invokeMethod('stopOverlay');
    } catch (_) {}
  }

  static Future<QuickActionPayload?> consumirAccionPendiente() async {
    if (!soportaOverlayNativo) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('consumeQuickAction');
      if (res is Map) {
        return QuickActionPayload.fromMap(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static void escucharAccionesRapidas(void Function(QuickActionPayload payload) onPayload) {
    if (!soportaOverlayNativo) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickPayload' && call.arguments is Map) {
        onPayload(QuickActionPayload.fromMap(call.arguments as Map));
      }
    });
  }
}
