import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archivador_digital/core/database/app_database.dart';
import 'package:archivador_digital/models/categoria.dart';
import 'package:archivador_digital/models/ficha.dart';
import 'package:archivador_digital/repositories/categoria_repository.dart';
import 'package:archivador_digital/repositories/etiqueta_repository.dart';
import 'package:archivador_digital/repositories/ficha_repository.dart';

void main() {
  // Inicialización de FFI para ejecutar SQLite en pruebas locales
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late CategoriaRepository categoriaRepo;
  late EtiquetaRepository etiquetaRepo;
  late FichaRepository fichaRepo;

  setUp(() async {
    // Usamos una base de datos en memoria para cada prueba
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          // Tablas
          await db.execute('''
            CREATE TABLE ${AppDatabase.tablaCategorias} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL,
              descripcion TEXT,
              color_hex TEXT NOT NULL DEFAULT '#2196F3'
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

          // Categorías iniciales
          await db.insert(AppDatabase.tablaCategorias, {
            'nombre': 'General',
            'descripcion': 'Fichas y documentos generales',
            'color_hex': '#4CAF50',
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

  group('Pruebas CRUD SQLite - Archivador Digital', () {
    test('CRUD de Categorias', () async {
      // 1. Lectura inicial (categoría por defecto)
      final iniciales = await categoriaRepo.obtenerTodas();
      expect(iniciales.length, 1);
      expect(iniciales.first.nombre, 'General');

      // 2. Inserción
      final nuevaCat = Categoria(
        nombre: 'Finanzas',
        descripcion: 'Gastos e impuestos',
        colorHex: '#9C27B0',
      );
      final idInsertado = await categoriaRepo.insertar(nuevaCat);
      expect(idInsertado, greaterThan(0));

      final categoriaConsultada = await categoriaRepo.obtenerPorId(idInsertado);
      expect(categoriaConsultada, isNotNull);
      expect(categoriaConsultada!.nombre, 'Finanzas');

      // 3. Actualización
      final catActualizada = categoriaConsultada.copyWith(
        nombre: 'Finanzas Personales',
      );
      await categoriaRepo.actualizar(catActualizada);
      final catVerificada = await categoriaRepo.obtenerPorId(idInsertado);
      expect(catVerificada!.nombre, 'Finanzas Personales');

      // 4. Eliminación
      await categoriaRepo.eliminar(idInsertado);
      final catEliminada = await categoriaRepo.obtenerPorId(idInsertado);
      expect(catEliminada, isNull);
    });

    test('CRUD de Etiquetas', () async {
      final tag1 = await etiquetaRepo.obtenerOCrear('Urgente');
      final tag2 = await etiquetaRepo.obtenerOCrear('Urgente');
      expect(tag1.id, equals(tag2.id));

      final todas = await etiquetaRepo.obtenerTodas();
      expect(todas.length, 1);
      expect(todas.first.nombre, 'Urgente');

      await etiquetaRepo.eliminar(tag1.id!);
      final vacias = await etiquetaRepo.obtenerTodas();
      expect(vacias.isEmpty, isTrue);
    });

    test('CRUD de Fichas y Relaciones con Etiquetas', () async {
      final ahora = DateTime.now();

      // 1. Inserción de ficha con etiquetas
      final nuevaFicha = Ficha(
        titulo: 'Factura de Luz',
        descripcion: 'Factura de electricidad de enero',
        categoriaId: 1, // Categoría 'General'
        fechaCreacion: ahora,
        fechaModificacion: ahora,
        rutaImagen: '/imagenes/factura_luz.jpg',
      );

      final fichaId = await fichaRepo.insertar(
        nuevaFicha,
        nombresEtiquetas: ['Servicios', 'Hogar', 'Urgente'],
      );
      expect(fichaId, greaterThan(0));

      // 2. Consulta y verificación de relaciones
      final fichaObtenida = await fichaRepo.obtenerPorId(fichaId);
      expect(fichaObtenida, isNotNull);
      expect(fichaObtenida!.titulo, 'Factura de Luz');
      expect(fichaObtenida.nombreCategoria, 'General');
      expect(fichaObtenida.etiquetas.length, 3);
      expect(fichaObtenida.etiquetas.map((e) => e.nombre), containsAll(['Servicios', 'Hogar', 'Urgente']));

      // 3. Búsqueda y filtrado
      final busquedaCoincidente = await fichaRepo.obtenerTodas(busqueda: 'electricidad');
      expect(busquedaCoincidente.length, 1);

      final busquedaNoCoincidente = await fichaRepo.obtenerTodas(busqueda: 'agua');
      expect(busquedaNoCoincidente.isEmpty, isTrue);

      // 4. Actualización de ficha y sus etiquetas
      final fichaModificada = fichaObtenida.copyWith(
        titulo: 'Factura de Luz - Pagada',
        fechaModificacion: DateTime.now(),
      );
      await fichaRepo.actualizar(
        fichaModificada,
        nuevosNombresEtiquetas: ['Servicios', 'Pagado'],
      );

      final fichaActualizada = await fichaRepo.obtenerPorId(fichaId);
      expect(fichaActualizada!.titulo, 'Factura de Luz - Pagada');
      expect(fichaActualizada.etiquetas.length, 2);
      expect(fichaActualizada.etiquetas.map((e) => e.nombre), containsAll(['Servicios', 'Pagado']));

      // 5. Verificación de borrado en cascada en la tabla Relaciones
      await fichaRepo.eliminar(fichaId);
      final relacionesRestantes = await db.query(
        AppDatabase.tablaRelaciones,
        where: 'ficha_id = ?',
        whereArgs: [fichaId],
      );
      expect(relacionesRestantes.isEmpty, isTrue);
    });
  });
}
