import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ajustes_provider.dart';

class BarraLateralXiaomi extends ConsumerStatefulWidget {
  final VoidCallback onAgregarNota;
  final VoidCallback onAgregarImagen;
  final VoidCallback onAgregarFormula;
  final VoidCallback onAgregarFecha;
  final bool esModoInicio;

  const BarraLateralXiaomi({
    super.key,
    required this.onAgregarNota,
    required this.onAgregarImagen,
    required this.onAgregarFormula,
    required this.onAgregarFecha,
    this.esModoInicio = false,
  });

  @override
  ConsumerState<BarraLateralXiaomi> createState() => _BarraLateralXiaomiState();
}

class _BarraLateralXiaomiState extends ConsumerState<BarraLateralXiaomi>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _despliegueAnim;
  bool _estaAbierta = false;
  double _posicionY = 280.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _despliegueAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _alternarPanel() {
    setState(() {
      _estaAbierta = !_estaAbierta;
      if (_estaAbierta) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ajustes = ref.watch(ajustesProvider);
    final esDerecha = ajustes.ladoBarra == 'derecha';

    return Positioned(
      top: _posicionY,
      right: esDerecha ? 0 : null,
      left: !esDerecha ? 0 : null,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            final screenHeight = MediaQuery.of(context).size.height;
            _posicionY = (_posicionY + details.delta.dy).clamp(100.0, screenHeight - 280.0);
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!esDerecha) ...[
              _construirPestanaInvocadora(esDerecha),
              _construirPanelHerramientas(esDerecha),
            ] else ...[
              _construirPanelHerramientas(esDerecha),
              _construirPestanaInvocadora(esDerecha),
            ],
          ],
        ),
      ),
    );
  }

  /// Pestañita delgada semitransparente tipo barra lateral de Xiaomi (MIUI/HyperOS)
  Widget _construirPestanaInvocadora(bool esDerecha) {
    return GestureDetector(
      onTap: _alternarPanel,
      onHorizontalDragUpdate: (details) {
        if (esDerecha && details.delta.dx < -3 && !_estaAbierta) {
          _alternarPanel();
        } else if (!esDerecha && details.delta.dx > 3 && !_estaAbierta) {
          _alternarPanel();
        } else if (esDerecha && details.delta.dx > 4 && _estaAbierta) {
          _alternarPanel();
        } else if (!esDerecha && details.delta.dx < -4 && _estaAbierta) {
          _alternarPanel();
        }
      },
      child: Container(
        width: 18,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.horizontal(
            left: esDerecha ? const Radius.circular(12) : Radius.zero,
            right: !esDerecha ? const Radius.circular(12) : Radius.zero,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  /// Panel desplegable flotante con las herramientas rápidas
  Widget _construirPanelHerramientas(bool esDerecha) {
    return SizeTransition(
      sizeFactor: _despliegueAnim,
      axis: Axis.horizontal,
      axisAlignment: esDerecha ? 1.0 : -1.0,
      child: FadeTransition(
        opacity: _despliegueAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _itemBoton(
                icon: Icons.functions,
                label: 'Fórmula',
                color: const Color(0xFF38BDF8),
                onTap: () {
                  _alternarPanel();
                  widget.onAgregarFormula();
                },
              ),
              const SizedBox(height: 8),
              _itemBoton(
                icon: Icons.image_outlined,
                label: 'Imagen',
                color: const Color(0xFF4ADE80),
                onTap: () {
                  _alternarPanel();
                  widget.onAgregarImagen();
                },
              ),
              const SizedBox(height: 8),
              _itemBoton(
                icon: Icons.push_pin_outlined,
                label: 'Nota',
                color: const Color(0xFFFBBF24),
                onTap: () {
                  _alternarPanel();
                  widget.onAgregarNota();
                },
              ),
              const SizedBox(height: 8),
              _itemBoton(
                icon: Icons.event_available,
                label: 'Fecha',
                color: const Color(0xFF2DD4BF),
                onTap: () {
                  _alternarPanel();
                  widget.onAgregarFecha();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemBoton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
