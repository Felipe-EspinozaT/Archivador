import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/categorias_provider.dart';
import '../../providers/fichas_provider.dart';
import '../widgets/ficha_card.dart';
import 'detalle_editor_screen.dart';

/// Pantalla con la lista completa de fichas archivadas, con búsqueda y filtros por categoría.
class ListaFichasScreen extends ConsumerStatefulWidget {
  const ListaFichasScreen({super.key});

  @override
  ConsumerState<ListaFichasScreen> createState() => _ListaFichasScreenState();
}

class _ListaFichasScreenState extends ConsumerState<ListaFichasScreen> {
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _busquedaController.text = ref.read(busquedaFichasProvider);
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Color _obtenerColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.blue;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);
    final categoriaSeleccionada = ref.watch(categoriaSeleccionadaProvider);
    final fichasAsync = ref.watch(fichasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichas Guardadas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              controller: _busquedaController,
              hintText: 'Buscar por título o descripción...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_busquedaController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _busquedaController.clear();
                      ref.read(busquedaFichasProvider.notifier).actualizar('');
                    },
                  ),
              ],
              onChanged: (valor) {
                ref.read(busquedaFichasProvider.notifier).actualizar(valor);
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Selector de Categorías (Chips horizontales)
          categoriasAsync.when(
            data: (categorias) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: categoriaSeleccionada == null,
                    onSelected: (seleccionado) {
                      if (seleccionado) {
                        ref.read(categoriaSeleccionadaProvider.notifier).seleccionar(null);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ...categorias.map((cat) {
                    final colorCat = _obtenerColor(cat.colorHex);
                    final esSeleccionada = categoriaSeleccionada == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: colorCat, radius: 6),
                        label: Text(cat.nombre),
                        selected: esSeleccionada,
                        onSelected: (seleccionado) {
                          ref.read(categoriaSeleccionadaProvider.notifier).seleccionar(
                            seleccionado ? cat.id : null,
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 48),
            error: (err, _) => const SizedBox.shrink(),
          ),

          // Lista de Fichas
          Expanded(
            child: fichasAsync.when(
              data: (fichas) {
                if (fichas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 70, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No hay fichas encontradas',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crea una nueva ficha con el botón "+"',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DetalleEditorScreen()),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Crear Ficha'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(fichasProvider.notifier).cargarFichas();
                  },
                  child: ListView.builder(
                    itemCount: fichas.length,
                    itemBuilder: (context, index) {
                      final ficha = fichas[index];
                      return FichaCard(
                        ficha: ficha,
                        alPresionar: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetalleEditorScreen(ficha: ficha),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error al cargar fichas: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DetalleEditorScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Ficha'),
      ),
    );
  }
}
