/// Modelo de datos que representa una Categoría para clasificar las fichas.
class Categoria {
  final int? id;
  final String nombre;
  final String? descripcion;
  final String colorHex;
  final int orden;
  final String? rutaImagenFondo;

  const Categoria({
    this.id,
    required this.nombre,
    this.descripcion,
    this.colorHex = '#2196F3', // Azul por defecto
    this.orden = 0,
    this.rutaImagenFondo,
  });

  /// Crea una copia del objeto modificando los atributos seleccionados.
  Categoria copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    String? colorHex,
    int? orden,
    String? rutaImagenFondo,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      colorHex: colorHex ?? this.colorHex,
      orden: orden ?? this.orden,
      rutaImagenFondo: rutaImagenFondo ?? this.rutaImagenFondo,
    );
  }

  /// Convierte el objeto a un mapa compatible con SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'color_hex': colorHex,
      'orden': orden,
      'ruta_imagen_fondo': rutaImagenFondo,
    };
  }

  /// Crea una instancia a partir de un mapa de SQLite.
  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      colorHex: (map['color_hex'] as String?) ?? '#2196F3',
      orden: (map['orden'] as int?) ?? 0,
      rutaImagenFondo: map['ruta_imagen_fondo'] as String?,
    );
  }

  @override
  String toString() {
    return 'Categoria(id: $id, nombre: $nombre, colorHex: $colorHex, orden: $orden, rutaImagenFondo: $rutaImagenFondo)';
  }
}
