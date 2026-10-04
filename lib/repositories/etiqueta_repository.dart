import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../models/etiqueta.dart';

/// Repositorio para operaciones CRUD sobre la tabla Etiquetas.
class EtiquetaRepository {
  final AppDatabase _dbProvider;

  EtiquetaRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instancia;

  Future<Database> get _db async => await _dbProvider.database;

  /// Obtiene todas las etiquetas registradas.
  Future<List<Etiqueta>> obtenerTodas() async {
    final db = await _db;
    final resultado = await db.query(
      AppDatabase.tablaEtiquetas,
      orderBy: 'nombre ASC',
    );
    return resultado.map((mapa) => Etiqueta.fromMap(mapa)).toList();
  }

  /// Inserta una nueva etiqueta o retorna la existente si ya tiene ese nombre.
  Future<Etiqueta> obtenerOCrear(String nombre) async {
    final nombreLimpio = nombre.trim();
    final db = await _db;
    final existente = await db.query(
      AppDatabase.tablaEtiquetas,
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [nombreLimpio],
      limit: 1,
    );

    if (existente.isNotEmpty) {
      return Etiqueta.fromMap(existente.first);
    }

    final id = await db.insert(
      AppDatabase.tablaEtiquetas,
      {'nombre': nombreLimpio},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return Etiqueta(id: id, nombre: nombreLimpio);
  }

  /// Obtiene las etiquetas asociadas a una ficha específica mediante la tabla Relaciones.
  Future<List<Etiqueta>> obtenerPorFichaId(int fichaId) async {
    final db = await _db;
    final resultado = await db.rawQuery('''
      SELECT e.id, e.nombre
      FROM ${AppDatabase.tablaEtiquetas} e
      INNER JOIN ${AppDatabase.tablaRelaciones} r ON e.id = r.etiqueta_id
      WHERE r.ficha_id = ?
      ORDER BY e.nombre ASC
    ''', [fichaId]);

    return resultado.map((mapa) => Etiqueta.fromMap(mapa)).toList();
  }

  /// Elimina una etiqueta por su ID.
  Future<int> eliminar(int id) async {
    final db = await _db;
    return await db.delete(
      AppDatabase.tablaEtiquetas,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
