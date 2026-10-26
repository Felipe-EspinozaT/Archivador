import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/etiqueta_repository.dart';
import '../repositories/ficha_repository.dart';
import '../services/storage_service.dart';
import '../services/backup_package_service.dart';

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

/// Proveedor para el servicio de empaquetado y respaldo completo (datos + imágenes)
final backupPackageServiceProvider = Provider<BackupPackageService>((ref) {
  final catRepo = ref.watch(categoriaRepositoryProvider);
  final fichaRepo = ref.watch(fichaRepositoryProvider);
  return BackupPackageService(
    categoriaRepo: catRepo,
    fichaRepo: fichaRepo,
  );
});
