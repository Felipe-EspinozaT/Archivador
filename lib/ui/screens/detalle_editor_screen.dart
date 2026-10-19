import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ficha.dart';
import '../../models/bloque_contenido.dart';
import '../../providers/categorias_provider.dart';
import '../../providers/fichas_provider.dart';
import '../../providers/etiquetas_provider.dart';
import '../../providers/database_provider.dart';
import '../../services/storage_service.dart';
import '../../providers/ajustes_provider.dart';
import '../widgets/etiqueta_chip.dart';
import '../widgets/recorte_imagen_modal.dart';
import '../widgets/renderizador_formula_matematica.dart';
import '../widgets/visor_imagen_completa_modal.dart';
import '../widgets/barra_lateral_xiaomi.dart';

/// Pantalla con estética de 'Diario de Campo / Bitácora' para visualizar, crear y editar fichas.
class DetalleEditorScreen extends ConsumerStatefulWidget {
  final Ficha? ficha;
  final int? categoriaIdInicial;
  final String? tipoBloqueInicial;
  final String? textoInicial;
  final String? rutaPortadaInicial;

  const DetalleEditorScreen({
    super.key,
    this.ficha,
    this.categoriaIdInicial,
    this.tipoBloqueInicial,
    this.textoInicial,
    this.rutaPortadaInicial,
  });

  @override
  ConsumerState<DetalleEditorScreen> createState() => _DetalleEditorScreenState();
}

class _DetalleEditorScreenState extends ConsumerState<DetalleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _textoPrincipalController;

  int? _categoriaIdSeleccionada;
  File? _nuevaImagenArchivo;
  String? _rutaImagenExistente;
  bool _eliminarImagenPrevia = false;
  late List<String> _etiquetas;
  final ImagePicker _picker = ImagePicker();
  bool _guardando = false;

  // Lista dinámica y persistente de bloques modulares de la bitácora
  final List<BloqueContenido> _bloques = [];
  final Map<String, TextEditingController> _controladoresNotasBloques = {};
  String? _bloqueFormulaEnEdicionId;
  DateTime? _fechaBitacora;

  bool get _esEdicion => widget.ficha != null;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.ficha?.titulo ?? '');

    // Desempaquetar contenido previo
    final contenidoDesempaquetado = BloquesContenidoHelper.desempaquetar(widget.ficha?.descripcion);
    final textoBase = widget.textoInicial != null && widget.textoInicial!.isNotEmpty
        ? widget.textoInicial!
        : contenidoDesempaquetado.notaPrincipal;
    _textoPrincipalController = TextEditingController(text: textoBase);

    _bloques.addAll(contenidoDesempaquetado.bloques);
    for (final b in _bloques) {
      if (b.tipo == TipoBloqueContenido.nota || b.tipo == TipoBloqueContenido.formula) {
        _controladoresNotasBloques[b.id] = TextEditingController(text: b.valor);
      } else if (b.tipo == TipoBloqueContenido.fecha) {
        _controladoresNotasBloques[b.id] = TextEditingController(text: b.subtitulo ?? '');
      }
    }

    _categoriaIdSeleccionada = widget.ficha?.categoriaId ?? widget.categoriaIdInicial;
    _rutaImagenExistente = widget.ficha?.rutaImagen;
    if (widget.rutaPortadaInicial != null && widget.rutaPortadaInicial!.isNotEmpty) {
      final f = File(widget.rutaPortadaInicial!);
      if (f.existsSync()) {
        _nuevaImagenArchivo = f;
      }
    }
    _etiquetas = widget.ficha?.etiquetas.map((e) => e.nombre).toList() ?? [];
    _fechaBitacora = widget.ficha?.fechaCreacion ?? DateTime.now();

    if (widget.tipoBloqueInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.tipoBloqueInicial) {
          case 'formula':
            _agregarBloqueFormula();
            break;
          case 'nota':
            _agregarBloqueNota();
            break;
          case 'imagen':
            _agregarImagenAnexa(ImageSource.gallery, proporcionAncho: 0.5);
            break;
          case 'fecha':
            _agregarBloqueFecha();
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _textoPrincipalController.dispose();
    for (final c in _controladoresNotasBloques.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Permite seleccionar la imagen principal y elegir su ajuste/proporción con recorte interactivo
  Future<void> _seleccionarImagenPrincipal(ImageSource origen) async {
    try {
      final picked = await _picker.pickImage(source: origen, imageQuality: 85);
      if (picked != null && mounted) {
        final archivoRecortado = await RecorteImagenModal.mostrar(
          context,
          archivoImagen: File(picked.path),
          aspectoObjetivo: 2.0, // Formato panorámico/portada 1x2 por defecto
        );

        if (archivoRecortado != null && mounted) {
          setState(() {
            _nuevaImagenArchivo = archivoRecortado;
            _rutaImagenExistente = archivoRecortado.path;
            _eliminarImagenPrevia = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  // Agrega una imagen anexa a la bitácora con recorte interactivo (1:1 o 1x2)
  Future<void> _agregarImagenAnexa(ImageSource origen, {required double proporcionAncho}) async {
    try {
      final picked = await _picker.pickImage(source: origen, imageQuality: 85);
      if (picked != null && mounted) {
        final aspectoRecorte = proporcionAncho < 0.9 ? 1.0 : 2.0;
        final archivoRecortado = await RecorteImagenModal.mostrar(
          context,
          archivoImagen: File(picked.path),
          aspectoObjetivo: aspectoRecorte,
        );

        if (archivoRecortado != null && mounted) {
          final id = 'img_${DateTime.now().millisecondsSinceEpoch}_${_bloques.length}';
          setState(() {
            _bloques.add(
              BloqueContenido(
                id: id,
                tipo: TipoBloqueContenido.imagen,
                valor: archivoRecortado.path,
                proporcionAncho: proporcionAncho,
              ),
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al adjuntar imagen: $e')),
        );
      }
    }
  }

  void _removerImagenPrincipal() {
    setState(() {
      _nuevaImagenArchivo = null;
      _rutaImagenExistente = null;
      _eliminarImagenPrevia = true;
    });
  }

  void _agregarBloqueNota({double proporcionAncho = 0.5}) {
    final id = 'nota_${DateTime.now().millisecondsSinceEpoch}_${_bloques.length}';
    final controller = TextEditingController();
    _controladoresNotasBloques[id] = controller;

    setState(() {
      _bloques.add(
        BloqueContenido(
          id: id,
          tipo: TipoBloqueContenido.nota,
          valor: '',
          proporcionAncho: proporcionAncho,
        ),
      );
    });
  }

  void _agregarBloqueFormula() {
    final id = 'form_${DateTime.now().millisecondsSinceEpoch}_${_bloques.length}';
    final controller = TextEditingController();
    _controladoresNotasBloques[id] = controller;

    setState(() {
      _bloqueFormulaEnEdicionId = id;
      _bloques.add(
        BloqueContenido(
          id: id,
          tipo: TipoBloqueContenido.formula,
          valor: '',
          proporcionAncho: 1.0,
        ),
      );
    });
  }

  void _agregarBloqueFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF825385),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccionada != null && mounted) {
      final id = 'fecha_${DateTime.now().millisecondsSinceEpoch}_${_bloques.length}';
      final controller = TextEditingController();
      _controladoresNotasBloques[id] = controller;

      setState(() {
        _bloques.add(
          BloqueContenido(
            id: id,
            tipo: TipoBloqueContenido.fecha,
            valor: '${seleccionada.day}/${seleccionada.month}/${seleccionada.year}',
            proporcionAncho: 0.5,
          ),
        );
      });
    }
  }

  void _eliminarBloque(int index) {
    final b = _bloques[index];
    if (_controladoresNotasBloques.containsKey(b.id)) {
      _controladoresNotasBloques[b.id]?.dispose();
      _controladoresNotasBloques.remove(b.id);
    }
    setState(() {
      _bloques.removeAt(index);
    });
  }

  void _alternarProporcionBloque(int index) {
    setState(() {
      final actual = _bloques[index];
      // Alterna entre ancho medio (0.5 - cuadrado) y ancho completo (1.0 - rectangular 1x2)
      final nuevoAncho = actual.proporcionAncho >= 0.9 ? 0.5 : 1.0;
      _bloques[index] = actual.copyWith(proporcionAncho: nuevoAncho);
    });
  }

  void _cambiarModoIncrustacion(int index) {
    setState(() {
      final actual = _bloques[index];
      ModoIncrustacion nuevoModo;
      switch (actual.modoIncrustacion) {
        case ModoIncrustacion.arribaAbajo:
          nuevoModo = ModoIncrustacion.alinearDerecha;
          break;
        case ModoIncrustacion.alinearDerecha:
          nuevoModo = ModoIncrustacion.alinearIzquierda;
          break;
        case ModoIncrustacion.alinearIzquierda:
          nuevoModo = ModoIncrustacion.arribaAbajo;
          break;
      }
      _bloques[index] = actual.copyWith(modoIncrustacion: nuevoModo);
    });
  }

  // Modal para agregar contenido: Nota, Imagen anexa, Fórmula, Fecha con texto
  void _mostrarSelectorNuevoContenido() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Color(0xFF825385)),
                    SizedBox(width: 8),
                    Text(
                      'Incrustar contenido a la bitácora',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.shade100,
                    child: const Icon(Icons.sticky_note_2_outlined, color: Colors.orange),
                  ),
                  title: const Text('Nota o Apunte incrustado', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Bloque de texto compacto o ancho completo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _agregarBloqueNota(proporcionAncho: 0.5);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: const Icon(Icons.image_outlined, color: Color(0xFF825385)),
                  ),
                  title: const Text('Imagen anexa', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Foto con ajuste de recorte (1:1 o 1x2) estilo Word'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _mostrarOpcionesImagenAnexa();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.functions, color: Colors.blue),
                  ),
                  title: const Text('Fórmula matemática de Ingeniería', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Fracciones apiladas, sumatorias, derivadas, símbolos'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _agregarBloqueFormula();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: const Icon(Icons.event_note, color: Colors.teal),
                  ),
                  title: const Text('Fecha / Hito con texto opcional', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sello de fecha con apunte breve para bitácoras'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _agregarBloqueFecha();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarOpcionesImagenAnexa() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Elige el formato de la imagen anexa',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.crop_square, color: Color(0xFF825385)),
                title: const Text('Cuadrada (1:1)'),
                subtitle: const Text('Ocupa medio ancho en el diario de campo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _agregarImagenAnexa(ImageSource.gallery, proporcionAncho: 0.5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.crop_16_9, color: Color(0xFF825385)),
                title: const Text('Rectangular (Máx 1x2 ancho completo)'),
                subtitle: const Text('Ocupa todo el ancho en el diario'),
                onTap: () {
                  Navigator.pop(ctx);
                  _agregarImagenAnexa(ImageSource.gallery, proporcionAncho: 1.0);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Modal para gestionar etiquetas
  void _mostrarModalEtiquetas() {
    final controllerTag = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final todasEtiquetas = ref.watch(etiquetasProvider).value ?? [];

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
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
                            'Etiquetas de la Ficha',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controllerTag,
                          decoration: InputDecoration(
                            hintText: 'Nueva etiqueta (ej. Facturas, Auto)',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (t) {
                            final limpio = t.trim();
                            if (limpio.isNotEmpty && !_etiquetas.contains(limpio)) {
                              setState(() => _etiquetas.add(limpio));
                              setModalState(() {});
                              controllerTag.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF825385)),
                        onPressed: () {
                          final limpio = controllerTag.text.trim();
                          if (limpio.isNotEmpty && !_etiquetas.contains(limpio)) {
                            setState(() => _etiquetas.add(limpio));
                            setModalState(() {});
                            controllerTag.clear();
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Asignadas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (_etiquetas.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _etiquetas.map((tag) {
                        return EtiquetaChip(
                          texto: tag,
                          alEliminar: () {
                            setState(() => _etiquetas.remove(tag));
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    )
                  else
                    const Text('No hay etiquetas asignadas a esta ficha.', style: TextStyle(color: Colors.black45)),
                  const SizedBox(height: 16),
                  if (todasEtiquetas.isNotEmpty) ...[
                    const Text('Sugerencias existentes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: todasEtiquetas
                          .where((e) => !_etiquetas.contains(e.nombre))
                          .map((e) {
                        return ActionChip(
                          label: Text(e.nombre),
                          onPressed: () {
                            setState(() => _etiquetas.add(e.nombre));
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF825385)),
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

  Future<void> _seleccionarFechaBitacora() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaBitacora ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF825385),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (seleccionada != null) {
      setState(() {
        _fechaBitacora = seleccionada;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

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
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF825385)),
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
      final storageService = ref.read(storageServiceProvider);

      // 1. Guardar imágenes anexas nuevas al almacenamiento interno persistente
      final List<BloqueContenido> bloquesFinales = [];
      for (final b in _bloques) {
        if (b.tipo == TipoBloqueContenido.imagen) {
          String rutaPersistida = b.valor;
          if (!kIsWeb && File(b.valor).existsSync()) {
            final esCarpetaApp = b.valor.contains('imagenes');
            if (!esCarpetaApp) {
              rutaPersistida = await storageService.guardarImagen(File(b.valor));
            }
          }
          bloquesFinales.add(b.copyWith(valor: rutaPersistida));
        } else if (b.tipo == TipoBloqueContenido.formula) {
          String valorFormula = _controladoresNotasBloques[b.id]?.text.trim() ?? b.valor;
          if (valorFormula.startsWith(RenderizadorFormulaMatematica.prefijoImagenFormula)) {
            final rutaImg = valorFormula.substring(RenderizadorFormulaMatematica.prefijoImagenFormula.length).trim();
            if (!kIsWeb && File(rutaImg).existsSync() && !rutaImg.contains('imagenes')) {
              final nuevaRuta = await storageService.guardarImagen(File(rutaImg));
              valorFormula = '${RenderizadorFormulaMatematica.prefijoImagenFormula}$nuevaRuta';
            }
          }
          bloquesFinales.add(b.copyWith(valor: valorFormula));
        } else if (b.tipo == TipoBloqueContenido.nota) {
          final valorActual = _controladoresNotasBloques[b.id]?.text.trim() ?? b.valor;
          bloquesFinales.add(b.copyWith(valor: valorActual));
        } else if (b.tipo == TipoBloqueContenido.fecha) {
          final textoHito = _controladoresNotasBloques[b.id]?.text.trim() ?? b.subtitulo;
          bloquesFinales.add(b.copyWith(subtitulo: textoHito));
        }
      }

      // 2. Empaquetar todo el contenido modular en formato persistente
      final textoPrincipal = _textoPrincipalController.text.trim();
      final descripcionSerializada = BloquesContenidoHelper.empaquetar(
        textoPrincipal,
        bloquesFinales,
      );

      if (_esEdicion) {
        await notifier.actualizarFicha(
          fichaExistente: widget.ficha!,
          nuevoTitulo: _tituloController.text.trim(),
          nuevaDescripcion: descripcionSerializada,
          nuevaCategoriaId: _categoriaIdSeleccionada,
          nuevaImagenArchivo: _nuevaImagenArchivo,
          eliminarImagenPrevia: _eliminarImagenPrevia,
          etiquetas: _etiquetas,
        );
      } else {
        await notifier.guardarFicha(
          titulo: _tituloController.text.trim(),
          descripcion: descripcionSerializada,
          categoriaId: _categoriaIdSeleccionada,
          archivoImagen: _nuevaImagenArchivo,
          etiquetas: _etiquetas,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
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
        content: Text('¿Seguro que deseas eliminar permanentemente "${widget.ficha!.titulo}"?'),
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
        body: _guardando
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SafeArea(
                child: Stack(
                  children: [
                    // CONTENIDO PRINCIPAL SCROLLEABLE TIPO DIARIO DE CAMPO
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. FOTO DE PORTADA PRINCIPAL (OPCIONAL)
                            _construirSeccionImagenPortada(),
                            const SizedBox(height: 8),

                            // 2. ACCIONES INTEGRADAS BAJO LA IMAGEN Y ALINEADAS A LA DERECHA (NO PERENNES)
                            _construirAccionesBajoImagen(),
                            const SizedBox(height: 12),

                            // 3. TÍTULO EN ÁREA AMPLIA Y TRANSLÚCIDA
                            _construirCampoTitulo(),
                            const SizedBox(height: 12),

                            // 4. METADATOS: Categoría y Fecha
                            _construirBarraMetadatos(categoriasAsync),
                            const SizedBox(height: 12),

                            // 5. ÁREA DE TEXTO PRINCIPAL (MARCO AMPLIO Y TRANSLÚCIDO)
                            _construirCampoTextoPrincipal(),
                            const SizedBox(height: 14),

                            // 6. GRILLA FLEXIBLE DE BLOQUES MODULARES (NOTAS, IMÁGENES ANEXAS, FÓRMULAS)
                            _construirGrillaBloquesModulares(),
                            const SizedBox(height: 16),

                            // 7. BOTÓN CENTRAL: [+ CONTENIDO]
                            Center(
                              child: FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                                  foregroundColor: const Color(0xFF825385),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 2,
                                ),
                                onPressed: _mostrarSelectorNuevoContenido,
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text(
                                  '+ Contenido',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // BOTÓN REGRESAR SOLO FLECHA (SIN CÍRCULO), TRANSLÚCIDO Y FLOTANTE
                    Positioned(
                      top: 6,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        tooltip: 'Regresar',
                        splashRadius: 24,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Acciones debajo de la imagen principal a la derecha: [Etiquetas modal] [Eliminar] [Modificar/Guardar]
  Widget _construirAccionesBajoImagen() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Botón modal de Etiquetas con badge de cantidad
        Badge(
          isLabelVisible: _etiquetas.isNotEmpty,
          label: Text('${_etiquetas.length}'),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
              backgroundColor: Colors.black.withValues(alpha: 0.22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.label_outline, size: 16, color: Colors.white),
            label: const Text('Etiquetas', style: TextStyle(fontSize: 12, color: Colors.white)),
            onPressed: _mostrarModalEtiquetas,
          ),
        ),
        const SizedBox(width: 8),

        if (_esEdicion) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.red.shade300.withValues(alpha: 0.7)),
              backgroundColor: Colors.red.shade900.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
            label: const Text('Eliminar', style: TextStyle(fontSize: 12, color: Colors.white)),
            onPressed: _guardando ? null : _confirmarEliminacion,
          ),
          const SizedBox(width: 8),
        ],

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            foregroundColor: const Color(0xFF825385),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
          icon: const Icon(Icons.check, size: 16),
          label: Text(
            _esEdicion ? 'Modificar' : 'Guardar',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }

  Widget _construirCampoTitulo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: _tituloController,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2C2C2C),
        ),
        decoration: const InputDecoration(
          hintText: 'Título de la ficha...',
          hintStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.normal),
          border: InputBorder.none,
          icon: Icon(Icons.edit_note, color: Color(0xFF825385)),
        ),
        validator: (valor) {
          if (valor == null || valor.trim().isEmpty) {
            return 'Por favor ingresa un título';
          }
          return null;
        },
      ),
    );
  }

  Widget _construirBarraMetadatos(AsyncValue<List<dynamic>> categoriasAsync) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: categoriasAsync.when(
              data: (categorias) {
                final existeSeleccion =
                    categorias.any((c) => c.id == _categoriaIdSeleccionada);
                final valorSeguro = existeSeleccion ? _categoriaIdSeleccionada : null;

                return DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: valorSeguro,
                    isExpanded: true,
                    hint: const Text(
                      'Errante (General)',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Errante (Por defecto)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      ...categorias.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _colorDesdeHex(c.colorHex),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  c.nombre,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (nuevoId) {
                      setState(() => _categoriaIdSeleccionada = nuevoId);
                    },
                  ),
                );
              },
              loading: () => const SizedBox(height: 36, child: LinearProgressIndicator()),
              error: (err, _) => Text('Error: $err', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _seleccionarFechaBitacora,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_outlined, size: 16, color: Color(0xFF825385)),
                  const SizedBox(width: 6),
                  Text(
                    _fechaBitacora != null
                        ? '${_fechaBitacora!.day}/${_fechaBitacora!.month}/${_fechaBitacora!.year}'
                        : 'Fecha',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirCampoTextoPrincipal() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextFormField(
        controller: _textoPrincipalController,
        maxLines: null,
        minLines: 3,
        style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
        decoration: const InputDecoration(
          hintText: 'Texto principal o resumen de la ficha...',
          hintStyle: TextStyle(color: Colors.black38),
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// Construye la grilla de bloques (Notas, Imágenes anexas, Fórmulas) que fluyen juntos
  Widget _construirGrillaBloquesModulares() {
    if (_bloques.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final halfWidth = (totalWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _bloques.asMap().entries.map((entry) {
            final idx = entry.key;
            final bloque = entry.value;
            final esMitad = bloque.proporcionAncho < 0.9;
            final itemWidth = esMitad ? halfWidth : totalWidth;

            return SizedBox(
              key: ValueKey(bloque.id),
              width: itemWidth,
              child: _construirWidgetBloque(bloque, idx, itemWidth),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _pegarImagenEnFormula(TextEditingController? controller, String bloqueId) async {
    if (controller == null) return;
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !mounted) return;

    String rutaFinal = picked.path;
    if (!kIsWeb) {
      final File? archivoRecortado = await RecorteImagenModal.mostrar(
        context,
        archivoImagen: File(picked.path),
        aspectoObjetivo: 3.0, // Proporción ideal 3:1 para fórmulas y ecuaciones
      );
      if (archivoRecortado == null || !mounted) return;
      rutaFinal = archivoRecortado.path;
    }

    controller.text = '[[IMG_FORMULA]]:$rutaFinal';
    setState(() {
      _bloqueFormulaEnEdicionId = null; // Pasar directo a modo solo vista tras pegar imagen
    });
  }

  Widget _construirWidgetBloque(BloqueContenido bloque, int index, double ancho) {
    switch (bloque.tipo) {
      case TipoBloqueContenido.imagen:
        final esCuadrada = bloque.proporcionAncho < 0.9;
        final alto = esCuadrada ? ancho : (ancho * 0.52);

        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                VisorImagenCompletaModal.abrir(
                  context,
                  rutaOUrl: bloque.valor,
                  titulo: 'Imagen anexada',
                );
              },
              child: Container(
                height: alto,
                width: ancho,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: kIsWeb
                      ? Image.network(bloque.valor, fit: BoxFit.cover)
                      : Image.file(File(bloque.valor), fit: BoxFit.cover, cacheWidth: 300),
                ),
              ),
            ),
            // Botones de acción en la tarjeta (eliminar y alternar tamaño)
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _alternarProporcionBloque(index),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        esCuadrada ? Icons.aspect_ratio : Icons.crop_square,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _eliminarBloque(index),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case TipoBloqueContenido.nota:
        final controller = _controladoresNotasBloques[bloque.id];
        final esMitad = bloque.proporcionAncho < 0.9;

        return Container(
          height: esMitad ? ancho : null,
          decoration: BoxDecoration(
            color: Colors.amber.shade50.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade200.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.push_pin, size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'Nota',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _alternarProporcionBloque(index),
                        child: Icon(
                          esMitad ? Icons.aspect_ratio : Icons.crop_square,
                          size: 15,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _eliminarBloque(index),
                        child: const Icon(Icons.close, size: 15, color: Colors.black45),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                flex: esMitad ? 1 : 0,
                child: TextFormField(
                  controller: controller,
                  maxLines: esMitad ? null : 3,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                  decoration: const InputDecoration(
                    hintText: 'Apunte...',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        );

      case TipoBloqueContenido.formula:
        final controller = _controladoresNotasBloques[bloque.id] ??=
            TextEditingController(text: bloque.valor);
        final bool editandoEstaFormula =
            _bloqueFormulaEnEdicionId == bloque.id || controller.text.trim().isEmpty;

        return GestureDetector(
          onTap: () {
            if (!editandoEstaFormula) {
              setState(() {
                _bloqueFormulaEnEdicionId = bloque.id;
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: editandoEstaFormula
                    ? const Color(0xFF1E3A8A)
                    : Colors.blue.shade200.withValues(alpha: 0.9),
                width: editandoEstaFormula ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.functions, size: 16, color: Color(0xFF1E3A8A)),
                        SizedBox(width: 4),
                        Text(
                          'Fórmula / Ecuación',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (editandoEstaFormula && controller.text.trim().isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _bloqueFormulaEnEdicionId = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Listo',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        else if (!editandoEstaFormula)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.edit_outlined, size: 15, color: Colors.blue.shade700),
                          ),
                        GestureDetector(
                          onTap: () => _eliminarBloque(index),
                          child: const Icon(Icons.close, size: 16, color: Colors.black45),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Vista previa renderizada siempre visible (priorizando el contenido)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final textoActual = value.text.trim();
                    final esImagenPegada = textoActual.startsWith('[[IMG_FORMULA]]:');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (textoActual.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              if (esImagenPegada && !editandoEstaFormula) {
                                final path = textoActual.replaceFirst('[[IMG_FORMULA]]:', '');
                                VisorImagenCompletaModal.abrir(
                                  context,
                                  rutaOUrl: path,
                                  titulo: 'Fórmula enmarcada',
                                );
                              } else if (!editandoEstaFormula) {
                                setState(() {
                                  _bloqueFormulaEnEdicionId = bloque.id;
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              margin: EdgeInsets.only(bottom: editandoEstaFormula ? 8 : 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Stack(
                                children: [
                                  RenderizadorFormulaMatematica(formula: textoActual),
                                  if (esImagenPegada && editandoEstaFormula)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              final path = textoActual.replaceFirst('[[IMG_FORMULA]]:', '');
                                              VisorImagenCompletaModal.abrir(
                                                context,
                                                rutaOUrl: path,
                                                titulo: 'Fórmula enmarcada',
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              margin: const EdgeInsets.only(right: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.zoom_in, size: 14, color: Colors.white),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => controller.clear(),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.blue.shade200),
                                              ),
                                              child: const Text(
                                                'Cambiar a texto',
                                                style: TextStyle(fontSize: 10, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // Solo mostrar caja de texto y teclado de ingeniería cuando se hace clic para editar
                        if (editandoEstaFormula && !esImagenPegada)
                          TextFormField(
                            controller: controller,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              setState(() {
                                _bloqueFormulaEnEdicionId = null;
                              });
                            },
                            maxLines: 2,
                            minLines: 1,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Escribe números, variables o ecuaciones (ej. V = I * R, x/y, x^2)...',
                              hintStyle: const TextStyle(color: Colors.black38, fontSize: 11.5),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.85),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.blue.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                              ),
                              isDense: true,
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // Cinta de ecuaciones estilo Word solo visible en modo edición
                if (editandoEstaFormula)
                  TecladoSimbolosIngenieria(
                    alPegarImagenFormula: () => _pegarImagenEnFormula(controller, bloque.id),
                    alInsertar: (simbolo) {
                      final sel = controller.selection;
                      final texto = controller.text;
                      if (texto.startsWith('[[IMG_FORMULA]]:')) {
                        controller.text = simbolo;
                        controller.selection = TextSelection.collapsed(offset: simbolo.length);
                        return;
                      }
                      if (sel.isValid && sel.start >= 0) {
                        final nuevoTexto = texto.replaceRange(sel.start, sel.end, simbolo);
                        controller.value = TextEditingValue(
                          text: nuevoTexto,
                          selection: TextSelection.collapsed(offset: sel.start + simbolo.length),
                        );
                      } else {
                        final nuevoTexto = texto + simbolo;
                        controller.value = TextEditingValue(
                          text: nuevoTexto,
                          selection: TextSelection.collapsed(offset: nuevoTexto.length),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );

      case TipoBloqueContenido.fecha:
        final controller = _controladoresNotasBloques[bloque.id];

        return Container(
          decoration: BoxDecoration(
            color: Colors.teal.shade50.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.shade200.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_available, size: 16, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text(
                        'Fecha / Hito: ${bloque.valor}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _alternarProporcionBloque(index),
                        child: const Icon(Icons.aspect_ratio, size: 15, color: Colors.black45),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _eliminarBloque(index),
                        child: const Icon(Icons.close, size: 15, color: Colors.black45),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: controller,
                maxLines: null,
                style: const TextStyle(fontSize: 13, height: 1.35),
                decoration: const InputDecoration(
                  hintText: 'Texto o apunte del hito (opcional)...',
                  hintStyle: TextStyle(color: Colors.black38, fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Portada opcional de la ficha
  Widget _construirSeccionImagenPortada() {
    final tienePortada = (_nuevaImagenArchivo != null) ||
        (_rutaImagenExistente != null && _rutaImagenExistente!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          if (tienePortada)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: GestureDetector(
                onTap: () {
                  final ruta = _nuevaImagenArchivo?.path ?? _rutaImagenExistente;
                  if (ruta != null && ruta.isNotEmpty) {
                    VisorImagenCompletaModal.abrir(
                      context,
                      rutaOUrl: ruta,
                      titulo: 'Foto de Portada',
                    );
                  }
                },
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _construirContenidoImagenPortada(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _seleccionarImagenPrincipal(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 17),
                  label: const Text('Cámara'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _seleccionarImagenPrincipal(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 17),
                  label: const Text('Portada'),
                ),
                if (tienePortada)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade200),
                    onPressed: _removerImagenPrincipal,
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('Quitar'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirContenidoImagenPortada() {
    if (_nuevaImagenArchivo != null) {
      return Image.file(_nuevaImagenArchivo!, fit: BoxFit.cover);
    }
    if (_rutaImagenExistente == null || _rutaImagenExistente!.isEmpty) {
      return const SizedBox.shrink();
    }
    if (kIsWeb) {
      return Image.network(_rutaImagenExistente!, fit: BoxFit.cover);
    }
    return FutureBuilder<bool>(
      future: File(_rutaImagenExistente!).exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(
            File(_rutaImagenExistente!),
            fit: BoxFit.cover,
            cacheWidth: 400,
          );
        }
        return const SizedBox.shrink();
      },
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
