import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ficha.dart';
import 'database_provider.dart';

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

/// Notificador para las etiquetas adjuntadas al filtro de búsqueda.
class EtiquetasFiltroNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void alternarEtiqueta(String nombre) {
    if (state.contains(nombre)) {
      state = state.where((e) => e != nombre).toList();
    } else {
      state = [...state, nombre];
    }
  }

  void eliminarEtiqueta(String nombre) {
    state = state.where((e) => e != nombre).toList();
  }

  void limpiar() => state = [];
}

/// Proveedor para la lista de etiquetas activas en el filtro.
final etiquetasFiltroProvider = NotifierProvider<EtiquetasFiltroNotifier, List<String>>(
  EtiquetasFiltroNotifier.new,
);

/// Notificador independiente para las 5 fichas más recientes (no afectado por filtros ni búsquedas).
class FichasRecientesNotifier extends AsyncNotifier<List<Ficha>> {
  @override
  FutureOr<List<Ficha>> build() async {
    final repo = ref.watch(fichaRepositoryProvider);
    return await repo.obtenerRecientes(limite: 5);
  }
}

/// Proveedor para las 5 fichas más recientes sin filtros.
final fichasRecientesProvider = AsyncNotifierProvider<FichasRecientesNotifier, List<Ficha>>(
  FichasRecientesNotifier.new,
);

/// Notificador reactivo para la lista general de fichas en Riverpod 3.
class FichasNotifier extends AsyncNotifier<List<Ficha>> {
  @override
  FutureOr<List<Ficha>> build() async {
    final repo = ref.watch(fichaRepositoryProvider);
    final busqueda = ref.watch(busquedaFichasProvider);
    final etiquetasFiltro = ref.watch(etiquetasFiltroProvider);

    final todas = await repo.obtenerTodas(
      busqueda: busqueda,
    );

    if (etiquetasFiltro.isEmpty) {
      return todas;
    }

    // Filtrar fichas que contengan todas las etiquetas adjuntadas
    return todas.where((ficha) {
      final nombresEtiquetasFicha =
          ficha.etiquetas.map((e) => e.nombre.toLowerCase()).toSet();
      return etiquetasFiltro.every(
        (tagFiltro) => nombresEtiquetasFicha.contains(tagFiltro.toLowerCase()),
      );
    }).toList();
  }

  /// Recarga las fichas desde SQLite forzando invalidación.
  Future<void> cargarFichas() async {
    ref.invalidateSelf();
    ref.invalidate(fichasRecientesProvider);
    await future;
  }

  /// Crea una nueva ficha, guarda la imagen en /imagenes/ y persiste los datos en SQLite.
  /// Si no se especifica categoría, se asigna por defecto a la categoría 'Errante'.
  Future<int> guardarFicha({
    required String titulo,
    String? descripcion,
    int? categoriaId,
    File? archivoImagen,
    List<String> etiquetas = const [],
  }) async {
    final storageService = ref.read(storageServiceProvider);
    final repo = ref.read(fichaRepositoryProvider);
    final catRepo = ref.read(categoriaRepositoryProvider);

    int? categoriaFinalId = categoriaId;
    if (categoriaFinalId == null) {
      final errante = await catRepo.obtenerOCrearErrante();
      categoriaFinalId = errante.id;
    }

    String? rutaImagenGuardada;
    if (archivoImagen != null) {
      rutaImagenGuardada = await storageService.guardarImagen(archivoImagen);
    }

    final ahora = DateTime.now();
    final nuevaFicha = Ficha(
      titulo: titulo,
      descripcion: descripcion,
      categoriaId: categoriaFinalId,
      fechaCreacion: ahora,
      fechaModificacion: ahora,
      rutaImagen: rutaImagenGuardada,
    );

    final id = await repo.insertar(nuevaFicha, nombresEtiquetas: etiquetas);
    ref.invalidateSelf();
    ref.invalidate(fichasRecientesProvider);
    await future;
    return id;
  }

  /// Actualiza una ficha existente y sincroniza su imagen si cambió.
  /// Si no tiene categoría asignada, usa la categoría 'Errante'.
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
    final catRepo = ref.read(categoriaRepositoryProvider);

    int? categoriaFinalId = nuevaCategoriaId;
    if (categoriaFinalId == null) {
      final errante = await catRepo.obtenerOCrearErrante();
      categoriaFinalId = errante.id;
    }

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
      categoriaId: categoriaFinalId,
      rutaImagen: rutaFinal,
      fechaModificacion: DateTime.now(),
    );

    await repo.actualizar(fichaActualizada, nuevosNombresEtiquetas: etiquetas);
    ref.invalidateSelf();
    ref.invalidate(fichasRecientesProvider);
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
    ref.invalidate(fichasRecientesProvider);
    await future;
  }
}

/// Proveedor para la lista de fichas gestionadas.
final fichasProvider = AsyncNotifierProvider<FichasNotifier, List<Ficha>>(
  FichasNotifier.new,
);
