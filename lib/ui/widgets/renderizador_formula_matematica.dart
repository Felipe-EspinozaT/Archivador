import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Widget que procesa y renderiza visualmente fórmulas matemáticas estilo Word:
/// - Estructuras: Fracciones apiladas [num / den], Índices (x², x_i), Radicales (√(x), ⁿ√(x)),
///   Integrales con límites (∫_a^b), Operadores grandes / Sumatorias (∑_{i=0}^n),
///   Corchetes/Paréntesis, Funciones (sin, cos, tan, log, ln), Límites (lim_{x→∞}), Matrices 2x2.
/// - También soporta adjuntar un recorte de imagen de fórmula si el usuario prefiere pegar una foto.
class RenderizadorFormulaMatematica extends StatelessWidget {
  final String formula;
  final TextStyle? estiloBase;

  const RenderizadorFormulaMatematica({
    super.key,
    required this.formula,
    this.estiloBase,
  });

  static const String prefijoImagenFormula = '[[IMG_FORMULA]]:';

  @override
  Widget build(BuildContext context) {
    final texto = formula.trim();
    if (texto.isEmpty) {
      return const SizedBox.shrink();
    }

    // Si es una imagen de ecuación recortada de la galería
    if (texto.startsWith(prefijoImagenFormula)) {
      final ruta = texto.substring(prefijoImagenFormula.length).trim();
      if (ruta.isEmpty) return const SizedBox.shrink();
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 110),
          child: kIsWeb
              ? Image.network(ruta, fit: BoxFit.contain)
              : Image.file(
                  File(ruta),
                  fit: BoxFit.contain,
                  cacheWidth: 400,
                  errorBuilder: (_, __, ___) => const Text('Imagen de fórmula no disponible'),
                ),
        ),
      );
    }

    final estilo = estiloBase ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E3A8A),
          fontFamily: 'serif',
        );

    final widgets = _analizarExpresion(texto, estilo);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: widgets,
        ),
      ),
    );
  }

  List<Widget> _analizarExpresion(String expresion, TextStyle estilo) {
    String exp = expresion
        .replaceAll(r'\sum', '∑')
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\partial', '∂')
        .replaceAll(r'\ohm', 'Ω')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\gamma', 'γ')
        .replaceAll(r'\lambda', 'λ')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\delta', 'Δ')
        .replaceAll(r'\nabla', '∇')
        .replaceAll(r'\sqrt', '√');

    final List<Widget> resultado = [];

    // Patrón unificado para detectar estructuras tipo Word:
    // 1. \frac{num}{den}
    // 2. \int_{inf}^{sup}
    // 3. \sum_{inf}^{sup}
    // 4. \lim_{sub}
    // 5. \sqrt[n]{rad} o \sqrt{rad}
    // 6. \matrix{a,b;c,d}
    final regexEstructuras = RegExp(
      r'(\\frac\{([^{}]*)\}\{([^{}]*)\})|'
      r'(\\int_\{([^{}]*)\}\^\{([^{}]*)\})|'
      r'(\\sum_\{([^{}]*)\}\^\{([^{}]*)\})|'
      r'(\\lim_\{([^{}]*)\})|'
      r'(\\sqrt(?:\[([^\[\]]*)\])?\{([^{}]*)\})|'
      r'(\\matrix\{([^{}]*)\})',
    );

    int cursor = 0;

    for (final match in regexEstructuras.allMatches(exp)) {
      if (match.start > cursor) {
        final previo = exp.substring(cursor, match.start);
        resultado.addAll(_convertirTokensSimples(previo, estilo));
      }

      if (match.group(1) != null) {
        // \frac{num}{den}
        resultado.add(_construirFraccionApilada(match.group(2) ?? '', match.group(3) ?? '', estilo));
      } else if (match.group(4) != null) {
        // \int_{a}^{b}
        resultado.add(_construirOperadorConLimites('∫', match.group(5) ?? '', match.group(6) ?? '', estilo));
      } else if (match.group(7) != null) {
        // \sum_{i=0}^{n}
        resultado.add(_construirOperadorConLimites('∑', match.group(8) ?? '', match.group(9) ?? '', estilo));
      } else if (match.group(10) != null) {
        // \lim_{x->\infty}
        resultado.add(_construirLimite(match.group(11) ?? '', estilo));
      } else if (match.group(12) != null) {
        // \sqrt[n]{x}
        resultado.add(_construirRadical(match.group(13), match.group(14) ?? '', estilo));
      } else if (match.group(15) != null) {
        // \matrix{a,b;c,d}
        resultado.add(_construirMatriz(match.group(16) ?? '', estilo));
      }

      cursor = match.end;
    }

    if (cursor < exp.length) {
      final resto = exp.substring(cursor);
      resultado.addAll(_convertirTokensSimples(resto, estilo));
    }

    return resultado;
  }

  /// Fracción apilada estilo Word: numerador sobre denominador
  Widget _construirFraccionApilada(String numerador, String denominador, TextStyle estilo) {
    final estiloFrac = estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 0.88);
    final numTxt = numerador.trim().isEmpty ? '□' : numerador.trim();
    final denTxt = denominador.trim().isEmpty ? '□' : denominador.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(numTxt, style: estiloFrac, textAlign: TextAlign.center),
            ),
            Container(
              height: 1.5,
              color: estilo.color ?? const Color(0xFF1E3A8A),
              margin: const EdgeInsets.symmetric(vertical: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(denTxt, style: estiloFrac, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  /// Operador grande (Integral o Sumatoria) con límite superior e inferior estilo Word
  Widget _construirOperadorConLimites(String simbolo, String inferior, String superior, TextStyle estilo) {
    final estiloLim = estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 0.65);
    final estiloSimbolo = estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 1.45);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (superior.isNotEmpty) Text(superior, style: estiloLim),
          Text(simbolo, style: estiloSimbolo.copyWith(height: 1.0)),
          if (inferior.isNotEmpty) Text(inferior, style: estiloLim),
        ],
      ),
    );
  }

  /// Estructura Límite: lim con subíndice debajo
  Widget _construirLimite(String subindice, TextStyle estilo) {
    final estiloSub = estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 0.68);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('lim', style: estilo.copyWith(fontStyle: FontStyle.italic)),
          Text(subindice.replaceAll('->', '→'), style: estiloSub),
        ],
      ),
    );
  }

  /// Estructura Radical con línea superior sobre el radicando
  Widget _construirRadical(String? indice, String radicando, TextStyle estilo) {
    final estiloIndice = estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 0.65);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (indice != null && indice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(indice, style: estiloIndice),
            ),
          Text('√', style: estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 1.25)),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: estilo.color ?? const Color(0xFF1E3A8A),
                  width: 1.4,
                ),
              ),
            ),
            padding: const EdgeInsets.only(top: 1, left: 2, right: 3),
            child: Text(radicando.isEmpty ? '□' : radicando, style: estilo),
          ),
        ],
      ),
    );
  }

  /// Estructura Matriz entre corchetes
  Widget _construirMatriz(String contenido, TextStyle estilo) {
    final filas = contenido.split(';');
    final estiloCelda = estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.symmetric(
            vertical: BorderSide(color: estilo.color ?? const Color(0xFF1E3A8A), width: 1.8),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: filas.map((f) {
            final cols = f.split(',');
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: cols
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text(c.trim(), style: estiloCelda),
                      ))
                  .toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Convierte divisiones directas (x/y) y potencias/subíndices simples (x^2, x_1)
  List<Widget> _convertirTokensSimples(String texto, TextStyle estilo) {
    final List<Widget> widgets = [];
    final palabras = texto.split(' ');

    for (int i = 0; i < palabras.length; i++) {
      final token = palabras[i];
      if (token.isEmpty) continue;

      // Si el usuario escribe a/b directamente con barra
      if (token.contains('/') &&
          !token.startsWith('http') &&
          token.length >= 3 &&
          token.indexOf('/') == token.lastIndexOf('/')) {
        final partes = token.split('/');
        if (partes.length == 2 && partes[0].trim().isNotEmpty && partes[1].trim().isNotEmpty) {
          widgets.add(_construirFraccionApilada(partes[0], partes[1], estilo));
          if (i < palabras.length - 1) widgets.add(const SizedBox(width: 4));
          continue;
        }
      }

      // Si contiene superíndice explícito base^exp
      if (token.contains('^') && token.indexOf('^') > 0 && token.indexOf('^') < token.length - 1) {
        final partes = token.split('^');
        if (partes.length == 2) {
          widgets.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partes[0], style: estilo),
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: Text(
                    partes[1].replaceAll('{', '').replaceAll('}', ''),
                    style: estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 0.72),
                  ),
                ),
              ],
            ),
          );
          if (i < palabras.length - 1) widgets.add(const SizedBox(width: 4));
          continue;
        }
      }

      // Si contiene subíndice explícito base_sub
      if (token.contains('_') && token.indexOf('_') > 0 && token.indexOf('_') < token.length - 1) {
        final partes = token.split('_');
        if (partes.length == 2) {
          widgets.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(partes[0], style: estilo),
                Transform.translate(
                  offset: const Offset(0, 3),
                  child: Text(
                    partes[1].replaceAll('{', '').replaceAll('}', ''),
                    style: estilo.copyWith(fontSize: (estilo.fontSize ?? 16) * 0.72),
                  ),
                ),
              ],
            ),
          );
          if (i < palabras.length - 1) widgets.add(const SizedBox(width: 4));
          continue;
        }
      }

      widgets.add(Text(token, style: estilo));
      if (i < palabras.length - 1) {
        widgets.add(const SizedBox(width: 4));
      }
    }

    return widgets;
  }
}

/// Panel de Ecuaciones inspirado en la cinta de Word:
/// Pestaña 1: "Estructuras" (Fracción, Índice, Radical, Integral, Sumatoria, Límite, Función, Matriz)
/// Pestaña 2: "Símbolos" (±, ∞, ≠, ×, ÷, ∂, √, Δ, Ω, π, θ, λ, μ, etc.)
/// Además incluye botón directo para "Pegar imagen de fórmula" desde galería con recorte.
class TecladoSimbolosIngenieria extends StatefulWidget {
  final Function(String) alInsertar;
  final VoidCallback? alPegarImagenFormula;

  const TecladoSimbolosIngenieria({
    super.key,
    required this.alInsertar,
    this.alPegarImagenFormula,
  });

  @override
  State<TecladoSimbolosIngenieria> createState() => _TecladoSimbolosIngenieriaState();
}

class _TecladoSimbolosIngenieriaState extends State<TecladoSimbolosIngenieria> {
  bool _mostrarEstructuras = true;

  static const List<Map<String, String>> estructurasWord = [
    {'titulo': 'Fracción', 'icono': 'x/y', 'plantilla': r'\frac{x}{y}'},
    {'titulo': 'Índice', 'icono': 'eˣ', 'plantilla': 'x^2'},
    {'titulo': 'Subíndice', 'icono': 'xᵢ', 'plantilla': 'x_1'},
    {'titulo': 'Radical', 'icono': '√x', 'plantilla': r'\sqrt{x}'},
    {'titulo': 'Raíz n', 'icono': 'ⁿ√x', 'plantilla': r'\sqrt[3]{x}'},
    {'titulo': 'Integral', 'icono': '∫ₐᵇ', 'plantilla': r'\int_{a}^{b} '},
    {'titulo': 'Sumatoria', 'icono': '∑', 'plantilla': r'\sum_{i=1}^{n} '},
    {'titulo': 'Límite', 'icono': 'lim', 'plantilla': r'\lim_{x->\infty} '},
    {'titulo': 'Seno/Cos', 'icono': 'sin θ', 'plantilla': 'sin(θ)'},
    {'titulo': 'Log/Ln', 'icono': 'ln(x)', 'plantilla': 'ln(x)'},
    {'titulo': 'Corchete', 'icono': '(x)', 'plantilla': '(x + y)'},
    {'titulo': 'Matriz', 'icono': '[a b]', 'plantilla': r'\matrix{1,0;0,1}'},
  ];

  static const List<Map<String, String>> simbolosWord = [
    {'etiqueta': '±', 'valor': '±'},
    {'etiqueta': '∞', 'valor': '∞'},
    {'etiqueta': '=', 'valor': ' = '},
    {'etiqueta': '≠', 'valor': ' ≠ '},
    {'etiqueta': '≈', 'valor': ' ≈ '},
    {'etiqueta': '×', 'valor': ' × '},
    {'etiqueta': '÷', 'valor': ' ÷ '},
    {'etiqueta': '≤', 'valor': ' ≤ '},
    {'etiqueta': '≥', 'valor': ' ≥ '},
    {'etiqueta': '∂', 'valor': '∂'},
    {'etiqueta': 'Δ', 'valor': 'Δ'},
    {'etiqueta': '∇', 'valor': '∇'},
    {'etiqueta': 'π', 'valor': 'π'},
    {'etiqueta': 'Ω', 'valor': 'Ω'},
    {'etiqueta': 'μ', 'valor': 'μ'},
    {'etiqueta': 'θ', 'valor': 'θ'},
    {'etiqueta': 'λ', 'valor': 'λ'},
    {'etiqueta': 'α', 'valor': 'α'},
    {'etiqueta': 'β', 'valor': 'β'},
    {'etiqueta': '°C', 'valor': '°C'},
    {'etiqueta': '→', 'valor': ' → '},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector superior: [Estructuras Word] | [Símbolos] | [📷 Foto Ecuación]
        Row(
          children: [
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: const Text('Estructuras', style: TextStyle(fontSize: 11)),
              selected: _mostrarEstructuras,
              selectedColor: Colors.blue.shade200,
              onSelected: (_) => setState(() => _mostrarEstructuras = true),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: const Text('Símbolos', style: TextStyle(fontSize: 11)),
              selected: !_mostrarEstructuras,
              selectedColor: Colors.blue.shade200,
              onSelected: (_) => setState(() => _mostrarEstructuras = false),
            ),
            const Spacer(),
            if (widget.alPegarImagenFormula != null)
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF825385),
                  backgroundColor: Colors.purple.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.alPegarImagenFormula,
                icon: const Icon(Icons.crop_original, size: 15),
                label: const Text('Pegar foto fórmula', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 6),

        if (_mostrarEstructuras)
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: estructurasWord.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final est = estructurasWord[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => widget.alInsertar(est['plantilla']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          est['icono']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          est['titulo']!,
                          style: const TextStyle(fontSize: 9, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        else
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: simbolosWord.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final s = simbolosWord[index];
                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.blue.shade200),
                  label: Text(
                    s['etiqueta']!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  onPressed: () => widget.alInsertar(s['valor']!),
                );
              },
            ),
          ),
      ],
    );
  }
}
