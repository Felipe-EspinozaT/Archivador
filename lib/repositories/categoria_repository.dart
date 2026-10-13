import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../models/categoria.dart';

/// Repositorio para operaciones CRUD y reordenamiento sobre la tabla Categorias en SQLite.
class CategoriaRepository {
  final AppDatabase _dbProvider;

  CategoriaRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instancia;

  Future<Database> get _db async => await _dbProvider.database;

  /// Obtiene todas las categorías ordenadas por prioridad de orden ascendente.
  Future<List<Categoria>> obtenerTodas() async {
    final db = await _db;
    final resultado = await db.query(
      AppDatabase.tablaCategorias,
      orderBy: 'orden ASC, id ASC',
    );
    return resultado.map((mapa) => Categoria.fromMap(mapa)).toList();
  }

  /// Obtiene o crea la categoría reservada 'Errante'.
  Future<Categoria> obtenerOCrearErrante() async {
    final db = await _db;
    final res = await db.query(
      AppDatabase.tablaCategorias,
      where: 'nombre = ?',
      whereArgs: [AppDatabase.categoriaErranteNombre],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return Categoria.fromMap(res.first);
    }
    final maxRes = await db.rawQuery(
      'SELECT MAX(orden) as max_orden FROM ${AppDatabase.tablaCategorias}',
    );
    final maxVal = maxRes.first['max_orden'] as int?;
    final ordenFinal = (maxVal ?? -1) + 1;
    final id = await db.insert(AppDatabase.tablaCategorias, {
      'nombre': AppDatabase.categoriaErranteNombre,
      'descripcion': 'Fichas sin categoría asignada',
      'color_hex': '#9E9E9E',
      'orden': ordenFinal,
      'ruta_imagen_fondo': null,
    });
    return Categoria(
      id: id,
      nombre: AppDatabase.categoriaErranteNombre,
      descripcion: 'Fichas sin categoría asignada',
      colorHex: '#9E9E9E',
      orden: ordenFinal,
    );
  }

  /// Obtiene una categoría por su ID.
  Future<Categoria?> obtenerPorId(int id) async {
    final db = await _db;
    final resultado = await db.query(
      AppDatabase.tablaCategorias,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (resultado.isNotEmpty) {
      return Categoria.fromMap(resultado.first);
    }
    return null;
  }

  /// Inserta una nueva categoría colocándola al final del orden.
  Future<int> insertar(Categoria categoria) async {
    final db = await _db;
    int ordenFinal = categoria.orden;
    if (ordenFinal == 0) {
      final maxRes = await db.rawQuery(
        'SELECT MAX(orden) as max_orden FROM ${AppDatabase.tablaCategorias}',
      );
      final maxVal = maxRes.first['max_orden'] as int?;
      ordenFinal = (maxVal ?? -1) + 1;
    }
    return await db.insert(
      AppDatabase.tablaCategorias,
      categoria.copyWith(orden: ordenFinal).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Actualiza una categoría existente.
  Future<int> actualizar(Categoria categoria) async {
    final db = await _db;
    return await db.update(
      AppDatabase.tablaCategorias,
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  /// Actualiza en lote el campo de orden de una lista de categorías para persistir su prioridad.
  Future<void> actualizarOrden(List<Categoria> categorias) async {
    final db = await _db;
    final batch = db.batch();
    for (int i = 0; i < categorias.length; i++) {
      final cat = categorias[i];
      if (cat.id != null) {
        batch.update(
          AppDatabase.tablaCategorias,
          {'orden': i},
          where: 'id = ?',
          whereArgs: [cat.id],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Elimina una categoría por su ID.
  /// Si [eliminarFichasDependientes] es true, elimina las fichas de esa categoría (y sus imágenes en servicio).
  /// Si es false, reasigna las fichas dependientes a la categoría reservada 'Errante'.
  Future<int> eliminar(int id, {bool eliminarFichasDependientes = false}) async {
    final db = await _db;
    return await db.transaction<int>((txn) async {
      final cat = await txn.query(
        AppDatabase.tablaCategorias,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      // No permitir eliminar la categoría Errante
      if (cat.isNotEmpty && cat.first['nombre'] == AppDatabase.categoriaErranteNombre) {
        return 0;
      }

      if (eliminarFichasDependientes) {
        // Eliminar fichas dependientes
        await txn.delete(
          AppDatabase.tablaFichas,
          where: 'categoria_id = ?',
          whereArgs: [id],
        );
      } else {
        // Reasignar fichas a la categoría 'Errante'
        final errante = await txn.query(
          AppDatabase.tablaCategorias,
          where: 'nombre = ?',
          whereArgs: [AppDatabase.categoriaErranteNombre],
          limit: 1,
        );
        int erranteId;
        if (errante.isNotEmpty) {
          erranteId = errante.first['id'] as int;
        } else {
          erranteId = await txn.insert(AppDatabase.tablaCategorias, {
            'nombre': AppDatabase.categoriaErranteNombre,
            'descripcion': 'Fichas sin categoría asignada',
            'color_hex': '#9E9E9E',
            'orden': 999,
          });
        }

        await txn.update(
          AppDatabase.tablaFichas,
          {'categoria_id': erranteId},
          where: 'categoria_id = ?',
          whereArgs: [id],
        );
      }

      // Eliminar la categoría
      return await txn.delete(
        AppDatabase.tablaCategorias,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
