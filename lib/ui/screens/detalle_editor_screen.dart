import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ficha.dart';
import '../../providers/categorias_provider.dart';
import '../../providers/fichas_provider.dart';
import '../../providers/etiquetas_provider.dart';
import '../widgets/etiqueta_chip.dart';

/// Pantalla para crear, visualizar y editar una ficha del archivador.
class DetalleEditorScreen extends ConsumerStatefulWidget {
  final Ficha? ficha;
  final int? categoriaIdInicial;

  const DetalleEditorScreen({
    super.key,
    this.ficha,
    this.categoriaIdInicial,
  });

  @override
  ConsumerState<DetalleEditorScreen> createState() => _DetalleEditorScreenState();
}

class _DetalleEditorScreenState extends ConsumerState<DetalleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _descripcionController;

  int? _categoriaIdSeleccionada;
  File? _nuevaImagenArchivo;
  String? _rutaImagenExistente;
  bool _eliminarImagenPrevia = false;
  late List<String> _etiquetas;
  final ImagePicker _picker = ImagePicker();
  bool _guardando = false;

  bool get _esEdicion => widget.ficha != null;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.ficha?.titulo ?? '');
    _descripcionController = TextEditingController(text: widget.ficha?.descripcion ?? '');

    _categoriaIdSeleccionada = widget.ficha?.categoriaId ?? widget.categoriaIdInicial;
    _rutaImagenExistente = widget.ficha?.rutaImagen;
    _etiquetas = widget.ficha?.etiquetas.map((e) => e.nombre).toList() ?? [];
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(ImageSource origen) async {
    try {
      final picked = await _picker.pickImage(source: origen, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _nuevaImagenArchivo = File(picked.path);
          _rutaImagenExistente = picked.path;
          _eliminarImagenPrevia = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  void _removerImagen() {
    setState(() {
      _nuevaImagenArchivo = null;
      _rutaImagenExistente = null;
      _eliminarImagenPrevia = true;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Si es edición de una ficha existente, pedir confirmación antes de modificar
    if (_esEdicion) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar modificación'),
          content: const Text(
            '¿Estás seguro de que deseas guardar los cambios realizados en esta ficha?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    setState(() => _guardando = true);

    try {
      final notifier = ref.read(fichasProvider.notifier);

      if (_esEdicion) {
        await notifier.actualizarFicha(
          fichaExistente: widget.ficha!,
          nuevoTitulo: _tituloController.text.trim(),
          nuevaDescripcion: _descripcionController.text.trim(),
          nuevaCategoriaId: _categoriaIdSeleccionada,
          nuevaImagenArchivo: _nuevaImagenArchivo,
          eliminarImagenPrevia: _eliminarImagenPrevia,
          etiquetas: _etiquetas,
        );
      } else {
        await notifier.guardarFicha(
          titulo: _tituloController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          categoriaId: _categoriaIdSeleccionada,
          archivoImagen: _nuevaImagenArchivo,
          etiquetas: _etiquetas,
        );
      }

      // Invalidar etiquetasProvider para reflejar nuevas etiquetas creadas
      ref.invalidate(etiquetasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion ? 'Ficha actualizada con éxito' : 'Ficha guardada con éxito'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarEliminacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Ficha'),
        content: const Text('¿Estás seguro de que deseas eliminar esta ficha y su imagen asociada? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await ref.read(fichasProvider.notifier).eliminarFicha(widget.ficha!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ficha eliminada')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Ficha' : 'Nueva Ficha'),
        actions: [
          if (_esEdicion)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar Ficha',
              onPressed: _guardando ? null : _confirmarEliminacion,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Guardar',
            onPressed: _guardando ? null : _guardar,
          ),
        ],
      ),
      body: _guardando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- SECCIÓN DE IMAGEN ---
                    _construirSeccionImagen(),
                    const SizedBox(height: 20),

                    // --- CAMPO TÍTULO ---
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título de la ficha *',
                        hintText: 'Ej. Factura de Internet Enero',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (valor) {
                        if (valor == null || valor.trim().isEmpty) {
                          return 'Por favor ingresa un título';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- SELECCIÓN DE CATEGORÍA ---
                    categoriasAsync.when(
                      data: (categorias) {
                        final existeSeleccion = categorias.any((c) => c.id == _categoriaIdSeleccionada);
                        final valorSeguro = existeSeleccion ? _categoriaIdSeleccionada : null;

                        return DropdownButtonFormField<int?>(
                          initialValue: valorSeguro,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.folder_outlined),
                          ),
                          hint: const Text('Errante (Por defecto)'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Sin asignar (irá a Errante)'),
                            ),
                            ...categorias.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _colorDesdeHex(c.colorHex),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(c.nombre),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (nuevoId) {
                            setState(() => _categoriaIdSeleccionada = nuevoId);
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error al cargar categorías: $err'),
                    ),
                    const SizedBox(height: 16),

                    // --- CAMPO DESCRIPCIÓN ---
                    TextFormField(
                      controller: _descripcionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción o notas adicionales',
                        hintText: 'Detalles relevantes de esta ficha...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- SECCIÓN DE ETIQUETAS CON AUTOCOMPLETADO ---
                    const Text(
                      'Etiquetas',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        final texto = textEditingValue.text.trim();
                        if (texto.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        final query = texto.toLowerCase();
                        final todas = ref.watch(etiquetasProvider).value ?? [];
                        return todas
                            .map((e) => e.nombre)
                            .where((nombre) =>
                                nombre.toLowerCase().contains(query) && !_etiquetas.contains(nombre));
                      },
                      onSelected: (String seleccion) {
                        if (!_etiquetas.contains(seleccion)) {
                          setState(() {
                            _etiquetas.add(seleccion);
                          });
                        }
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  hintText: 'Añadir etiqueta (ej. Impuestos, Auto)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.label_outline, size: 20),
                                ),
                                onSubmitted: (texto) {
                                  final limpio = texto.trim();
                                  if (limpio.isNotEmpty && !_etiquetas.contains(limpio)) {
                                    setState(() {
                                      _etiquetas.add(limpio);
                                    });
                                    controller.clear();
                                  }
                                  onFieldSubmitted();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () {
                                final limpio = controller.text.trim();
                                if (limpio.isNotEmpty && !_etiquetas.contains(limpio)) {
                                  setState(() {
                                    _etiquetas.add(limpio);
                                  });
                                  controller.clear();
                                }
                              },
                              icon: const Icon(Icons.add),
                              tooltip: 'Agregar etiqueta',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (_etiquetas.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _etiquetas
                            .map(
                              (tag) => EtiquetaChip(
                                texto: tag,
                                alEliminar: () {
                                  setState(() => _etiquetas.remove(tag));
                                },
                              ),
                            )
                            .toList(),
                      )
                    else
                      Text(
                        'Sin etiquetas asignadas.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),

                    const SizedBox(height: 32),

                    // Botón principal de Guardar
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _guardando ? null : _guardar,
                      icon: const Icon(Icons.save),
                      label: Text(
                        _esEdicion ? 'Actualizar Ficha' : 'Guardar Ficha',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _construirSeccionImagen() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: _construirContenidoImagen(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _BotonesImagen(
              nuevaImagenArchivo: _nuevaImagenArchivo,
              rutaImagenExistente: _rutaImagenExistente,
              onCamara: () => _seleccionarImagen(ImageSource.camera),
              onGaleria: () => _seleccionarImagen(ImageSource.gallery),
              onQuitar: _removerImagen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirContenidoImagen() {
    // 1. Nueva imagen recién seleccionada (archivo en caché temporal)
    if (_nuevaImagenArchivo != null) {
      return Image.file(_nuevaImagenArchivo!, fit: BoxFit.cover);
    }

    // 2. Sin ninguna ruta
    if (_rutaImagenExistente == null || _rutaImagenExistente!.isEmpty) {
      return _placeholderSinImagen();
    }

    // 3. En Web: cargar por URL/path de red
    if (kIsWeb) {
      return Image.network(
        _rutaImagenExistente!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderSinImagen(),
      );
    }

    // 4. En Android/Desktop: verificar si el archivo existe de forma asíncrona
    return FutureBuilder<bool>(
      future: File(_rutaImagenExistente!).exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == true) {
          return Image.file(
            File(_rutaImagenExistente!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholderSinImagen(),
          );
        }
        return _placeholderSinImagen();
      },
    );
  }


  Widget _placeholderSinImagen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('No hay imagen seleccionada', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Color _colorDesdeHex(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}

/// Widget de botones de imagen que determina de forma asíncrona si "Quitar" debe mostrarse.
class _BotonesImagen extends StatelessWidget {
  final File? nuevaImagenArchivo;
  final String? rutaImagenExistente;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final VoidCallback onQuitar;

  const _BotonesImagen({
    required this.nuevaImagenArchivo,
    required this.rutaImagenExistente,
    required this.onCamara,
    required this.onGaleria,
    required this.onQuitar,
  });

  Future<bool> _tieneImagen() async {
    if (nuevaImagenArchivo != null) return true;
    if (rutaImagenExistente == null || rutaImagenExistente!.isEmpty) return false;
    if (kIsWeb) return true;
    return await File(rutaImagenExistente!).exists();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _tieneImagen(),
      builder: (context, snapshot) {
        final tieneImagen = snapshot.data == true;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: onCamara,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Cámara'),
            ),
            TextButton.icon(
              onPressed: onGaleria,
              icon: const Icon(Icons.photo_library),
              label: const Text('Galería'),
            ),
            if (tieneImagen)
              TextButton.icon(
                onPressed: onQuitar,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Quitar', style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      },
    );
  }
}
