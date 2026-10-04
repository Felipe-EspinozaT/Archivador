import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/categorias_provider.dart';
import '../../providers/fichas_provider.dart';
import '../widgets/ficha_card.dart';
import 'categorias_screen.dart';
import 'lista_fichas_screen.dart';
import 'detalle_editor_screen.dart';

/// Pantalla de inicio del Archivador Digital Visual.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  Color _obtenerColor(String? hexString) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriasAsync = ref.watch(categoriasProvider);
    final fichasAsync = ref.watch(fichasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Archivador Digital', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () {
              ref.read(categoriasProvider.notifier).cargarCategorias();
              ref.read(fichasProvider.notifier).cargarFichas();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de estado y métricas
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.indigo, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud_off, color: Colors.white70, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Modo Offline Activo',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tus documentos organizados de manera visual y segura',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _construirMetrica(
                          'Total Fichas',
                          fichasAsync.maybeWhen(
                            data: (fichas) => '${fichas.length}',
                            orElse: () => '-',
                          ),
                        ),
                        const SizedBox(width: 24),
                        _construirMetrica(
                          'Categorías',
                          categoriasAsync.maybeWhen(
                            data: (cat) => '${cat.length}',
                            orElse: () => '-',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Sección de Categorías
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Categorías',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          ref.read(categoriaSeleccionadaProvider.notifier).seleccionar(null);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ListaFichasScreen()),
                          );
                        },
                        child: const Text('Ver fichas'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        tooltip: 'Gestionar categorías',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CategoriasScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            categoriasAsync.when(
              data: (categorias) => SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categorias.length,
                  itemBuilder: (context, index) {
                    final cat = categorias[index];
                    final color = _obtenerColor(cat.colorHex);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Filtrar por esta categoría y navegar a la lista
                          ref.read(categoriaSeleccionadaProvider.notifier).seleccionar(cat.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ListaFichasScreen()),
                          );
                        },
                        child: Container(
                          width: 130,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: color,
                                radius: 14,
                                child: const Icon(Icons.folder, color: Colors.white, size: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error al cargar categorías: $e'),
              ),
            ),

            const SizedBox(height: 16),

            // Sección de Fichas Recientes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fichas Recientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ListaFichasScreen()),
                      );
                    },
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('Explorar'),
                  ),
                ],
              ),
            ),

            fichasAsync.when(
              data: (fichas) {
                if (fichas.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.note_add_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Aún no tienes fichas guardadas.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Mostrar las 4 más recientes
                final recientes = fichas.take(4).toList();
                return Column(
                  children: recientes.map((f) {
                    return FichaCard(
                      ficha: f,
                      alPresionar: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetalleEditorScreen(ficha: f),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DetalleEditorScreen()),
          );
        },
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Nueva Ficha'),
      ),
    );
  }

  Widget _construirMetrica(String etiqueta, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
