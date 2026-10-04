import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/etiqueta_repository.dart';
import '../repositories/ficha_repository.dart';
import '../services/storage_service.dart';

/// Proveedor para la instancia de base de datos
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instancia;
});

/// Proveedor para el repositorio de categorías
final categoriaRepositoryProvider = Provider<CategoriaRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoriaRepository(dbProvider: db);
});

/// Proveedor para el repositorio de etiquetas
final etiquetaRepositoryProvider = Provider<EtiquetaRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return EtiquetaRepository(dbProvider: db);
});

/// Proveedor para el repositorio de fichas
final fichaRepositoryProvider = Provider<FichaRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final etiquetaRepo = ref.watch(etiquetaRepositoryProvider);
  return FichaRepository(dbProvider: db, etiquetaRepo: etiquetaRepo);
});

/// Proveedor para el servicio de almacenamiento de imágenes
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
