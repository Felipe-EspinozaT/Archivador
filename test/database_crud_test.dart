import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:simplista/core/database/app_database.dart';
import 'package:simplista/models/categoria.dart';
import 'package:simplista/models/ficha.dart';
import 'package:simplista/repositories/categoria_repository.dart';
import 'package:simplista/repositories/etiqueta_repository.dart';
import 'package:simplista/repositories/ficha_repository.dart';

void main() {
  // Inicialización de FFI para ejecutar SQLite en pruebas locales
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late CategoriaRepository categoriaRepo;
  late EtiquetaRepository etiquetaRepo;
  late FichaRepository fichaRepo;

  setUp(() async {
    // Usamos una base de datos en memoria para cada prueba con el esquema actualizado v2
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          // Tablas con soporte de orden y fondo
          await db.execute('''
            CREATE TABLE ${AppDatabase.tablaCategorias} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL,
              descripcion TEXT,
              color_hex TEXT NOT NULL DEFAULT '#2196F3',
              orden INTEGER NOT NULL DEFAULT 0,
              ruta_imagen_fondo TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE ${AppDatabase.tablaFichas} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              titulo TEXT NOT NULL,
              descripcion TEXT,
              categoria_id INTEGER,
              fecha_creacion TEXT NOT NULL,
              fecha_modificacion TEXT NOT NULL,
              ruta_imagen TEXT,
              FOREIGN KEY (categoria_id) REFERENCES ${AppDatabase.tablaCategorias} (id) ON DELETE SET NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE ${AppDatabase.tablaEtiquetas} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL UNIQUE
            )
          ''');

          await db.execute('''
            CREATE TABLE ${AppDatabase.tablaRelaciones} (
              ficha_id INTEGER NOT NULL,
              etiqueta_id INTEGER NOT NULL,
              PRIMARY KEY (ficha_id, etiqueta_id),
              FOREIGN KEY (ficha_id) REFERENCES ${AppDatabase.tablaFichas} (id) ON DELETE CASCADE,
              FOREIGN KEY (etiqueta_id) REFERENCES ${AppDatabase.tablaEtiquetas} (id) ON DELETE CASCADE
            )
          ''');

          // Categorías iniciales con orden
          await db.insert(AppDatabase.tablaCategorias, {
            'nombre': 'General',
            'descripcion': 'Fichas y documentos generales',
            'color_hex': '#4CAF50',
            'orden': 0,
          });
        },
      ),
    );

    AppDatabase.configurarBaseDatosParaPruebas(db);
    categoriaRepo = CategoriaRepository();
    etiquetaRepo = EtiquetaRepository();
    fichaRepo = FichaRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('Pruebas CRUD SQLite - Simplista', () {
    test('CRUD y Reordenamiento de Categorias', () async {
      // 1. Lectura inicial (categoría por defecto)
      final iniciales = await categoriaRepo.obtenerTodas();
      expect(iniciales.length, 1);
      expect(iniciales.first.nombre, 'General');
      expect(iniciales.first.orden, 0);

      // 2. Inserción con orden y ruta_imagen_fondo
      final nuevaCat = const Categoria(
        nombre: 'Finanzas',
        descripcion: 'Gastos e impuestos',
        colorHex: '#9C27B0',
        orden: 1,
        rutaImagenFondo: '/imagenes/fondo_finanzas.png',
      );
      final idInsertado = await categoriaRepo.insertar(nuevaCat);
      expect(idInsertado, greaterThan(0));

      final categoriaConsultada = await categoriaRepo.obtenerPorId(idInsertado);
      expect(categoriaConsultada, isNotNull);
      expect(categoriaConsultada!.nombre, 'Finanzas');
      expect(categoriaConsultada.rutaImagenFondo, '/imagenes/fondo_finanzas.png');

      // 3. Probar reordenamiento (actualizarOrden)
      final catA = categoriaConsultada.copyWith(orden: 0);
      final catB = iniciales.first.copyWith(orden: 1);
      await categoriaRepo.actualizarOrden([catA, catB]);

      final reordenadas = await categoriaRepo.obtenerTodas();
      expect(reordenadas.first.nombre, 'Finanzas');
      expect(reordenadas.last.nombre, 'General');

      // 4. Actualización
      final catActualizada = categoriaConsultada.copyWith(
        nombre: 'Finanzas Personales',
      );
      await categoriaRepo.actualizar(catActualizada);
      final catVerificada = await categoriaRepo.obtenerPorId(idInsertado);
      expect(catVerificada!.nombre, 'Finanzas Personales');

      // 5. Eliminación
      await categoriaRepo.eliminar(idInsertado);
      final catEliminada = await categoriaRepo.obtenerPorId(idInsertado);
      expect(catEliminada, isNull);
    });

    test('CRUD de Etiquetas', () async {
      final et1 = await etiquetaRepo.obtenerOCrear('Urgente');
      expect(et1.id, greaterThan(0));
      expect(et1.nombre, 'Urgente');

      // Idempotencia: obtener la misma etiqueta no debe duplicar
      final et2 = await etiquetaRepo.obtenerOCrear('urgente');
      expect(et2.id, et1.id);

      final todas = await etiquetaRepo.obtenerTodas();
      expect(todas.length, 1);
    });

    test('CRUD de Fichas y Relaciones con Etiquetas', () async {
      final ahora = DateTime.now();
      final ficha = Ficha(
        titulo: 'DNI Digital',
        descripcion: 'Documento nacional de identidad',
        categoriaId: 1,
        fechaCreacion: ahora,
        fechaModificacion: ahora,
        rutaImagen: '/imagenes/dni.jpg',
      );

      // Inserción con etiquetas
      final idFicha = await fichaRepo.insertar(
        ficha,
        nombresEtiquetas: ['Personal', 'Legal'],
      );
      expect(idFicha, greaterThan(0));

      // Consulta de la ficha con sus etiquetas
      final fichaConsultada = await fichaRepo.obtenerPorId(idFicha);
      expect(fichaConsultada, isNotNull);
      expect(fichaConsultada!.titulo, 'DNI Digital');
      expect(fichaConsultada.etiquetas.length, 2);
      expect(
        fichaConsultada.etiquetas.map((e) => e.nombre).toSet(),
        containsAll({'Personal', 'Legal'}),
      );

      // Actualización de etiquetas
      await fichaRepo.actualizar(
        fichaConsultada.copyWith(titulo: 'DNI Renovado'),
        nuevosNombresEtiquetas: ['Legal', 'Renovado'],
      );

      final fichaActualizada = await fichaRepo.obtenerPorId(idFicha);
      expect(fichaActualizada!.titulo, 'DNI Renovado');
      expect(fichaActualizada.etiquetas.length, 2);
      expect(
        fichaActualizada.etiquetas.map((e) => e.nombre).toSet(),
        containsAll({'Legal', 'Renovado'}),
      );

      // Eliminación en cascada de relaciones
      await fichaRepo.eliminar(idFicha);
      final fichaEliminada = await fichaRepo.obtenerPorId(idFicha);
      expect(fichaEliminada, isNull);

      final etiquetasFichaEliminada = await etiquetaRepo.obtenerPorFichaId(idFicha);
      expect(etiquetasFichaEliminada, isEmpty);
    });
  });
}
