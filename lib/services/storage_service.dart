import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Servicio responsable del almacenamiento y gestión de imágenes locales en el dispositivo.
class StorageService {
  static const String carpetaImagenes = 'imagenes';

  /// Obtiene o crea la carpeta local '/imagenes/' en el directorio privado de la aplicación.
  Future<String> obtenerRutaDirectorioImagenes() async {
    if (kIsWeb) {
      return carpetaImagenes;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final rutaCarpeta = p.join(docDir.path, carpetaImagenes);
    final carpeta = Directory(rutaCarpeta);

    if (!await carpeta.exists()) {
      await carpeta.create(recursive: true);
    }

    return carpeta.path;
  }

  /// Guarda una imagen desde un archivo de origen en la carpeta local '/imagenes/'.
  /// Retorna la ruta absoluta del archivo almacenado para registrarla en SQLite.
  Future<String> guardarImagen(File archivoOrigen) async {
    if (kIsWeb) {
      // En entorno Web se almacena la referencia del path o URI
      return archivoOrigen.path;
    }

    final rutaCarpeta = await obtenerRutaDirectorioImagenes();
    final extensionArchivo = p.extension(archivoOrigen.path).isNotEmpty
        ? p.extension(archivoOrigen.path)
        : '.jpg';

    final nombreUnico = 'img_${DateTime.now().millisecondsSinceEpoch}$extensionArchivo';
    final rutaDestino = p.join(rutaCarpeta, nombreUnico);

    // Copia el archivo al directorio interno protegido de la app
    final archivoGuardado = await archivoOrigen.copy(rutaDestino);
    return archivoGuardado.path;
  }

  /// Guarda una imagen a partir de una lista de bytes en la carpeta '/imagenes/'.
  Future<String> guardarImagenDesdeBytes(Uint8List bytes, {String extensionArchivo = '.jpg'}) async {
    if (kIsWeb) {
      return 'web_img_${DateTime.now().millisecondsSinceEpoch}$extensionArchivo';
    }

    final rutaCarpeta = await obtenerRutaDirectorioImagenes();
    final nombreUnico = 'img_${DateTime.now().millisecondsSinceEpoch}$extensionArchivo';
    final rutaDestino = p.join(rutaCarpeta, nombreUnico);

    final archivo = File(rutaDestino);
    await archivo.writeAsBytes(bytes);
    return archivo.path;
  }

  /// Elimina una imagen del almacenamiento local si existe.
  Future<bool> eliminarImagen(String? rutaArchivo) async {
    if (rutaArchivo == null || rutaArchivo.trim().isEmpty || kIsWeb) return false;

    try {
      final archivo = File(rutaArchivo);
      if (await archivo.exists()) {
        await archivo.delete();
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /// Verifica si el archivo en la ruta dada existe en el almacenamiento.
  Future<bool> existeImagen(String? rutaArchivo) async {
    if (rutaArchivo == null || rutaArchivo.trim().isEmpty) return false;
    if (kIsWeb) return true;
    return await File(rutaArchivo).exists();
  }
}
