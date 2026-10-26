import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class QuickActionPayload {
  final String action;
  final String title;
  final String text;
  final String portada;
  final int? fichaId;
  final int? categoriaId;

  QuickActionPayload({
    required this.action,
    this.title = '',
    this.text = '',
    this.portada = '',
    this.fichaId,
    this.categoriaId,
  });

  factory QuickActionPayload.fromMap(Map<dynamic, dynamic> map) {
    final rawFichaId = map['fichaId'];
    final rawCatId = map['categoriaId'];

    int? parsedFichaId;
    if (rawFichaId is int && rawFichaId > 0) {
      parsedFichaId = rawFichaId;
    } else if (rawFichaId is num && rawFichaId.toInt() > 0) {
      parsedFichaId = rawFichaId.toInt();
    }

    int? parsedCatId;
    if (rawCatId is int && rawCatId > 0) {
      parsedCatId = rawCatId;
    } else if (rawCatId is num && rawCatId.toInt() > 0) {
      parsedCatId = rawCatId.toInt();
    }

    return QuickActionPayload(
      action: map['action']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      portada: map['portada']?.toString() ?? '',
      fichaId: parsedFichaId,
      categoriaId: parsedCatId,
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

  /// Abre el selector nativo de Android (Storage Access Framework) donde el usuario
  /// puede elegir directamente su Google Drive o carpeta del teléfono para guardar el respaldo.
  static Future<String?> guardarArchivoSelectorSistema({
    required String fileName,
    required String content,
  }) async {
    if (!soportaOverlayNativo) return null;
    try {
      final res = await _channel.invokeMethod<String>('saveBackupToDriveDialog', {
        'fileName': fileName,
        'content': content,
      });
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Abre el selector nativo de Android (Storage Access Framework) para seleccionar y leer
  /// un archivo de respaldo desde Google Drive o almacenamiento interno.
  static Future<String?> abrirArchivoSelectorSistema() async {
    if (!soportaOverlayNativo) return null;
    try {
      final res = await _channel.invokeMethod<String>('openBackupFromDriveDialog');
      return res;
    } catch (_) {
      return null;
    }
  }
}
