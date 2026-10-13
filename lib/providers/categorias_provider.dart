import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/categoria.dart';
import 'database_provider.dart';
import 'fichas_provider.dart';

/// Notificador reactivo para la gestión y reordenamiento de categorías en Riverpod 3.
class CategoriasNotifier extends AsyncNotifier<List<Categoria>> {
  @override
  FutureOr<List<Categoria>> build() async {
    final repo = ref.watch(categoriaRepositoryProvider);
    return await repo.obtenerTodas();
  }

  /// Recarga las categorías desde SQLite.
  Future<void> cargarCategorias() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoriaRepositoryProvider);
      return await repo.obtenerTodas();
    });
  }

  /// Reordena las categorías visualmente y persiste el nuevo orden en SQLite.
  Future<void> reordenarCategorias(int oldIndex, int newIndex) async {
    final categoriasActuales = state.value;
    if (categoriasActuales == null) return;

    final lista = List<Categoria>.from(categoriasActuales);
    if (oldIndex < 0 || oldIndex >= lista.length) return;
    final item = lista.removeAt(oldIndex);
    final indiceInsercion = newIndex.clamp(0, lista.length);
    lista.insert(indiceInsercion, item);

    // Reasignar campo orden correlativamente
    final listaConOrden = <Categoria>[];
    for (int i = 0; i < lista.length; i++) {
      listaConOrden.add(lista[i].copyWith(orden: i));
    }

    // Actualizar estado inmediatamente para retroalimentación instantánea
    state = AsyncValue.data(listaConOrden);

    // Persistir el orden en SQLite
    final repo = ref.read(categoriaRepositoryProvider);
    await repo.actualizarOrden(listaConOrden);
  }

  /// Agrega una nueva categoría.
  Future<void> agregarCategoria(
    String nombre,
    String? descripcion,
    String colorHex, {
    String? rutaImagenFondo,
  }) async {
    final repo = ref.read(categoriaRepositoryProvider);
    await repo.insertar(Categoria(
      nombre: nombre,
      descripcion: descripcion,
      colorHex: colorHex,
      rutaImagenFondo: rutaImagenFondo,
    ));
    ref.invalidateSelf();
    await future;
  }

  /// Actualiza una categoría existente.
  Future<void> actualizarCategoria(Categoria categoria) async {
    final repo = ref.read(categoriaRepositoryProvider);
    await repo.actualizar(categoria);
    ref.invalidateSelf();
    await future;
  }

  /// Elimina una categoría por su ID, con opción de eliminar o reasignar fichas a Errante.
  Future<void> eliminarCategoria(int id, {bool eliminarFichasDependientes = false}) async {
    final repo = ref.read(categoriaRepositoryProvider);
    await repo.eliminar(id, eliminarFichasDependientes: eliminarFichasDependientes);
    ref.invalidateSelf();
    // Invalidar fichas para reflejar cambios (borradas o reasignadas a Errante)
    ref.invalidate(fichasProvider);
    ref.invalidate(fichasRecientesProvider);
    await future;
  }
}

/// Proveedor para la lista de categorías.
final categoriasProvider = AsyncNotifierProvider<CategoriasNotifier, List<Categoria>>(
  CategoriasNotifier.new,
);

/// Notificador para la categoría seleccionada como filtro en la pantalla de lista.
class CategoriaSeleccionadaNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void seleccionar(int? id) => state = id;
}

/// Proveedor para la categoría seleccionada actualmente en la búsqueda/lista.
final categoriaSeleccionadaProvider = NotifierProvider<CategoriaSeleccionadaNotifier, int?>(
  CategoriaSeleccionadaNotifier.new,
);
