/// Modelo de datos que representa una Etiqueta asignable a múltiples fichas.
class Etiqueta {
  final int? id;
  final String nombre;

  const Etiqueta({
    this.id,
    required this.nombre,
  });

  /// Copia el modelo con nuevos valores.
  Etiqueta copyWith({
    int? id,
    String? nombre,
  }) {
    return Etiqueta(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
    );
  }

  /// Convierte a mapa para SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
    };
  }

  /// Crea una instancia a partir de un mapa de SQLite.
  factory Etiqueta.fromMap(Map<String, dynamic> map) {
    return Etiqueta(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
    );
  }

  @override
  String toString() {
    return 'Etiqueta(id: $id, nombre: $nombre)';
  }
}
