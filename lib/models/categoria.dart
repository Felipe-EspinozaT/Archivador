/// Modelo de datos que representa una Categoría para clasificar las fichas.
class Categoria {
  final int? id;
  final String nombre;
  final String? descripcion;
  final String colorHex;

  const Categoria({
    this.id,
    required this.nombre,
    this.descripcion,
    this.colorHex = '#2196F3', // Azul por defecto
  });

  /// Crea una copia del objeto modificando los atributos seleccionados.
  Categoria copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    String? colorHex,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  /// Convierte el objeto a un mapa compatible con SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'color_hex': colorHex,
    };
  }

  /// Crea una instancia a partir de un mapa de SQLite.
  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      colorHex: (map['color_hex'] as String?) ?? '#2196F3',
    );
  }

  @override
  String toString() {
    return 'Categoria(id: $id, nombre: $nombre, colorHex: $colorHex)';
  }
}
