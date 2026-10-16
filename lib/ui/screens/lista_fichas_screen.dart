import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ficha.dart';
import '../../providers/categorias_provider.dart';
import '../../providers/fichas_provider.dart';
import '../../providers/ajustes_provider.dart';
import '../widgets/ficha_card.dart';
import 'detalle_editor_screen.dart';

/// Pantalla con la lista completa de fichas archivadas, con búsqueda, filtros por categoría
/// y modos de vista tipo Notion: Galería (Cards), Lista detallada y Tabla compacta.
class ListaFichasScreen extends ConsumerStatefulWidget {
  const ListaFichasScreen({super.key});

  @override
  ConsumerState<ListaFichasScreen> createState() => _ListaFichasScreenState();
}

class _ListaFichasScreenState extends ConsumerState<ListaFichasScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String? _vistaActual; // 'cuadricula', 'lista', 'tabla'
  String _criterioOrden = 'reciente'; // 'reciente', 'alfabetico', 'antiguo'

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

  List<Ficha> _ordenarFichas(List<Ficha> fichas) {
    final lista = List<Ficha>.from(fichas);
    switch (_criterioOrden) {
      case 'alfabetico':
        lista.sort((a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
        break;
      case 'antiguo':
        lista.sort((a, b) => a.fechaModificacion.compareTo(b.fechaModificacion));
        break;
      case 'reciente':
      default:
        lista.sort((a, b) => b.fechaModificacion.compareTo(a.fechaModificacion));
        break;
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);
    final categoriaSeleccionada = ref.watch(categoriaSeleccionadaProvider);
    final fichasAsync = ref.watch(fichasProvider);
    final ajustes = ref.watch(ajustesProvider);

    final modoVista = _vistaActual ?? ajustes.vistaFichasDefault;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichas Guardadas'),
        actions: [
          // Selector de Vistas estilo Notion (Galería, Lista, Tabla)
          PopupMenuButton<String>(
            icon: Icon(
              modoVista == 'cuadricula'
                  ? Icons.grid_view_rounded
                  : modoVista == 'tabla'
                      ? Icons.table_chart_outlined
                      : Icons.view_agenda_outlined,
            ),
            tooltip: 'Cambiar visualización (Estilo Notion)',
            onSelected: (val) {
              setState(() {
                _vistaActual = val;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cuadricula',
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Vista Galería (Tarjetas)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lista',
                child: Row(
                  children: [
                    Icon(Icons.view_agenda_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Vista Lista detallada'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tabla',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Vista Tabla / Compacta'),
                  ],
                ),
              ),
            ],
          ),
          // Menú de Ordenamiento
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Ordenar fichas',
            onSelected: (val) {
              setState(() {
                _criterioOrden = val;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reciente',
                child: Row(
                  children: [
                    Icon(Icons.update, size: 20, color: _criterioOrden == 'reciente' ? Colors.blue : null),
                    const SizedBox(width: 10),
                    const Text('Más recientes primero'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'alfabetico',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 20, color: _criterioOrden == 'alfabetico' ? Colors.blue : null),
                    const SizedBox(width: 10),
                    const Text('Alfabético (A - Z)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'antiguo',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20, color: _criterioOrden == 'antiguo' ? Colors.blue : null),
                    const SizedBox(width: 10),
                    const Text('Más antiguas primero'),
                  ],
                ),
              ),
            ],
          ),
        ],
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

          // Contenedor de Fichas según el modo de vista elegido
          Expanded(
            child: fichasAsync.when(
              data: (fichas) {
                final fichasFiltradas = categoriaSeleccionada == null
                    ? fichas
                    : fichas.where((f) => f.categoriaId == categoriaSeleccionada).toList();

                if (fichasFiltradas.isEmpty) {
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
                              MaterialPageRoute(
                                builder: (_) => DetalleEditorScreen(
                                  categoriaIdInicial: categoriaSeleccionada,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Crear Ficha'),
                        ),
                      ],
                    ),
                  );
                }

                final listaOrdenada = _ordenarFichas(fichasFiltradas);

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(fichasProvider.notifier).cargarFichas();
                  },
                  child: _construirCuerpoVista(modoVista, listaOrdenada),
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
            MaterialPageRoute(
              builder: (_) => DetalleEditorScreen(
                categoriaIdInicial: categoriaSeleccionada,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Ficha'),
      ),
    );
  }

  Widget _construirCuerpoVista(String modo, List<Ficha> fichas) {
    switch (modo) {
      case 'cuadricula':
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: fichas.length,
          itemBuilder: (context, index) {
            final f = fichas[index];
            return FichaCard(
              ficha: f,
              alPresionar: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetalleEditorScreen(ficha: f)),
                );
              },
            );
          },
        );

      case 'tabla':
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: fichas.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final f = fichas[index];
            final colorCat = _obtenerColor(f.colorCategoria);
            final fechaStr = '${f.fechaModificacion.day}/${f.fechaModificacion.month}/${f.fechaModificacion.year}';

            return ListTile(
              dense: true,
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorCat.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: f.rutaImagen != null && f.rutaImagen!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: kIsWeb
                              ? Image.network(f.rutaImagen!, width: 30, height: 30, fit: BoxFit.cover)
                              : Image.file(File(f.rutaImagen!), width: 30, height: 30, fit: BoxFit.cover, cacheWidth: 60),
                        )
                      : Icon(Icons.notes, size: 18, color: colorCat),
                ),
              ),
              title: Text(
                f.titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${f.nombreCategoria ?? 'General'} • $fechaStr',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: f.etiquetas.isNotEmpty
                  ? Chip(
                      label: Text('#${f.etiquetas.first}', style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetalleEditorScreen(ficha: f)),
                );
              },
            );
          },
        );

      case 'lista':
      default:
        return ListView.builder(
          itemCount: fichas.length,
          itemBuilder: (context, index) {
            final ficha = fichas[index];
            return FichaDetalleCard(
              ficha: ficha,
              alPresionar: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetalleEditorScreen(ficha: ficha)),
                );
              },
            );
          },
        );
    }
  }
}
