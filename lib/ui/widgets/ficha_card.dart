import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/ficha.dart';
import 'etiqueta_chip.dart';

/// Tarjeta visual para representar una ficha en listas y cuadrículas.
class FichaCard extends StatelessWidget {
  final Ficha ficha;
  final VoidCallback alPresionar;

  const FichaCard({
    super.key,
    required this.ficha,
    required this.alPresionar,
  });

  Color _obtenerColorCategoria(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.indigo;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorCat = _obtenerColorCategoria(ficha.colorCategoria);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniatura de la imagen
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _ImagenMiniatura(rutaImagen: ficha.rutaImagen),
                ),
              ),
              const SizedBox(width: 14),

              // Contenido descriptivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Indicador de Categoría
                    if (ficha.nombreCategoria != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: colorCat.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ficha.nombreCategoria!,
                          style: TextStyle(
                            color: colorCat,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    // Título de la Ficha
                    Text(
                      ficha.titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Descripción breve
                    if (ficha.descripcion != null && ficha.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ficha.descripcion!,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Etiquetas asociadas
                    if (ficha.etiquetas.isNotEmpty) ...[
                      const SizedBox(height: 8),
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
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que carga la imagen de forma asíncrona y muestra un placeholder mientras verifica.
class _ImagenMiniatura extends StatelessWidget {
  final String? rutaImagen;

  const _ImagenMiniatura({this.rutaImagen});

  @override
  Widget build(BuildContext context) {
    if (rutaImagen == null || rutaImagen!.isEmpty) {
      return _placeholder();
    }

    if (kIsWeb) {
      return Image.network(
        rutaImagen!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    // Para Android/iOS/Desktop: verificar existencia de forma asíncrona
    return FutureBuilder<bool>(
      future: File(rutaImagen!).exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final existe = snapshot.data == true;
        if (!existe) return _placeholder();

        return Image.file(
          File(rutaImagen!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 36),
    );
  }
}
