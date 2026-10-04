import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/categoria.dart';
import 'database_provider.dart';

/// Notificador reactivo para la gestión de categorías en Riverpod 3.
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

  /// Agrega una nueva categoría.
  Future<void> agregarCategoria(String nombre, String? descripcion, String colorHex) async {
    final repo = ref.read(categoriaRepositoryProvider);
    await repo.insertar(Categoria(
      nombre: nombre,
      descripcion: descripcion,
      colorHex: colorHex,
    ));
    ref.invalidateSelf();
    await future;
  }

  /// Elimina una categoría por su ID.
  Future<void> eliminarCategoria(int id) async {
    final repo = ref.read(categoriaRepositoryProvider);
    await repo.eliminar(id);
    ref.invalidateSelf();
    await future;
  }
}

/// Proveedor para la lista de categorías.
final categoriasProvider = AsyncNotifierProvider<CategoriasNotifier, List<Categoria>>(
  CategoriasNotifier.new,
);

/// Notificador para la categoría seleccionada como filtro.
class CategoriaSeleccionadaNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void seleccionar(int? id) => state = id;
}

/// Proveedor para la categoría seleccionada actualmente en la búsqueda/lista.
final categoriaSeleccionadaProvider = NotifierProvider<CategoriaSeleccionadaNotifier, int?>(
  CategoriaSeleccionadaNotifier.new,
);
