import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../models/ficha.dart';
import 'etiqueta_repository.dart';

/// Repositorio para operaciones CRUD sobre la tabla Fichas y sus Relaciones con Etiquetas.
class FichaRepository {
  final AppDatabase _dbProvider;
  final EtiquetaRepository _etiquetaRepo;

  FichaRepository({
    AppDatabase? dbProvider,
    EtiquetaRepository? etiquetaRepo,
  })  : _dbProvider = dbProvider ?? AppDatabase.instancia,
        _etiquetaRepo = etiquetaRepo ?? EtiquetaRepository(dbProvider: dbProvider);

  Future<Database> get _db async => await _dbProvider.database;

  /// Obtiene todas las fichas con sus datos de categoría y lista de etiquetas.
  Future<List<Ficha>> obtenerTodas({int? categoriaId, String? busqueda}) async {
    final db = await _db;

    String query = '''
      SELECT f.*, c.nombre AS nombre_categoria, c.color_hex AS color_categoria
      FROM ${AppDatabase.tablaFichas} f
      LEFT JOIN ${AppDatabase.tablaCategorias} c ON f.categoria_id = c.id
    ''';

    List<dynamic> args = [];
    List<String> condiciones = [];

    if (categoriaId != null) {
      condiciones.add('f.categoria_id = ?');
      args.add(categoriaId);
    }

    if (busqueda != null && busqueda.trim().isNotEmpty) {
      condiciones.add('(f.titulo LIKE ? OR f.descripcion LIKE ?)');
      args.add('%$busqueda%');
      args.add('%$busqueda%');
    }

    if (condiciones.isNotEmpty) {
      query += ' WHERE ${condiciones.join(' AND ')}';
    }

    query += ' ORDER BY f.fecha_modificacion DESC';

    final filas = await db.rawQuery(query, args);

    List<Ficha> fichas = [];
    for (var fila in filas) {
      final fichaId = fila['id'] as int;
      final etiquetas = await _etiquetaRepo.obtenerPorFichaId(fichaId);
      fichas.add(Ficha.fromMap(fila, etiquetas: etiquetas));
    }

    return fichas;
  }

  /// Obtiene una ficha completa por su identificador.
  Future<Ficha?> obtenerPorId(int id) async {
    final db = await _db;
    final filas = await db.rawQuery('''
      SELECT f.*, c.nombre AS nombre_categoria, c.color_hex AS color_categoria
      FROM ${AppDatabase.tablaFichas} f
      LEFT JOIN ${AppDatabase.tablaCategorias} c ON f.categoria_id = c.id
      WHERE f.id = ?
      LIMIT 1
    ''', [id]);

    if (filas.isEmpty) return null;

    final etiquetas = await _etiquetaRepo.obtenerPorFichaId(id);
    return Ficha.fromMap(filas.first, etiquetas: etiquetas);
  }

  /// Inserta una nueva ficha y sus relaciones con etiquetas en una transacción atómica.
  Future<int> insertar(Ficha ficha, {List<String>? nombresEtiquetas}) async {
    final db = await _db;
    return await db.transaction<int>((txn) async {
      // 1. Insertar la ficha
      final idFicha = await txn.insert(
        AppDatabase.tablaFichas,
        ficha.toMap(),
      );

      // 2. Asociar etiquetas si se proporcionaron
      final tags = nombresEtiquetas ?? ficha.etiquetas.map((e) => e.nombre).toList();
      for (final nombre in tags) {
        if (nombre.trim().isEmpty) continue;
        
        // Buscar o crear etiqueta
        final existentes = await txn.query(
          AppDatabase.tablaEtiquetas,
          where: 'LOWER(nombre) = LOWER(?)',
          whereArgs: [nombre.trim()],
          limit: 1,
        );

        int tagId;
        if (existentes.isNotEmpty) {
          tagId = existentes.first['id'] as int;
        } else {
          tagId = await txn.insert(
            AppDatabase.tablaEtiquetas,
            {'nombre': nombre.trim()},
          );
        }

        // Crear la relación en la tabla 'relaciones'
        await txn.insert(
          AppDatabase.tablaRelaciones,
          {'ficha_id': idFicha, 'etiqueta_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      return idFicha;
    });
  }

  /// Actualiza una ficha existente y sincroniza sus etiquetas asociadas.
  Future<void> actualizar(Ficha ficha, {List<String>? nuevosNombresEtiquetas}) async {
    if (ficha.id == null) return;
    final db = await _db;

    await db.transaction((txn) async {
      // 1. Actualizar los campos de la ficha
      await txn.update(
        AppDatabase.tablaFichas,
        ficha.toMap(),
        where: 'id = ?',
        whereArgs: [ficha.id],
      );

      // 2. Si se pasaron etiquetas, actualizar la tabla de relaciones
      if (nuevosNombresEtiquetas != null) {
        // Eliminar relaciones previas
        await txn.delete(
          AppDatabase.tablaRelaciones,
          where: 'ficha_id = ?',
          whereArgs: [ficha.id],
        );

        // Insertar las nuevas
        for (final nombre in nuevosNombresEtiquetas) {
          if (nombre.trim().isEmpty) continue;

          final existentes = await txn.query(
            AppDatabase.tablaEtiquetas,
            where: 'LOWER(nombre) = LOWER(?)',
            whereArgs: [nombre.trim()],
            limit: 1,
          );

          int tagId;
          if (existentes.isNotEmpty) {
            tagId = existentes.first['id'] as int;
          } else {
            tagId = await txn.insert(
              AppDatabase.tablaEtiquetas,
              {'nombre': nombre.trim()},
            );
          }

          await txn.insert(
            AppDatabase.tablaRelaciones,
            {'ficha_id': ficha.id, 'etiqueta_id': tagId},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  /// Elimina una ficha (la restricción ON DELETE CASCADE elimina automáticamente sus relaciones).
  Future<int> eliminar(int id) async {
    final db = await _db;
    return await db.delete(
      AppDatabase.tablaFichas,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
