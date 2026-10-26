import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ajustes_provider.dart';
import '../../services/overlay_service.dart';

class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  bool _procesandoGoogle = false;

  Future<void> _manejarConexionGoogle() async {
    final ajustes = ref.read(ajustesProvider);
    final notifier = ref.read(ajustesProvider.notifier);

    if (!ajustes.googleConectado) {
      // Permitir confirmar o personalizar el correo de Google
      final controller = TextEditingController(text: ajustes.correoGoogle);
      final correoElegido = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_circle, color: Color(0xFF825385)),
              SizedBox(width: 8),
              Text('Conectar Cuenta Google', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el correo de tu cuenta de Google para vincular tus respaldos en Google Drive:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo de Google',
                  hintText: 'ejemplo@gmail.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF825385)),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Vincular Cuenta'),
            ),
          ],
        ),
      );

      if (correoElegido == null || correoElegido.isEmpty) return;

      setState(() => _procesandoGoogle = true);
      await Future.delayed(const Duration(milliseconds: 600));
      await notifier.alternarConexionGoogle(correo: correoElegido);
      if (mounted) {
        setState(() => _procesandoGoogle = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cuenta $correoElegido conectada exitosamente.')),
        );
      }
    } else {
      setState(() => _procesandoGoogle = true);
      await Future.delayed(const Duration(milliseconds: 400));
      await notifier.alternarConexionGoogle();
      if (mounted) {
        setState(() => _procesandoGoogle = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta de Google desvinculada.')),
        );
      }
    }
  }

  Future<void> _manejarToggleSegundoPlano(bool activar) async {
    final notifier = ref.read(ajustesProvider.notifier);
    final ajustes = ref.read(ajustesProvider);

    if (!activar) {
      await OverlayService.detenerBarraSegundoPlano();
      await notifier.toggleBarraSistema(false);
      return;
    }

    if (!OverlayService.soportaOverlayNativo) {
      await notifier.toggleBarraSistema(true);
      return;
    }

    final tienePermiso = await OverlayService.tienePermiso();
    if (!tienePermiso) {
      if (!mounted) return;
      final irAPermisos = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permiso de Superposición'),
          content: const Text(
            'Para mostrar la barra rápida fuera de la aplicación (en segundo plano con consumo mínimo), Android requiere activar el permiso "Mostrar sobre otras aplicaciones".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF825385)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Conceder Permiso'),
            ),
          ],
        ),
      );

      if (irAPermisos == true) {
        await OverlayService.solicitarPermiso();
      }
      return;
    }

    final iniciado = await OverlayService.iniciarBarraSegundoPlano(lado: ajustes.ladoBarra);
    if (iniciado) {
      await notifier.toggleBarraSistema(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barra rápida en segundo plano activada (funciona fuera de la app).'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ajustes = ref.watch(ajustesProvider);
    final notifier = ref.read(ajustesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuenta'),
      ),
      body: ListView(
        children: [
          // 1. SECCIÓN DE CUENTA DE GOOGLE
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'CUENTA Y CONECTIVIDAD GOOGLE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF825385),
                letterSpacing: 1.1,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.purple.shade50.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF825385).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: ajustes.googleConectado
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    child: Icon(
                      ajustes.googleConectado ? Icons.verified_user : Icons.account_circle_outlined,
                      color: ajustes.googleConectado ? Colors.green.shade700 : Colors.grey.shade700,
                    ),
                  ),
                  title: Text(
                    ajustes.googleConectado ? 'Cuenta de Google Conectada' : 'Sin cuenta vinculada',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    ajustes.googleConectado
                        ? ajustes.correoGoogle
                        : 'Conecta tu cuenta para habilitar respaldos automáticos en Google Drive',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ajustes.googleConectado
                          ? Colors.red.shade600
                          : const Color(0xFF825385),
                    ),
                    onPressed: _procesandoGoogle ? null : _manejarConexionGoogle,
                    icon: _procesandoGoogle
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(ajustes.googleConectado ? Icons.logout : Icons.login, size: 18),
                    label: Text(
                      ajustes.googleConectado ? 'Desvincular cuenta de Google' : 'Conectar con Google',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // 2. SECCIÓN DE SELECCIÓN RÁPIDA
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'BARRA LATERAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF825385),
                letterSpacing: 1.1,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text(
              'Selección rápida (siempre listo)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Notas rápidas con título y descripción con una captura para portada, y opción de agregar contenido a la última ficha interactuada',
            ),
            value: ajustes.barraLateralSistema,
            activeThumbColor: const Color(0xFF825385),
            onChanged: _manejarToggleSegundoPlano,
          ),
          ListTile(
            title: const Text('Lado de ubicación'),
            subtitle: Text(ajustes.ladoBarra == 'derecha' ? 'Borde Derecho' : 'Borde Izquierdo'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'izquierda', label: Text('Izq')),
                ButtonSegment(value: 'derecha', label: Text('Der')),
              ],
              selected: {ajustes.ladoBarra},
              onSelectionChanged: (val) async {
                final nuevoLado = val.first;
                await notifier.cambiarLadoBarra(nuevoLado);
                if (ajustes.barraLateralSistema) {
                  await OverlayService.iniciarBarraSegundoPlano(lado: nuevoLado);
                }
              },
            ),
          ),

          // GUÍA VISUAL / TARJETA DE RECOMENDACIÓN DE OPCIONES
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Guía de botones al presionar la "S"',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF825385),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '+',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ficha Rápida nueva',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            'Recorta la pantalla y crea una ficha con título, descripción y categoría.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '⤵',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agregar contenido a la ficha reciente',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            'Despliega barra horizontal para anexar Nota, Recorte, Fórmula o Fecha a la última ficha.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
