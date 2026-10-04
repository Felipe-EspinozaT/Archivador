import 'package:flutter/material.dart';

/// Widget visual para representar una etiqueta en forma de chip.
class EtiquetaChip extends StatelessWidget {
  final String texto;
  final VoidCallback? alEliminar;

  const EtiquetaChip({
    super.key,
    required this.texto,
    this.alEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade800,
            ),
          ),
          if (alEliminar != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: alEliminar,
              child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
            ),
          ],
        ],
      ),
    );
  }
}
