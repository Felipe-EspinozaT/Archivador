import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Modal visor de pantalla completa con soporte para zoom interactivo (pinch-to-zoom)
/// y desplazamiento libre para inspeccionar fotos de fórmulas, notas y diagramas en detalle.
class VisorImagenCompletaModal extends StatelessWidget {
  final String rutaOUrl;
  final String? titulo;

  const VisorImagenCompletaModal({
    super.key,
    required this.rutaOUrl,
    this.titulo,
  });

  static Future<void> abrir(
    BuildContext context, {
    required String rutaOUrl,
    String? titulo,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => VisorImagenCompletaModal(
          rutaOUrl: rutaOUrl,
          titulo: titulo,
        ),
        transitionsBuilder: (context, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esUrl = rutaOUrl.startsWith('http://') || rutaOUrl.startsWith('https://');

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      body: SafeArea(
        child: Stack(
          children: [
            // Área interactiva de zoom (hasta 6x) y paneo
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 6.0,
                clipBehavior: Clip.none,
                child: Hero(
                  tag: 'img_zoom_$rutaOUrl',
                  child: esUrl || kIsWeb
                      ? Image.network(
                          rutaOUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white70),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white54,
                          ),
                        )
                      : Image.file(
                          File(rutaOUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                ),
              ),
            ),

            // Barra superior flotante con título y botón cerrar
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          titulo ?? 'Doble toque o pellizco para zoom',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
