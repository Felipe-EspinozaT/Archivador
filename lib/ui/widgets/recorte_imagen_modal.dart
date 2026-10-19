import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

/// Modal interactivo para recortar y ajustar físicamente el área seleccionada de una imagen
/// usando RepaintBoundary para guardar exactamente la región encuadrada por el usuario.
/// Soporta proporciones fija (1:1 Cuadrada, 1:2 Rectangular, 3:1 Fórmula/Ecuación) o 3:4.
class RecorteImagenModal extends StatefulWidget {
  final File archivoImagen;
  final double? aspectoObjetivo; // 1.0 para 1:1, 2.0 para 1x2, 3.0 para fórmula

  const RecorteImagenModal({
    super.key,
    required this.archivoImagen,
    this.aspectoObjetivo,
  });

  static Future<File?> mostrar(
    BuildContext context, {
    required File archivoImagen,
    double? aspectoObjetivo,
  }) async {
    return await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecorteImagenModal(
          archivoImagen: archivoImagen,
          aspectoObjetivo: aspectoObjetivo,
        ),
      ),
    );
  }

  @override
  State<RecorteImagenModal> createState() => _RecorteImagenModalState();
}

class _RecorteImagenModalState extends State<RecorteImagenModal> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  late double _proporcion;
  bool _procesando = false;
  ui.Image? _imagenDecodificada;

  @override
  void initState() {
    super.initState();
    _proporcion = widget.aspectoObjetivo ?? 1.0;
    _cargarImagen();
  }

  Future<void> _cargarImagen() async {
    try {
      final bytes = await widget.archivoImagen.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _imagenDecodificada = frame.image;
        });
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, widget.archivoImagen);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Captura físicamente los píxeles visibles dentro del recuadro de recorte
  /// y genera un nuevo archivo PNG recortado.
  Future<void> _confirmarRecorte() async {
    if (_imagenDecodificada == null) return;
    setState(() => _procesando = true);

    try {
      // Esperar un micro-frame para asegurar que el RepaintBoundary esté limpio
      await Future.delayed(const Duration(milliseconds: 30));

      final RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null && !kIsWeb) {
        final ui.Image imageRecortada = await boundary.toImage(pixelRatio: 2.5);
        final ByteData? byteData =
            await imageRecortada.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final archivoRecortado = File('${tempDir.path}/crop_$timestamp.png');
          await archivoRecortado.writeAsBytes(pngBytes, flush: true);

          if (mounted) {
            Navigator.pop(context, archivoRecortado);
            return;
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, widget.archivoImagen);
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, widget.archivoImagen);
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Encuadrar y Recortar', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton.icon(
            onPressed: _procesando ? null : _confirmarRecorte,
            icon: _procesando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 2),
                  )
                : const Icon(Icons.crop, color: Colors.amberAccent),
            label: Text(
              _procesando ? 'Recortando...' : 'Recortar y Usar',
              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _imagenDecodificada == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 16, right: 16),
                  child: Text(
                    'Pellizca con 2 dedos para acercar y arrastra la imagen dentro del marco amarillo',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AspectRatio(
                        aspectRatio: _proporcion,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber, width: 2.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: Container(
                              color: Colors.black,
                              child: InteractiveViewer(
                                transformationController: _controller,
                                minScale: 0.5,
                                maxScale: 6.0,
                                boundaryMargin: const EdgeInsets.all(220),
                                child: Center(
                                  child: Image.file(
                                    widget.archivoImagen,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  color: Colors.grey.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _botonProporcion('Fórmula 3:1', 3.0),
                        const SizedBox(width: 8),
                        _botonProporcion('Rectangular 2:1', 2.0),
                        const SizedBox(width: 8),
                        _botonProporcion('Cuadrado 1:1', 1.0),
                        const SizedBox(width: 8),
                        _botonProporcion('Vertical 3:4', 0.75),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _botonProporcion(String etiqueta, double valor) {
    final seleccionada = (_proporcion - valor).abs() < 0.05;
    return ChoiceChip(
      label: Text(etiqueta),
      selected: seleccionada,
      selectedColor: const Color(0xFF825385),
      labelStyle: TextStyle(
        color: seleccionada ? Colors.white : Colors.white70,
        fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _proporcion = valor;
          _controller.value = Matrix4.identity();
        });
      },
    );
  }
}
