import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/database/app_database.dart';
import '../../models/categoria.dart';
import '../../providers/categorias_provider.dart';
import '../../providers/database_provider.dart';

/// Pantalla para gestionar las categorías del archivador:
/// reordenar verticalmente (ReorderableListView), crear con imagen de fondo, editar y eliminar con confirmación.
class CategoriasScreen extends ConsumerStatefulWidget {
  const CategoriasScreen({super.key});

  @override
  ConsumerState<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends ConsumerState<CategoriasScreen> {
  final ImagePicker _picker = ImagePicker();

  // Colores predefinidos para elegir al crear o editar categoría
  static const List<Map<String, String>> _coloresDisponibles = [
    {'nombre': 'Azul', 'hex': '#2196F3'},
    {'nombre': 'Verde', 'hex': '#4CAF50'},
    {'nombre': 'Naranja', 'hex': '#FF9800'},
    {'nombre': 'Rosa', 'hex': '#E91E63'},
    {'nombre': 'Púrpura', 'hex': '#9C27B0'},
    {'nombre': 'Cian', 'hex': '#00BCD4'},
    {'nombre': 'Rojo', 'hex': '#F44336'},
    {'nombre': 'Ámbar', 'hex': '#FFC107'},
    {'nombre': 'Gris', 'hex': '#9E9E9E'},
  ];

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

  /// Muestra el diálogo para crear o editar una categoría, permitiendo cargar imagen de fondo.
  void _mostrarDialogoCategoria({Categoria? categoriaExistente}) {
    final esEdicion = categoriaExistente != null;
    final esErrante =
        esEdicion && categoriaExistente.nombre == AppDatabase.categoriaErranteNombre;

    final nombreCtrl = TextEditingController(text: categoriaExistente?.nombre ?? '');
    final descripcionCtrl =
        TextEditingController(text: categoriaExistente?.descripcion ?? '');
    String colorSeleccionado =
        categoriaExistente?.colorHex ?? _coloresDisponibles[0]['hex']!;
    String? rutaFondoActual = categoriaExistente?.rutaImagenFondo;
    File? nuevoArchivoFondo;
    bool quitarFondoExistente = false;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          Future<void> seleccionarFondo(ImageSource source) async {
            try {
              final picked = await _picker.pickImage(source: source, imageQuality: 85);
              if (picked != null) {
                setDialogState(() {
                  nuevoArchivoFondo = File(picked.path);
                  rutaFondoActual = picked.path;
                  quitarFondoExistente = false;
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

          return AlertDialog(
            title: Text(esEdicion ? 'Editar Categoría' : 'Nueva Categoría'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreCtrl,
                      enabled: !esErrante,
                      decoration: InputDecoration(
                        labelText: 'Nombre *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.label),
                        helperText: esErrante
                            ? 'La categoría Errante no puede cambiar de nombre'
                            : null,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        if (!esErrante &&
                            v.trim().toLowerCase() ==
                                AppDatabase.categoriaErranteNombre.toLowerCase()) {
                          return 'Nombre reservado del sistema';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descripcionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _coloresDisponibles.map((c) {
                        final color = _colorDesdeHex(c['hex']!);
                        final seleccionado = colorSeleccionado == c['hex'];
                        return GestureDetector(
                          onTap: () => setDialogState(() => colorSeleccionado = c['hex']!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: seleccionado
                                  ? Border.all(color: Colors.black54, width: 3)
                                  : null,
                              boxShadow: seleccionado
                                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                                  : null,
                            ),
                            child: seleccionado
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Imagen de fondo (opcional):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rutaFondoActual != null && rutaFondoActual!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 90,
                          width: double.infinity,
                          child: kIsWeb
                              ? Image.network(rutaFondoActual!, fit: BoxFit.cover)
                              : Image.file(File(rutaFondoActual!), fit: BoxFit.cover),
                        ),
                      )
                    else
                      Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Sin imagen de fondo',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => seleccionarFondo(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Galería'),
                        ),
                        TextButton.icon(
                          onPressed: () => seleccionarFondo(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Cámara'),
                        ),
                        if (rutaFondoActual != null && rutaFondoActual!.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                nuevoArchivoFondo = null;
                                rutaFondoActual = null;
                                quitarFondoExistente = true;
                              });
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            label: const Text('Quitar', style: TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  // Si es edición, pedir confirmación de modificación
                  if (esEdicion) {
                    final confirmarMod = await showDialog<bool>(
                      context: ctx,
                      builder: (confirmCtx) => AlertDialog(
                        title: const Text('Confirmar modificación'),
                        content: Text(
                          '¿Estás seguro de que deseas guardar los cambios en la categoría "${nombreCtrl.text.trim()}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmCtx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(confirmCtx, true),
                            child: const Text('Guardar cambios'),
                          ),
                        ],
                      ),
                    );
                    if (confirmarMod != true) return;
                  }

                  if (ctx.mounted) Navigator.pop(ctx);

                  final storage = ref.read(storageServiceProvider);
                  String? rutaFinal = categoriaExistente?.rutaImagenFondo;

                  if (nuevoArchivoFondo != null) {
                    rutaFinal = await storage.guardarImagen(nuevoArchivoFondo!);
                  } else if (quitarFondoExistente) {
                    rutaFinal = null;
                  }

                  if (esEdicion) {
                    final actualizada = Categoria(
                      id: categoriaExistente.id,
                      nombre: nombreCtrl.text.trim(),
                      descripcion: descripcionCtrl.text.trim().isEmpty
                          ? null
                          : descripcionCtrl.text.trim(),
                      colorHex: colorSeleccionado,
                      orden: categoriaExistente.orden,
                      rutaImagenFondo: rutaFinal,
                    );
                    await ref
                        .read(categoriasProvider.notifier)
                        .actualizarCategoria(actualizada);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Categoría "${actualizada.nombre}" actualizada'),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    }
                  } else {
                    await ref.read(categoriasProvider.notifier).agregarCategoria(
                          nombreCtrl.text.trim(),
                          descripcionCtrl.text.trim().isEmpty
                              ? null
                              : descripcionCtrl.text.trim(),
                          colorSeleccionado,
                          rutaImagenFondo: rutaFinal,
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Categoría "${nombreCtrl.text.trim()}" creada'),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    }
                  }
                },
                child: Text(esEdicion ? 'Guardar' : 'Crear'),
              ),
            ],
          );
        });
      },
    );
  }

  /// Diálogo de confirmación al eliminar una categoría:
  /// Pregunta si desea eliminar también las fichas dependientes o moverlas a 'Errante'.
  Future<void> _confirmarEliminar(int id, String nombre) async {
    // Retorna: null (cancelar), false (mover a Errante), true (eliminar fichas también)
    final decision = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar "$nombre"'),
        content: const Text(
          '¿Deseas eliminar también las fichas asociadas a esta categoría o prefieres conservarlas pasándolas a la categoría "Errante"?',
        ),
        actionsAlignment: MainAxisAlignment.end,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.drive_file_move_outlined, size: 18),
            label: const Text('Mover fichas a Errante'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
            label: const Text(
              'Eliminar todo',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (decision != null && mounted) {
      await ref
          .read(categoriasProvider.notifier)
          .eliminarCategoria(id, eliminarFichasDependientes: decision);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision
                  ? 'Categoría "$nombre" y sus fichas fueron eliminadas'
                  : 'Categoría "$nombre" eliminada (fichas movidas a Errante)',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Categorías'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoCategoria(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Categoría'),
      ),
      body: categoriasAsync.when(
        data: (categorias) {
          if (categorias.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No hay categorías aún',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Mantén presionado y arrastra para ordenar las categorías:',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: categorias.length,
                  onReorderItem: (oldIndex, newIndex) {
                    ref
                        .read(categoriasProvider.notifier)
                        .reordenarCategorias(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final cat = categorias[index];
                    final color = _colorDesdeHex(cat.colorHex);
                    final esErrante = cat.nombre == AppDatabase.categoriaErranteNombre;
                    final tieneImagen = cat.rutaImagenFondo != null &&
                        cat.rutaImagenFondo!.isNotEmpty;

                    return Card(
                      key: ValueKey(cat.id ?? index),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          backgroundImage: tieneImagen
                              ? (kIsWeb
                                  ? NetworkImage(cat.rutaImagenFondo!)
                                  : FileImage(File(cat.rutaImagenFondo!))
                                      as ImageProvider)
                              : null,
                          child: !tieneImagen
                              ? const Icon(Icons.folder, color: Colors.white)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                cat.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (esErrante)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Por defecto',
                                  style: TextStyle(fontSize: 10, color: Colors.black54),
                                ),
                              ),
                          ],
                        ),
                        subtitle: cat.descripcion != null && cat.descripcion!.isNotEmpty
                            ? Text(cat.descripcion!)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                              tooltip: 'Editar categoría',
                              onPressed: () =>
                                  _mostrarDialogoCategoria(categoriaExistente: cat),
                            ),
                            if (!esErrante)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Eliminar categoría',
                                onPressed: cat.id != null
                                    ? () => _confirmarEliminar(cat.id!, cat.nombre)
                                    : null,
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.0),
                                child: Tooltip(
                                  message: 'Esta categoría no se puede eliminar',
                                  child: Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                                ),
                              ),
                            const Icon(Icons.drag_handle, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
