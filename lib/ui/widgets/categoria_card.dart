import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/categoria.dart';

/// Tarjeta cuadrada visual para una Categoría, con soporte para fondos personalizados
/// (`rutaImagenFondo`), colores distintivos y texto centrado de alto contraste.
class CategoriaCard extends StatelessWidget {
  final Categoria categoria;
  final bool esSeleccionada;
  final VoidCallback alPresionar;
  final double tamano;

  const CategoriaCard({
    super.key,
    required this.categoria,
    required this.esSeleccionada,
    required this.alPresionar,
    this.tamano = 95.0,
  });

  Color _obtenerColor(String? hexString) {
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
    final color = _obtenerColor(categoria.colorHex);
    final tieneFondo = categoria.rutaImagenFondo != null && categoria.rutaImagenFondo!.isNotEmpty;
    final imagenFondo = _obtenerImagenFondo(categoria.rutaImagenFondo);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Card(
        elevation: esSeleccionada ? 4 : 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: esSeleccionada ? (tieneFondo ? Colors.white : color) : color.withValues(alpha: 0.35),
            width: esSeleccionada ? 2.5 : 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: alPresionar,
          child: Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              color: tieneFondo ? null : (esSeleccionada ? Colors.white : Colors.white.withValues(alpha: 0.92)),
              image: tieneFondo && imagenFondo != null
                  ? DecorationImage(
                      image: imagenFondo,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.45),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            child: Text(
              categoria.nombre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: tieneFondo ? Colors.white : color,
                shadows: tieneFondo
                    ? const [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
