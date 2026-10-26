import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/categoria.dart';
import '../models/ficha.dart';
import '../models/bloque_contenido.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/ficha_repository.dart';

/// Servicio encargado de empaquetar y restaurar copias de seguridad completas:
/// Base de datos (Categorías, Fichas, Etiquetas) + Imágenes reales codificadas en Base64.
/// Permite que un solo archivo JSON contenga TODO el contenido multimedia y se pueda
/// mover a cualquier dispositivo o subir a Google Drive sin perder ninguna foto.
class BackupPackageService {
  final CategoriaRepository _categoriaRepo;
  final FichaRepository _fichaRepo;

  BackupPackageService({
    required CategoriaRepository categoriaRepo,
    required FichaRepository fichaRepo,
  })  : _categoriaRepo = categoriaRepo,
        _fichaRepo = fichaRepo;

  /// Genera un mapa completo con todas las categorías, fichas, etiquetas y las
  /// imágenes físicas (portadas, recortes y anexos) codificadas en base64.
  Future<Map<String, dynamic>> generarPaqueteCompleto() async {
    final categorias = await _categoriaRepo.obtenerTodas();
    final fichas = await _fichaRepo.obtenerTodas();

    final Map<String, String> imagenesBase64 = {};

    // 1. Recolectar y codificar imágenes de portada y anexos de fichas
    for (final f in fichas) {
      if (f.rutaImagen != null && f.rutaImagen!.isNotEmpty) {
        await _procesarYCodificarArchivo(f.rutaImagen!, imagenesBase64);
      }

      // Procesar bloques de imágenes incrustadas dentro de la ficha
      if (f.descripcion != null && f.descripcion!.isNotEmpty) {
        final contenido = BloquesContenidoHelper.desempaquetar(f.descripcion);
        for (final b in contenido.bloques) {
          if (b.tipo == TipoBloqueContenido.imagen && b.valor.isNotEmpty) {
            await _procesarYCodificarArchivo(b.valor, imagenesBase64);
          }
        }
      }
    }

    // 2. Recolectar imágenes de fondo de categorías
    for (final c in categorias) {
      if (c.rutaImagenFondo != null && c.rutaImagenFondo!.isNotEmpty) {
        await _procesarYCodificarArchivo(c.rutaImagenFondo!, imagenesBase64);
      }
    }

    return {
      'formato': 'simplista_paquete_completo',
      'version': 3,
      'fecha_creacion': DateTime.now().toIso8601String(),
      'total_fichas': fichas.length,
      'total_categorias': categorias.length,
      'total_imagenes': imagenesBase64.length,
      'categorias': categorias.map((c) => c.toMap()).toList(),
      'fichas': fichas
          .map((f) => {
                ...f.toMap(),
                'etiquetas': f.etiquetas.map((e) => e.nombre).toList(),
              })
          .toList(),
      'archivos_multimedia': imagenesBase64,
    };
  }

  /// Lee el archivo de imagen del almacenamiento y lo almacena con su nombre base en el mapa base64.
  Future<void> _procesarYCodificarArchivo(
    String ruta,
    Map<String, String> mapaDestino,
  ) async {
    if (kIsWeb) return;
    try {
      final file = File(ruta);
      if (await file.exists()) {
        final nombreBase = p.basename(ruta);
        if (!mapaDestino.containsKey(nombreBase)) {
          final bytes = await file.readAsBytes();
          mapaDestino[nombreBase] = base64Encode(bytes);
        }
      }
    } catch (_) {}
  }

  /// Restaura todas las categorías, fichas, etiquetas e imágenes en el almacenamiento
  /// interno de la app, corrigiendo dinámicamente las rutas para que coincidan con el nuevo dispositivo.
  Future<Map<String, int>> restaurarPaqueteCompleto(Map<String, dynamic> paquete) async {
    final categoriasRaw = paquete['categorias'] as List<dynamic>? ?? [];
    final fichasRaw = paquete['fichas'] as List<dynamic>? ?? [];
    final multimediaRaw = paquete['archivos_multimedia'] as Map<String, dynamic>? ?? {};

    // 1. Extraer y escribir todas las imágenes en el directorio permanente del nuevo dispositivo
    final Map<String, String> mapeoRutasNuevas = {};
    if (!kIsWeb && multimediaRaw.isNotEmpty) {
      final docDir = await getApplicationDocumentsDirectory();
      final carpetaImagenes = Directory(p.join(docDir.path, 'imagenes'));
      if (!await carpetaImagenes.exists()) {
        await carpetaImagenes.create(recursive: true);
      }

      for (final entry in multimediaRaw.entries) {
        final nombreArchivo = entry.key;
        final base64String = entry.value.toString();
        try {
          final bytes = base64Decode(base64String);
          final archivoDestino = File(p.join(carpetaImagenes.path, nombreArchivo));
          await archivoDestino.writeAsBytes(bytes, flush: true);
          mapeoRutasNuevas[nombreArchivo] = archivoDestino.path;
        } catch (_) {}
      }
    }

    // 2. Restaurar Categorías
    int categoriasRestauradas = 0;
    for (final item in categoriasRaw) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        if (m['ruta_imagen_fondo'] != null) {
          final nombre = p.basename(m['ruta_imagen_fondo'].toString());
          if (mapeoRutasNuevas.containsKey(nombre)) {
            m['ruta_imagen_fondo'] = mapeoRutasNuevas[nombre];
          }
        }
        final cat = Categoria.fromMap(m);
        await _categoriaRepo.insertar(cat);
        categoriasRestauradas++;
      }
    }

    // 3. Restaurar Fichas y actualizar las rutas de sus imágenes
    int fichasRestauradas = 0;
    for (final item in fichasRaw) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        final tags =
            (m['etiquetas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        // Ajustar ruta de imagen principal/portada
        if (m['ruta_imagen'] != null && m['ruta_imagen'].toString().isNotEmpty) {
          final nombre = p.basename(m['ruta_imagen'].toString());
          if (mapeoRutasNuevas.containsKey(nombre)) {
            m['ruta_imagen'] = mapeoRutasNuevas[nombre];
          }
        }

        // Ajustar rutas dentro de bloques modulares si existen
        if (m['descripcion'] != null && m['descripcion'].toString().isNotEmpty) {
          final desc = m['descripcion'].toString();
          if (desc.startsWith('{') && desc.contains('"bloques"')) {
            try {
              final contenido = BloquesContenidoHelper.desempaquetar(desc);
              final nuevosBloques = contenido.bloques.map((b) {
                if (b.tipo == TipoBloqueContenido.imagen) {
                  final nom = p.basename(b.valor);
                  if (mapeoRutasNuevas.containsKey(nom)) {
                    return BloqueContenido(
                      id: b.id,
                      tipo: b.tipo,
                      valor: mapeoRutasNuevas[nom]!,
                      proporcionAncho: b.proporcionAncho,
                      subtitulo: b.subtitulo,
                      modoIncrustacion: b.modoIncrustacion,
                    );
                  }
                }
                return b;
              }).toList();

              m['descripcion'] = BloquesContenidoHelper.empaquetar(
                contenido.notaPrincipal,
                nuevosBloques,
              );
            } catch (_) {}
          }
        }

        final nuevaFicha = Ficha.fromMap(m);
        await _fichaRepo.restaurarFicha(nuevaFicha, nombresEtiquetas: tags);
        fichasRestauradas++;
      }
    }

    return {
      'categorias': categoriasRestauradas,
      'fichas': fichasRestauradas,
      'imagenes': mapeoRutasNuevas.length,
    };
  }

  /// Guarda el paquete completo en el almacenamiento local como archivo listo para Drive o respaldo.
  Future<File> guardarPaqueteEnArchivo({String? prefijo}) async {
    final paquete = await generarPaqueteCompleto();
    final jsonStr = jsonEncode(paquete);

    final dir = await getApplicationDocumentsDirectory();
    final nombre = '${prefijo ?? "simplista_backup"}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(p.join(dir.path, nombre));
    await file.writeAsString(jsonStr, flush: true);

    // Intentar replicar también en Descargas para acceso fácil del usuario
    if (!kIsWeb) {
      try {
        final dirDescargas = Directory('/storage/emulated/0/Download');
        if (await dirDescargas.exists()) {
          final fileDescargas = File(p.join(dirDescargas.path, nombre));
          await fileDescargas.writeAsString(jsonStr, flush: true);
        }
      } catch (_) {}
    }

    return file;
  }
}
