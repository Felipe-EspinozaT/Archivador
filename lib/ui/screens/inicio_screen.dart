import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/categorias_provider.dart';
import '../../providers/fichas_provider.dart';
import '../../providers/etiquetas_provider.dart';
import '../../models/ficha.dart';
import '../widgets/ficha_card.dart';
import '../widgets/categoria_card.dart';
import 'categorias_screen.dart';
import 'lista_fichas_screen.dart';
import 'detalle_editor_screen.dart';
import 'backup_screen.dart';
import 'sugerencias_screen.dart';
import 'ajustes_screen.dart';
import '../../providers/ajustes_provider.dart';
import '../../providers/database_provider.dart';
import '../../services/overlay_service.dart';
import '../widgets/barra_lateral_xiaomi.dart';

/// Pantalla principal de Simplista.
class InicioScreen extends ConsumerStatefulWidget {
  const InicioScreen({super.key});

  @override
  ConsumerState<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends ConsumerState<InicioScreen> with WidgetsBindingObserver {
  final TextEditingController _busquedaController = TextEditingController();
  int? _categoriaSeleccionadaId;

  static const double _tamanoCategoria = 95.0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // El servicio nativo pudo guardar fichas rápidas mientras la app estaba en segundo plano
      ref.invalidate(fichasProvider);
      ref.invalidate(fichasRecientesProvider);
      ref.invalidate(categoriasProvider);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Respaldo automático al salir/cerrar la app si está configurado
      final ajustes = ref.read(ajustesProvider);
      if (ajustes.frecuenciaRespaldo == 'Al cerrar la app' ||
          ajustes.frecuenciaRespaldo == 'En cada cambio (Automático)') {
        final packageService = ref.read(backupPackageServiceProvider);
        packageService.guardarPaqueteEnArchivo(prefijo: 'simplista_auto_backup');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OverlayService.escucharAccionesRapidas((payload) {
      if (mounted) {
        _abrirEditorConBloque(
          payload.action,
          tituloInicial: payload.title,
          textoInicial: payload.text,
          rutaPortadaInicial: payload.portada,
          fichaId: payload.fichaId,
          categoriaId: payload.categoriaId,
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final payload = await OverlayService.consumirAccionPendiente();
      if (payload != null && payload.action.isNotEmpty && mounted) {
        _abrirEditorConBloque(
          payload.action,
          tituloInicial: payload.title,
          textoInicial: payload.text,
          rutaPortadaInicial: payload.portada,
          fichaId: payload.fichaId,
          categoriaId: payload.categoriaId,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _busquedaController.dispose();
    super.dispose();
  }

  /// Muestra un selector modal para adjuntar o quitar etiquetas al filtro de búsqueda.
  void _mostrarSelectorEtiquetasFiltro() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final etiquetasAsync = ref.watch(etiquetasProvider);
            final seleccionadas = ref.watch(etiquetasFiltroProvider);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.label_outline, color: Color(0xFF825385)),
                          SizedBox(width: 8),
                          Text(
                            'Filtrar por etiquetas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (seleccionadas.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            ref.read(etiquetasFiltroProvider.notifier).limpiar();
                          },
                          child: const Text('Limpiar todo'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  etiquetasAsync.when(
                    data: (etiquetas) {
                      if (etiquetas.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Aún no hay etiquetas creadas en tus fichas.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: etiquetas.map((et) {
                          final activa = seleccionadas.contains(et.nombre);
                          return FilterChip(
                            label: Text(et.nombre),
                            selected: activa,
                            selectedColor:
                                const Color(0xFF825385).withValues(alpha: 0.2),
                            checkmarkColor: const Color(0xFF825385),
                            onSelected: (_) {
                              ref
                                  .read(etiquetasFiltroProvider.notifier)
                                  .alternarEtiqueta(et.nombre);
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Text('Error al cargar etiquetas: $e'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Listo'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasProvider);
    final fichasAsync = ref.watch(fichasProvider);
    final fichasRecientesAsync = ref.watch(fichasRecientesProvider);
    final etiquetasFiltro = ref.watch(etiquetasFiltroProvider);
    final textoBusqueda = ref.watch(busquedaFichasProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF825385),
            Color(0xFFEF9810),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.person, color: Colors.white, size: 28),
              tooltip: 'Menú de usuario',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Text(
            'Simplista',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
            ),
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF825385),
                      Color(0xFFEF9810),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 36, color: Color(0xFF825385)),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Simplista',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Cuenta y Ajustes'),
                subtitle: const Text('Barra Xiaomi, vistas de fichas'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AjustesScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Temas'),
                onTap: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'En desarrollo',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      duration: const Duration(milliseconds: 1400),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Backup'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('Sugerencias'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SugerenciasScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Buscador de fichas con botón para adjuntar etiquetas al filtro
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        controller: _busquedaController,
                        hintText: 'Buscar fichas...',
                        leading: const Icon(Icons.search, color: Colors.black54),
                        trailing: [
                          if (_busquedaController.text.isNotEmpty ||
                              textoBusqueda.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _busquedaController.clear();
                                });
                                ref.read(busquedaFichasProvider.notifier).actualizar('');
                              },
                            ),
                        ],
                        onChanged: (query) {
                          setState(() {});
                          ref.read(busquedaFichasProvider.notifier).actualizar(query);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: etiquetasFiltro.isNotEmpty,
                      label: Text('${etiquetasFiltro.length}'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: etiquetasFiltro.isNotEmpty
                              ? Colors.amber.shade100
                              : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.label_outline,
                            color: Color(0xFF825385),
                          ),
                          tooltip: 'Adjuntar etiquetas al filtro',
                          onPressed: _mostrarSelectorEtiquetasFiltro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Chips de etiquetas adjuntadas al filtro en la barra de búsqueda
              if (etiquetasFiltro.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: etiquetasFiltro.map((tag) {
                      return InputChip(
                        label: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF825385),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        deleteIconColor: Colors.red.shade400,
                        onDeleted: () {
                          ref
                              .read(etiquetasFiltroProvider.notifier)
                              .eliminarEtiqueta(tag);
                        },
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 6),

              // Carrusel horizontal superior de Fichas Recientes (INDEPENDIENTE del filtro de búsqueda/etiquetas)
              fichasRecientesAsync.when(
                data: (recientes) {
                  if (recientes.isEmpty) {
                    return const SizedBox(
                      height: 50,
                      child: Center(
                        child: Text(
                          'No hay recientes',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: recientes.length,
                      itemBuilder: (context, index) {
                        final ficha = recientes[index];
                        return FichaCard(
                          ficha: ficha,
                          ancho: 82,
                          alto: 74,
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
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                error: (e, _) => SizedBox(
                  height: 60,
                  child: Center(
                    child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Sección de Categorías
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categorías',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 20, color: Colors.white),
                      tooltip: 'Gestionar y ordenar categorías',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CategoriasScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              categoriasAsync.when(
                data: (categorias) {
                  if (categorias.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No hay categorías disponibles',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  // Validar que _categoriaSeleccionadaId exista en la lista actual; si no, usar la primera
                  final existeEnLista =
                      categorias.any((c) => c.id == _categoriaSeleccionadaId);
                  final categoriaActivaId = existeEnLista
                      ? _categoriaSeleccionadaId
                      : categorias.first.id;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Listado horizontal de tarjetas cuadradas de categorías
                      SizedBox(
                        height: _tamanoCategoria + 14,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: categorias.length,
                          itemBuilder: (context, index) {
                            final cat = categorias[index];
                            final esSeleccionada = cat.id == categoriaActivaId;

                            return CategoriaCard(
                              key: ValueKey(cat.id ?? index),
                              categoria: cat,
                              esSeleccionada: esSeleccionada,
                              tamano: _tamanoCategoria,
                              alPresionar: () {
                                setState(() {
                                  _categoriaSeleccionadaId = cat.id;
                                });
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Encabezado de la lista vertical de fichas de la categoría activa
                      Builder(
                        builder: (context) {
                          final catActual = categorias.firstWhere(
                            (c) => c.id == categoriaActivaId,
                            orElse: () => categorias.first,
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  catActual.nombre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    ref
                                        .read(categoriaSeleccionadaProvider.notifier)
                                        .seleccionar(catActual.id);
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ListaFichasScreen(),
                                      ),
                                    );
                                    // Al regresar, limpiar el filtro de pantalla secundaria
                                    ref
                                        .read(categoriaSeleccionadaProvider.notifier)
                                        .seleccionar(null);
                                  },
                                  child: const Text('Ver todas'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Listado vertical de fichas de la categoría activa (aplicando filtro de búsqueda y etiquetas si existen)
                      fichasAsync.when(
                        data: (fichas) {
                          final fichasFiltradas = fichas
                              .where((f) => f.categoriaId == categoriaActivaId)
                              .toList();

                          if (fichasFiltradas.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 24.0,
                                horizontal: 16.0,
                              ),
                              child: Center(
                                child: Text(
                                  'No hay fichas en esta categoría',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: fichasFiltradas.map((ficha) {
                              return FichaDetalleCard(
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
                            }).toList(),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => SizedBox(
                  height: _tamanoCategoria + 14,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    ),
        floatingActionButton: Builder(
          builder: (context) {
            final categorias = categoriasAsync.value;
            final existeEnLista = categorias != null &&
                categorias.any((c) => c.id == _categoriaSeleccionadaId);
            final catActivaId = existeEnLista
                ? _categoriaSeleccionadaId
                : (categorias != null && categorias.isNotEmpty
                    ? categorias.first.id
                    : null);

            return FloatingActionButton.extended(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF825385),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalleEditorScreen(
                      categoriaIdInicial: catActivaId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text(
                '+ Ficha',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _abrirEditorConBloque(
    String tipo, {
    String? tituloInicial,
    String? textoInicial,
    String? rutaPortadaInicial,
    int? fichaId,
    int? categoriaId,
  }) async {
    Ficha? fichaExistente;
    if (fichaId != null && fichaId > 0) {
      try {
        final repo = ref.read(fichaRepositoryProvider);
        fichaExistente = await repo.obtenerPorId(fichaId);
      } catch (_) {}
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleEditorScreen(
          ficha: fichaExistente,
          categoriaIdInicial: categoriaId ?? fichaExistente?.categoriaId ?? _categoriaSeleccionadaId,
          tipoBloqueInicial: tipo,
          tituloInicial: tituloInicial,
          textoInicial: textoInicial,
          rutaPortadaInicial: rutaPortadaInicial,
        ),
      ),
    );
  }
}
