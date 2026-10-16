import 'dart:convert';

/// Tipos de bloque admitidos en el diario de campo.
enum TipoBloqueContenido {
  nota,
  imagen,
  formula,
  fecha,
}

/// Modo de incrustación de un bloque respecto al flujo del texto (estilo Word):
/// - 'arribaAbajo': Bloque separado en su propio renglón (ocupa todo el ancho o mitad).
/// - 'alinearDerecha': Incrustado a la derecha flotando.
/// - 'alinearIzquierda': Incrustado a la izquierda flotando.
enum ModoIncrustacion {
  arribaAbajo,
  alinearDerecha,
  alinearIzquierda,
}

/// Representa un bloque modular de contenido dentro de una Ficha (Bitácora de campo).
class BloqueContenido {
  final String id;
  final TipoBloqueContenido tipo;
  final String valor; // Texto de la nota, ruta de la imagen, fórmula o fecha ISO
  final double proporcionAncho; // 1.0 (ancho completo) o 0.5 (medio ancho)
  final String? subtitulo; // Texto secundario (o comentario para el bloque fecha/imagen)
  final ModoIncrustacion modoIncrustacion;

  BloqueContenido({
    required this.id,
    required this.tipo,
    required this.valor,
    this.proporcionAncho = 1.0,
    this.subtitulo,
    this.modoIncrustacion = ModoIncrustacion.arribaAbajo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo.name,
      'valor': valor,
      'proporcionAncho': proporcionAncho,
      if (subtitulo != null) 'subtitulo': subtitulo,
      'modoIncrustacion': modoIncrustacion.name,
    };
  }

  factory BloqueContenido.fromMap(Map<String, dynamic> map) {
    return BloqueContenido(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoBloqueContenido.values.firstWhere(
        (t) => t.name == map['tipo'],
        orElse: () => TipoBloqueContenido.nota,
      ),
      valor: map['valor'] as String? ?? '',
      proporcionAncho: (map['proporcionAncho'] as num?)?.toDouble() ?? 1.0,
      subtitulo: map['subtitulo'] as String?,
      modoIncrustacion: ModoIncrustacion.values.firstWhere(
        (m) => m.name == map['modoIncrustacion'],
        orElse: () => ModoIncrustacion.arribaAbajo,
      ),
    );
  }

  BloqueContenido copyWith({
    String? id,
    TipoBloqueContenido? tipo,
    String? valor,
    double? proporcionAncho,
    String? subtitulo,
    ModoIncrustacion? modoIncrustacion,
  }) {
    return BloqueContenido(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      valor: valor ?? this.valor,
      proporcionAncho: proporcionAncho ?? this.proporcionAncho,
      subtitulo: subtitulo ?? this.subtitulo,
      modoIncrustacion: modoIncrustacion ?? this.modoIncrustacion,
    );
  }
}

/// Utilidad para serializar y deserializar la lista de bloques en la descripción o JSON.
class BloquesContenidoHelper {
  static const String prefijoJson = '[[SIMPLISTA_BLOQUES]]';

  /// Serializa la nota principal y los bloques modulares a un solo String persistente para SQLite y Backup.
  static String empaquetar(String notaPrincipal, List<BloqueContenido> bloques) {
    final mapa = {
      'notaPrincipal': notaPrincipal,
      'bloques': bloques.map((b) => b.toMap()).toList(),
    };
    return '$prefijoJson${jsonEncode(mapa)}';
  }

  /// Desempaqueta el String almacenado en SQLite. Si era texto plano antiguo, lo maneja transparentemente.
  static ({String notaPrincipal, List<BloqueContenido> bloques}) desempaquetar(String? contenido) {
    if (contenido == null || contenido.trim().isEmpty) {
      return (notaPrincipal: '', bloques: <BloqueContenido>[]);
    }

    if (contenido.startsWith(prefijoJson)) {
      try {
        final jsonStr = contenido.substring(prefijoJson.length);
        final mapa = jsonDecode(jsonStr) as Map<String, dynamic>;
        final nota = mapa['notaPrincipal'] as String? ?? '';
        final listaRaw = mapa['bloques'] as List<dynamic>? ?? [];
        final bloques = listaRaw
            .map((e) => BloqueContenido.fromMap(e as Map<String, dynamic>))
            .toList();
        return (notaPrincipal: nota, bloques: bloques);
      } catch (_) {
        return (notaPrincipal: contenido, bloques: <BloqueContenido>[]);
      }
    }

    // Compatibilidad con fichas previas que usaban formato simple o separador ---
    if (contenido.contains('\n\n---\n')) {
      final partes = contenido.split('\n\n---\n');
      final principal = partes.first;
      final extras = partes.sublist(1).join('\n\n---\n').split('\n\n');
      final bloques = extras.map((t) => BloqueContenido(
        id: DateTime.now().millisecondsSinceEpoch.toString() + t.hashCode.toString(),
        tipo: TipoBloqueContenido.nota,
        valor: t,
        proporcionAncho: 0.5,
      )).toList();
      return (notaPrincipal: principal, bloques: bloques);
    }

    return (notaPrincipal: contenido, bloques: <BloqueContenido>[]);
  }

  /// Retorna un texto limpio representativo para búsquedas y tarjetas resumen.
  static String obtenerResumenTexto(String? contenido) {
    if (contenido == null) return '';
    final resultado = desempaquetar(contenido);
    if (resultado.notaPrincipal.isNotEmpty) {
      return resultado.notaPrincipal;
    }
    for (final b in resultado.bloques) {
      if (b.tipo == TipoBloqueContenido.nota && b.valor.isNotEmpty) {
        return b.valor;
      }
    }
    return '';
  }
}
