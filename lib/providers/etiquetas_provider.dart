import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/etiqueta.dart';
import 'database_provider.dart';

/// Notificador reactivo para la lista de etiquetas existentes.
class EtiquetasNotifier extends AsyncNotifier<List<Etiqueta>> {
  @override
  FutureOr<List<Etiqueta>> build() async {
    final repo = ref.watch(etiquetaRepositoryProvider);
    return await repo.obtenerTodas();
  }

  /// Recarga las etiquetas disponibles.
  Future<void> recargar() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Proveedor para obtener todas las etiquetas registradas en SQLite.
final etiquetasProvider = AsyncNotifierProvider<EtiquetasNotifier, List<Etiqueta>>(
  EtiquetasNotifier.new,
);
