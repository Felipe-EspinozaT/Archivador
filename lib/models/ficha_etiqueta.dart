/// Modelo para la relación de muchos a muchos entre Fichas y Etiquetas.
class FichaEtiqueta {
  final int fichaId;
  final int etiquetaId;

  const FichaEtiqueta({
    required this.fichaId,
    required this.etiquetaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'ficha_id': fichaId,
      'etiqueta_id': etiquetaId,
    };
  }

  factory FichaEtiqueta.fromMap(Map<String, dynamic> map) {
    return FichaEtiqueta(
      fichaId: map['ficha_id'] as int,
      etiquetaId: map['etiqueta_id'] as int,
    );
  }
}
