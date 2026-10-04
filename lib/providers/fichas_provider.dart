import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ficha.dart';
import 'database_provider.dart';
import 'categorias_provider.dart';

/// Notificador para el término de búsqueda de fichas.
class BusquedaFichasNotifier extends Notifier<String> {
  @override
  String build() => '';

  void actualizar(String texto) => state = texto;
}

/// Proveedor para el término de búsqueda de fichas.
final busquedaFichasProvider = NotifierProvider<BusquedaFichasNotifier, String>(
  BusquedaFichasNotifier.new,
);

/// Notificador reactivo para la lista de fichas en Riverpod 3.
class FichasNotifier extends AsyncNotifier<List<Ficha>> {
  @override
  FutureOr<List<Ficha>> build() async {
    final repo = ref.watch(fichaRepositoryProvider);
    final catId = ref.watch(categoriaSeleccionadaProvider);
    final busqueda = ref.watch(busquedaFichasProvider);

    return await repo.obtenerTodas(
      categoriaId: catId,
      busqueda: busqueda,
    );
  }

  /// Recarga las fichas desde SQLite forzando invalidación.
  Future<void> cargarFichas() async {
    ref.invalidateSelf();
    await future;
  }

  /// Crea una nueva ficha, guarda la imagen en /imagenes/ y persiste los datos en SQLite.
  Future<int> guardarFicha({
    required String titulo,
    String? descripcion,
    int? categoriaId,
    File? archivoImagen,
    List<String> etiquetas = const [],
  }) async {
    final storageService = ref.read(storageServiceProvider);
    final repo = ref.read(fichaRepositoryProvider);

    String? rutaImagenGuardada;
    if (archivoImagen != null) {
      rutaImagenGuardada = await storageService.guardarImagen(archivoImagen);
    }

    final ahora = DateTime.now();
    final nuevaFicha = Ficha(
      titulo: titulo,
      descripcion: descripcion,
      categoriaId: categoriaId,
      fechaCreacion: ahora,
      fechaModificacion: ahora,
      rutaImagen: rutaImagenGuardada,
    );

    final id = await repo.insertar(nuevaFicha, nombresEtiquetas: etiquetas);
    ref.invalidateSelf();
    await future;
    return id;
  }

  /// Actualiza una ficha existente y sincroniza su imagen si cambió.
  Future<void> actualizarFicha({
    required Ficha fichaExistente,
    required String nuevoTitulo,
    String? nuevaDescripcion,
    int? nuevaCategoriaId,
    File? nuevaImagenArchivo,
    bool eliminarImagenPrevia = false,
    List<String> etiquetas = const [],
  }) async {
    final storageService = ref.read(storageServiceProvider);
    final repo = ref.read(fichaRepositoryProvider);

    String? rutaFinal = fichaExistente.rutaImagen;

    // Si se seleccionó una nueva imagen
    if (nuevaImagenArchivo != null) {
      if (fichaExistente.rutaImagen != null) {
        await storageService.eliminarImagen(fichaExistente.rutaImagen);
      }
      rutaFinal = await storageService.guardarImagen(nuevaImagenArchivo);
    } else if (eliminarImagenPrevia && fichaExistente.rutaImagen != null) {
      // Se solicitó eliminar la imagen previa
      await storageService.eliminarImagen(fichaExistente.rutaImagen);
      rutaFinal = null;
    }

    final fichaActualizada = fichaExistente.copyWith(
      titulo: nuevoTitulo,
      descripcion: nuevaDescripcion,
      categoriaId: nuevaCategoriaId,
      rutaImagen: rutaFinal,
      fechaModificacion: DateTime.now(),
    );

    await repo.actualizar(fichaActualizada, nuevosNombresEtiquetas: etiquetas);
    ref.invalidateSelf();
    await future;
  }

  /// Elimina una ficha y su imagen asociada.
  Future<void> eliminarFicha(Ficha ficha) async {
    final storageService = ref.read(storageServiceProvider);
    final repo = ref.read(fichaRepositoryProvider);

    if (ficha.rutaImagen != null) {
      await storageService.eliminarImagen(ficha.rutaImagen);
    }

    if (ficha.id != null) {
      await repo.eliminar(ficha.id!);
    }

    ref.invalidateSelf();
    await future;
  }
}

/// Proveedor para la lista de fichas gestionadas.
final fichasProvider = AsyncNotifierProvider<FichasNotifier, List<Ficha>>(
  FichasNotifier.new,
);
