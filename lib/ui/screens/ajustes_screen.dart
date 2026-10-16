import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ajustes_provider.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ajustes = ref.watch(ajustesProvider);
    final notifier = ref.read(ajustesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes y Personalización'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'HERRAMIENTAS RÁPIDAS (BARRA LATERAL XIAOMI)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF825385),
                letterSpacing: 1.1,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Barra rápida en Editor / Ficha'),
            subtitle: const Text('Pestaña lateral para insertar fórmulas, notas, fechas y fotos al instante'),
            value: ajustes.barraLateralEditor,
            activeColor: const Color(0xFF825385),
            onChanged: (val) => notifier.toggleBarraEditor(val),
          ),
          SwitchListTile(
            title: const Text('Barra rápida global en Inicio'),
            subtitle: const Text('Acceso directo en la pantalla principal para apuntes rápidos (desactivada por defecto)'),
            value: ajustes.barraLateralInicio,
            activeColor: const Color(0xFF825385),
            onChanged: (val) => notifier.toggleBarraInicio(val),
          ),
          ListTile(
            title: const Text('Lado de la barra lateral'),
            subtitle: Text(ajustes.ladoBarra == 'derecha' ? 'Borde Derecho' : 'Borde Izquierdo'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'izquierda', label: Text('Izq')),
                ButtonSegment(value: 'derecha', label: Text('Der')),
              ],
              selected: {ajustes.ladoBarra},
              onSelectionChanged: (val) => notifier.cambiarLadoBarra(val.first),
            ),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'VISTA DE FICHAS Y CATEGORÍAS (ESTILO NOTION)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF825385),
                letterSpacing: 1.1,
              ),
            ),
          ),
          ListTile(
            title: const Text('Disposición predeterminada de fichas'),
            subtitle: Text(
              ajustes.vistaFichasDefault == 'cuadricula'
                  ? 'Galería / Cuadrícula visual'
                  : ajustes.vistaFichasDefault == 'lista'
                      ? 'Lista detallada'
                      : 'Tabla compacta',
            ),
            trailing: DropdownButton<String>(
              value: ajustes.vistaFichasDefault,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'cuadricula', child: Text('Galería')),
                DropdownMenuItem(value: 'lista', child: Text('Lista')),
                DropdownMenuItem(value: 'tabla', child: Text('Tabla')),
              ],
              onChanged: (val) {
                if (val != null) notifier.cambiarVistaDefault(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
