import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/categorias_provider.dart';

/// Pantalla para gestionar las categorías del archivador (ver, crear y eliminar).
class CategoriasScreen extends ConsumerStatefulWidget {
  const CategoriasScreen({super.key});

  @override
  ConsumerState<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends ConsumerState<CategoriasScreen> {
  // Colores predefinidos para elegir al crear categoría
  static const List<Map<String, String>> _coloresDisponibles = [
    {'nombre': 'Azul', 'hex': '#2196F3'},
    {'nombre': 'Verde', 'hex': '#4CAF50'},
    {'nombre': 'Naranja', 'hex': '#FF9800'},
    {'nombre': 'Rosa', 'hex': '#E91E63'},
    {'nombre': 'Púrpura', 'hex': '#9C27B0'},
    {'nombre': 'Cian', 'hex': '#00BCD4'},
    {'nombre': 'Rojo', 'hex': '#F44336'},
    {'nombre': 'Ámbar', 'hex': '#FFC107'},
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

  void _mostrarDialogoNuevaCategoria() {
    final nombreCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    String colorSeleccionado = _coloresDisponibles[0]['hex']!;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Nueva Categoría'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
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
                            width: 36,
                            height: 36,
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
                  Navigator.pop(ctx);
                  await ref.read(categoriasProvider.notifier).agregarCategoria(
                        nombreCtrl.text.trim(),
                        descripcionCtrl.text.trim().isEmpty ? null : descripcionCtrl.text.trim(),
                        colorSeleccionado,
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Categoría "${nombreCtrl.text.trim()}" creada'),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _confirmarEliminar(int id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text(
          '¿Eliminar "$nombre"? Las fichas asociadas quedarán sin categoría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await ref.read(categoriasProvider.notifier).eliminarCategoria(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Categoría "$nombre" eliminada')),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(categoriasProvider.notifier).cargarCategorias(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevaCategoria,
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
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca el botón "+" para crear una',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: categorias.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final cat = categorias[index];
              final color = _colorDesdeHex(cat.colorHex);
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: const Icon(Icons.folder, color: Colors.white),
                  ),
                  title: Text(cat.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: cat.descripcion != null && cat.descripcion!.isNotEmpty
                      ? Text(cat.descripcion!)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Eliminar categoría',
                    onPressed: cat.id != null
                        ? () => _confirmarEliminar(cat.id!, cat.nombre)
                        : null,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
