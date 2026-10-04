import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Manejador principal de la base de datos SQLite para el Archivador Digital (Multiplataforma: Android, Windows y Web).
class AppDatabase {
  static const String _nombreBaseDatos = 'archivador_digital.db';
  static const int _versionBaseDatos = 1;

  // Nombres de tablas
  static const String tablaCategorias = 'categorias';
  static const String tablaFichas = 'fichas';
  static const String tablaEtiquetas = 'etiquetas';
  static const String tablaRelaciones = 'relaciones';

  // Instancia única (Singleton)
  static final AppDatabase instancia = AppDatabase._inicializar();
  static Database? _database;

  AppDatabase._inicializar();

  /// Obtiene la instancia activa de la base de datos o la inicializa si aún no existe.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _abrirBaseDatos();
    return _database!;
  }

  /// Permite inyectar una base de datos para pruebas.
  static void configurarBaseDatosParaPruebas(Database db) {
    _database = db;
  }

  Future<Database> _abrirBaseDatos() async {
    String ruta;

    if (kIsWeb) {
      // Configuración para entorno Web (IndexedDB backing)
      databaseFactory = databaseFactoryFfiWeb;
      ruta = _nombreBaseDatos;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Configuración para entorno de escritorio
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directorio = await getApplicationDocumentsDirectory();
      ruta = join(directorio.path, _nombreBaseDatos);
    } else {
      // Configuración nativa para Android e iOS: usar getDatabasesPath() es el estándar sqflite
      final dbPath = await getDatabasesPath();
      ruta = join(dbPath, _nombreBaseDatos);
    }

    return await databaseFactory.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: _versionBaseDatos,
        onConfigure: _configurarPragmas,
        onCreate: _crearTablas,
      ),
    );
  }

  /// Configuración de claves foráneas en SQLite.
  static Future<void> _configurarPragmas(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Creación de la estructura de tablas inicial.
  static Future<void> _crearTablas(Database db, int version) async {
    // 1. Tabla Categorias
    await db.execute('''
      CREATE TABLE $tablaCategorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        color_hex TEXT NOT NULL DEFAULT '#2196F3'
      )
    ''');

    // 2. Tabla Fichas
    await db.execute('''
      CREATE TABLE $tablaFichas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        descripcion TEXT,
        categoria_id INTEGER,
        fecha_creacion TEXT NOT NULL,
        fecha_modificacion TEXT NOT NULL,
        ruta_imagen TEXT,
        FOREIGN KEY (categoria_id) REFERENCES $tablaCategorias (id) ON DELETE SET NULL
      )
    ''');

    // 3. Tabla Etiquetas
    await db.execute('''
      CREATE TABLE $tablaEtiquetas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    // 4. Tabla Relaciones (Muchos a Muchos entre Fichas y Etiquetas)
    await db.execute('''
      CREATE TABLE $tablaRelaciones (
        ficha_id INTEGER NOT NULL,
        etiqueta_id INTEGER NOT NULL,
        PRIMARY KEY (ficha_id, etiqueta_id),
        FOREIGN KEY (ficha_id) REFERENCES $tablaFichas (id) ON DELETE CASCADE,
        FOREIGN KEY (etiqueta_id) REFERENCES $tablaEtiquetas (id) ON DELETE CASCADE
      )
    ''');

    // Insertar categorías iniciales por defecto
    await db.insert(tablaCategorias, {
      'nombre': 'General',
      'descripcion': 'Fichas y documentos generales',
      'color_hex': '#4CAF50',
    });
    await db.insert(tablaCategorias, {
      'nombre': 'Documentos',
      'descripcion': 'Contratos, identificaciones y certificados',
      'color_hex': '#2196F3',
    });
    await db.insert(tablaCategorias, {
      'nombre': 'Recibos',
      'descripcion': 'Facturas, boletas y comprobantes de pago',
      'color_hex': '#FF9800',
    });
    await db.insert(tablaCategorias, {
      'nombre': 'Recuerdos',
      'descripcion': 'Fotos, postales y memorias',
      'color_hex': '#E91E63',
    });
  }

  /// Cierra la conexión con la base de datos.
  Future<void> cerrar() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
