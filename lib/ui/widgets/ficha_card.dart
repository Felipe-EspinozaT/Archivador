import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/ficha.dart';
import 'etiqueta_chip.dart';

/// Tarjeta visual compacta y achatada para el carrusel horizontal superior de fichas recientes.
class FichaCard extends StatelessWidget {
  final Ficha ficha;
  final VoidCallback alPresionar;
  final double ancho;
  final double alto;

  const FichaCard({
    super.key,
    required this.ficha,
    required this.alPresionar,
    this.ancho = 82.0,
    this.alto = 75.0,
  });

  Color _obtenerColorCategoria(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF825385);
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF825385);
    }
  }

  ImageProvider? _obtenerImagenFondo(String? ruta) {
    if (ruta == null || ruta.isEmpty) return null;
    if (kIsWeb) {
      return NetworkImage(ruta);
    }
    return FileImage(File(ruta));
  }

  @override
  Widget build(BuildContext context) {
    final colorCat = _obtenerColorCategoria(ficha.colorCategoria);
    final tieneFondo = ficha.rutaImagen != null && ficha.rutaImagen!.isNotEmpty;
    final imagenFondo = _obtenerImagenFondo(ficha.rutaImagen);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: Container(
          width: ancho,
          height: alto,
          decoration: BoxDecoration(
            color: tieneFondo ? null : Colors.white,
            image: tieneFondo && imagenFondo != null
                ? DecorationImage(
                    image: imagenFondo,
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.48),
                      BlendMode.darken,
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!tieneFondo)
                CircleAvatar(
                  radius: 13,
                  backgroundColor: colorCat.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.description_outlined,
                    color: colorCat,
                    size: 15,
                  ),
                ),
              if (!tieneFondo) const SizedBox(height: 3),
              Text(
                ficha.titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tieneFondo ? Colors.white : Colors.black87,
                  shadows: tieneFondo
                      ? const [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black87,
                            offset: Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                maxLines: tieneFondo ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta vertical con detalles (miniatura, título, descripción y etiquetas)
/// para el listado vertical de fichas por categoría.
class FichaDetalleCard extends StatelessWidget {
  final Ficha ficha;
  final VoidCallback alPresionar;

  const FichaDetalleCard({
    super.key,
    required this.ficha,
    required this.alPresionar,
  });

  Color _obtenerColorCategoria(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF825385);
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF825385);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorCat = _obtenerColorCategoria(ficha.colorCategoria);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniatura o icono de imagen
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 65,
                  height: 65,
                  child: _MiniaturaFicha(
                    rutaImagen: ficha.rutaImagen,
                    colorPrimario: colorCat,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Detalles descriptivos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ficha.titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ficha.descripcionLimpia.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        ficha.descripcionLimpia,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (ficha.etiquetas.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: ficha.etiquetas
                            .take(3)
                            .map((et) => EtiquetaChip(texto: et.nombre))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniaturaFicha extends StatelessWidget {
  final String? rutaImagen;
  final Color colorPrimario;

  const _MiniaturaFicha({
    this.rutaImagen,
    required this.colorPrimario,
  });

  @override
  Widget build(BuildContext context) {
    if (rutaImagen == null || rutaImagen!.isEmpty) {
      return _placeholder();
    }

    if (kIsWeb) {
      return Image.network(
        rutaImagen!,
        fit: BoxFit.cover,
        cacheWidth: 150,
        cacheHeight: 150,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    return FutureBuilder<bool>(
      future: File(rutaImagen!).exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        if (snapshot.data == true) {
          return Image.file(
            File(rutaImagen!),
            fit: BoxFit.cover,
            cacheWidth: 150,
            cacheHeight: 150,
            errorBuilder: (_, _, _) => _placeholder(),
          );
        }

        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: colorPrimario.withValues(alpha: 0.12),
      child: Icon(Icons.insert_drive_file_outlined, color: colorPrimario, size: 28),
    );
  }
}
