import 'etiqueta.dart';

/// Modelo de datos que representa una Ficha del archivador visual.
class Ficha {
  final int? id;
  final String titulo;
  final String? descripcion;
  final int? categoriaId;
  final String? nombreCategoria;
  final String? colorCategoria;
  final DateTime fechaCreacion;
  final DateTime fechaModificacion;
  final String? rutaImagen;
  final List<Etiqueta> etiquetas;

  const Ficha({
    this.id,
    required this.titulo,
    this.descripcion,
    this.categoriaId,
    this.nombreCategoria,
    this.colorCategoria,
    required this.fechaCreacion,
    required this.fechaModificacion,
    this.rutaImagen,
    this.etiquetas = const [],
  });

  /// Copia la ficha con campos modificados.
  Ficha copyWith({
    int? id,
    String? titulo,
    String? descripcion,
    int? categoriaId,
    String? nombreCategoria,
    String? colorCategoria,
    DateTime? fechaCreacion,
    DateTime? fechaModificacion,
    String? rutaImagen,
    List<Etiqueta>? etiquetas,
  }) {
    return Ficha(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      categoriaId: categoriaId ?? this.categoriaId,
      nombreCategoria: nombreCategoria ?? this.nombreCategoria,
      colorCategoria: colorCategoria ?? this.colorCategoria,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      rutaImagen: rutaImagen ?? this.rutaImagen,
      etiquetas: etiquetas ?? this.etiquetas,
    );
  }

  /// Convierte la ficha en un mapa para insertar o actualizar en la tabla 'Fichas'.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'categoria_id': categoriaId,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_modificacion': fechaModificacion.toIso8601String(),
      'ruta_imagen': rutaImagen,
    };
  }

  /// Construye una ficha a partir de un mapa de SQLite.
  factory Ficha.fromMap(Map<String, dynamic> map, {List<Etiqueta> etiquetas = const []}) {
    return Ficha(
      id: map['id'] as int?,
      titulo: map['titulo'] as String,
      descripcion: map['descripcion'] as String?,
      categoriaId: map['categoria_id'] as int?,
      nombreCategoria: map['nombre_categoria'] as String?,
      colorCategoria: map['color_categoria'] as String?,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaModificacion: DateTime.parse(map['fecha_modificacion'] as String),
      rutaImagen: map['ruta_imagen'] as String?,
      etiquetas: etiquetas,
    );
  }

  @override
  String toString() {
    return 'Ficha(id: $id, titulo: $titulo, categoriaId: $categoriaId, rutaImagen: $rutaImagen, etiquetas: ${etiquetas.length})';
  }
}
