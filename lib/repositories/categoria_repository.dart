import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../models/categoria.dart';

/// Repositorio para operaciones CRUD sobre la tabla Categorias en SQLite.
class CategoriaRepository {
  final AppDatabase _dbProvider;

  CategoriaRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instancia;

  Future<Database> get _db async => await _dbProvider.database;

  /// Obtiene todas las categorías ordenadas por nombre.
  Future<List<Categoria>> obtenerTodas() async {
    final db = await _db;
    final resultado = await db.query(
      AppDatabase.tablaCategorias,
      orderBy: 'nombre ASC',
    );
    return resultado.map((mapa) => Categoria.fromMap(mapa)).toList();
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

  /// Inserta una nueva categoría.
  Future<int> insertar(Categoria categoria) async {
    final db = await _db;
    return await db.insert(
      AppDatabase.tablaCategorias,
      categoria.toMap(),
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

  /// Elimina una categoría por su ID.
  Future<int> eliminar(int id) async {
    final db = await _db;
    return await db.delete(
      AppDatabase.tablaCategorias,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
