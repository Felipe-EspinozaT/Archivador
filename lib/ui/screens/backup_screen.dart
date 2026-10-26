import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/fichas_provider.dart';
import '../../providers/categorias_provider.dart';
import '../../providers/etiquetas_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/ajustes_provider.dart';
import '../../services/overlay_service.dart';
import 'ajustes_screen.dart';

/// Pantalla de Backup centrada exclusivamente en:
/// 1. Selección de "Frecuencia de Respaldo" y sincronización con Google Drive (la cuenta se vincula en Cuenta y Ajustes).
/// 2. Exportar e Importar copia local (con restauración completa de categorías, fichas y etiquetas sin errores de ID).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _sincronizandoNube = false;
  bool _exportandoLocal = false;
  bool _importandoLocal = false;
  String? _mensajeEstado;

  final List<String> _opcionesFrecuencia = [
    'En cada cambio (Automático)',
    'Al cerrar la app',
    'Cada 24 horas',
    'Solo manual',
  ];

  Future<void> _sincronizarAhoraNube() async {
    setState(() => _sincronizandoNube = true);
    try {
      final packageService = ref.read(backupPackageServiceProvider);
      final paquete = await packageService.generarPaqueteCompleto();
      final jsonString = jsonEncode(paquete);
      final totalFichas = paquete['total_fichas'] ?? 0;
      final totalImagenes = paquete['total_imagenes'] ?? 0;
      final fileName = 'simplista_drive_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      // También guardar copia local de respaldo rápido
      await packageService.guardarPaqueteEnArchivo(prefijo: 'simplista_drive_backup');

      if (OverlayService.soportaOverlayNativo) {
        final uriGuardado = await OverlayService.guardarArchivoSelectorSistema(
          fileName: fileName,
          content: jsonString,
        );
        if (mounted) {
          setState(() {
            _sincronizandoNube = false;
            if (uriGuardado != null && uriGuardado.isNotEmpty) {
              _mensajeEstado =
                  'Respaldo guardado en la ubicación seleccionada (Google Drive / Dispositivo):\n• $totalFichas fichas\n• $totalImagenes imágenes y portadas incluidas.';
            } else {
              _mensajeEstado =
                  'Se canceló la selección externa, pero se guardó una copia local de seguridad ($totalFichas fichas y $totalImagenes imágenes).';
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _sincronizandoNube = false;
            _mensajeEstado =
                'Respaldo generado exitosamente:\n• $totalFichas fichas\n• $totalImagenes imágenes y portadas aseguradas.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sincronizandoNube = false;
          _mensajeEstado = 'Error al guardar respaldo en Google Drive: $e';
        });
      }
    }
  }

  /// Exporta todas las categorías, fichas, etiquetas e imágenes en un paquete completo.
  Future<void> _exportarCopiaLocal() async {
    setState(() {
      _exportandoLocal = true;
      _mensajeEstado = null;
    });

    try {
      final packageService = ref.read(backupPackageServiceProvider);
      final archivoGenerado = await packageService.guardarPaqueteEnArchivo();
      final paquete = await packageService.generarPaqueteCompleto();
      final totalFichas = paquete['total_fichas'] ?? 0;
      final totalImagenes = paquete['total_imagenes'] ?? 0;

      setState(() {
        _mensajeEstado =
            'Respaldo completo exportado con éxito:\n• $totalFichas fichas\n• $totalImagenes imágenes/portadas incluidas.\nGuardado en: ${archivoGenerado.path.split("/").last} y en Descargas.';
      });
    } catch (e) {
      setState(() {
        _mensajeEstado = 'Error al exportar copia: $e';
      });
    } finally {
      if (mounted) setState(() => _exportandoLocal = false);
    }
  }

  /// Ejecuta la restauración real de categorías, fichas, etiquetas e imágenes asociadas.
  Future<void> _procesarJsonRestauracion(String contenidoJson, String origen) async {
    setState(() {
      _importandoLocal = true;
      _mensajeEstado = null;
    });

    try {
      final dynamic decodificado = jsonDecode(contenidoJson);
      if (decodificado is! Map<String, dynamic>) {
        throw const FormatException('El formato del respaldo no es un objeto JSON válido.');
      }

      final packageService = ref.read(backupPackageServiceProvider);
      final resultado = await packageService.restaurarPaqueteCompleto(decodificado);

      // Refrescar todos los providers de la aplicación
      ref.invalidate(categoriasProvider);
      ref.invalidate(fichasProvider);
      ref.invalidate(fichasRecientesProvider);
      ref.invalidate(etiquetasProvider);

      setState(() {
        _mensajeEstado =
            'Restauración exitosa desde $origen:\n• ${resultado["categorias"]} categorías\n• ${resultado["fichas"]} fichas recuperadas\n• ${resultado["imagenes"]} imágenes/portadas restauradas con éxito.';
      });
    } catch (e) {
      setState(() {
        _mensajeEstado = 'Error al importar copia: $e';
      });
    } finally {
      if (mounted) setState(() => _importandoLocal = false);
    }
  }

  /// Abre un selector interactivo con todas las copias encontradas en el celular + opción de pegar JSON.
  Future<void> _mostrarModalImportarCopia() async {
    List<File> archivosEncontrados = [];

    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final locales = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('simplista_backup_') && f.path.endsWith('.json'))
            .toList();
        archivosEncontrados.addAll(locales);
      } catch (_) {}

      try {
        final dirDescargas = Directory('/storage/emulated/0/Download');
        if (await dirDescargas.exists()) {
          final enDescargas = dirDescargas
              .listSync()
              .whereType<File>()
              .where((f) => f.path.contains('simplista_backup_') && f.path.endsWith('.json'))
              .toList();
          for (final f in enDescargas) {
            if (!archivosEncontrados.any((x) => x.path.split('/').last == f.path.split('/').last)) {
              archivosEncontrados.add(f);
            }
          }
        }
      } catch (_) {}

      archivosEncontrados.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final navBarBottom = MediaQuery.of(ctx).viewPadding.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + navBarBottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.restore_page_outlined, color: Color(0xFF825385)),
                      SizedBox(width: 8),
                      Text(
                        'Importar Copia de Seguridad',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecciona un archivo del dispositivo, busca en cualquier carpeta o restaura desde Google Drive:',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),

                  // Botón para examinar en cualquier carpeta o Drive usando SAF
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF825385).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF825385),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final contenido = await OverlayService.abrirArchivoSelectorSistema();
                        if (contenido != null && contenido.isNotEmpty) {
                          await _procesarJsonRestauracion(contenido, 'archivo seleccionado');
                        }
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text(
                        'Buscar archivo .json en otra carpeta / Drive',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (archivosEncontrados.isNotEmpty) ...[
                    const Text(
                      'Copias detectadas recientemente:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF825385)),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: archivosEncontrados.length,
                        itemBuilder: (context, index) {
                          final f = archivosEncontrados[index];
                          final nombre = f.path.split(Platform.pathSeparator).last.split('/').last;
                          final mod = f.statSync().modified;
                          final fechaFmt =
                              '${mod.day}/${mod.month}/${mod.year} ${mod.hour.toString().padLeft(2, '0')}:${mod.minute.toString().padLeft(2, '0')}';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.description_outlined, color: Color(0xFF825385)),
                              title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text('Fecha: $fechaFmt', style: const TextStyle(fontSize: 11)),
                              trailing: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF825385),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  final contenido = await f.readAsString();
                                  await _procesarJsonRestauracion(contenido, nombre);
                                },
                                child: const Text('Restaurar', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 20),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.0),
                      child: Text(
                        'No hay archivos locales automáticos en la carpeta interna.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),

                  // Opción para restaurar desde el Portapapeles o pegar JSON manualmente
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _mostrarDialogoPegarJson();
                      },
                      icon: const Icon(Icons.content_paste_go),
                      label: const Text('Pegar respaldo desde Portapapeles / Texto JSON'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _mostrarDialogoPegarJson() async {
    final textController = TextEditingController();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().startsWith('{')) {
      textController.text = data.text!.trim();
    }

    if (!mounted) return;

    final jsonConfirmado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pegar Respaldo JSON', style: TextStyle(fontSize: 17)),
        content: TextField(
          controller: textController,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: '{"version": 2, "categorias": [...], "fichas": [...]}',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF825385)),
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('Importar ahora'),
          ),
        ],
      ),
    );

    if (jsonConfirmado != null && jsonConfirmado.isNotEmpty) {
      await _procesarJsonRestauracion(jsonConfirmado, 'Portapapeles / JSON');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ajustes = ref.watch(ajustesProvider);
    final notifier = ref.read(ajustesProvider.notifier);

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
          foregroundColor: Colors.white,
          title: const Text('Backup y Respaldo', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- SECCIÓN 1: FRECUENCIA DE RESPALDO EN LA NUBE ---
              _construirTarjetaFrecuenciaRespaldo(ajustes, notifier),
              const SizedBox(height: 16),

              // --- SECCIÓN 2: EXPORTAR / IMPORTAR COPIA LOCAL ---
              _construirTarjetaLocal(),
              const SizedBox(height: 16),

              // Mensaje de estado
              if (_mensajeEstado != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF825385)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _mensajeEstado!,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirTarjetaFrecuenciaRespaldo(AjustesEstado ajustes, AjustesNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple.shade50,
                child: const Icon(Icons.schedule_send, color: Color(0xFF825385)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frecuencia de Respaldo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Programación automática en Google Drive',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Selecciona cada cuánto deseas guardar tus cambios automáticamente:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _opcionesFrecuencia.contains(ajustes.frecuenciaRespaldo)
                    ? ajustes.frecuenciaRespaldo
                    : _opcionesFrecuencia[1],
                isExpanded: true,
                items: _opcionesFrecuencia.map((f) {
                  return DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) notifier.cambiarFrecuenciaRespaldo(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (ajustes.googleConectado) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF825385),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _sincronizandoNube ? null : _sincronizarAhoraNube,
                icon: _sincronizandoNube
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(_sincronizandoNube
                    ? 'Sincronizando con ${ajustes.correoGoogle}...'
                    : 'Guardar copia ahora en Google Drive'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF825385),
                  side: const BorderSide(color: Color(0xFF825385)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _sincronizandoNube ? null : () async {
                  setState(() => _sincronizandoNube = true);
                  try {
                    if (OverlayService.soportaOverlayNativo) {
                      final contenidoSeleccionado = await OverlayService.abrirArchivoSelectorSistema();
                      if (contenidoSeleccionado != null && contenidoSeleccionado.isNotEmpty) {
                        await _procesarJsonRestauracion(contenidoSeleccionado, 'Google Drive / Selector del Sistema');
                        return;
                      }
                    }

                    // Fallback si el usuario cierra el selector o está en escritorio: buscar copia local de drive
                    final dir = await getApplicationDocumentsDirectory();
                    final copias = dir
                        .listSync()
                        .whereType<File>()
                        .where((f) => f.path.contains('simplista_drive_backup') && f.path.endsWith('.json'))
                        .toList();

                    if (copias.isEmpty) {
                      setState(() {
                        _sincronizandoNube = false;
                        _mensajeEstado = 'No se seleccionó ningún archivo en el selector de Google Drive.';
                      });
                      return;
                    }

                    copias.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
                    final masReciente = copias.first;
                    final contenido = await masReciente.readAsString();
                    await _procesarJsonRestauracion(contenido, 'Copia rápida local (${masReciente.path.split("/").last})');
                  } catch (e) {
                    setState(() {
                      _mensajeEstado = 'Error al restaurar desde Google Drive: $e';
                    });
                  } finally {
                    if (mounted) setState(() => _sincronizandoNube = false);
                  }
                },
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Restaurar desde Google Drive (Elegir archivo)'),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Conecta tu cuenta de Google en "Cuenta y Ajustes" para activar la subida en la nube.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AjustesScreen()),
                      );
                    },
                    child: const Text('Ir a Cuenta'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirTarjetaLocal() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.sd_storage_outlined, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exportar e Importar Copia',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Respaldo físico local (.json) y Portapapeles',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Exporta todas tus categorías, etiquetas y fichas en un archivo físico dentro de tu celular o impórtalas en cualquier momento.',
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_exportandoLocal || _importandoLocal) ? null : _exportarCopiaLocal,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Exportar copia'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF9810),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_exportandoLocal || _importandoLocal) ? null : _mostrarModalImportarCopia,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Importar copia'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
