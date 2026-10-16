import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AjustesEstado {
  final bool barraLateralEditor;
  final bool barraLateralInicio;
  final String ladoBarra; // 'derecha' o 'izquierda'
  final String vistaFichasDefault; // 'cuadricula', 'lista', 'tabla'

  const AjustesEstado({
    this.barraLateralEditor = true,
    this.barraLateralInicio = false, // Desactivada por default según solicitud
    this.ladoBarra = 'derecha',
    this.vistaFichasDefault = 'cuadricula',
  });

  AjustesEstado copyWith({
    bool? barraLateralEditor,
    bool? barraLateralInicio,
    String? ladoBarra,
    String? vistaFichasDefault,
  }) {
    return AjustesEstado(
      barraLateralEditor: barraLateralEditor ?? this.barraLateralEditor,
      barraLateralInicio: barraLateralInicio ?? this.barraLateralInicio,
      ladoBarra: ladoBarra ?? this.ladoBarra,
      vistaFichasDefault: vistaFichasDefault ?? this.vistaFichasDefault,
    );
  }
}

class AjustesNotifier extends Notifier<AjustesEstado> {
  @override
  AjustesEstado build() {
    _cargarAjustes();
    return const AjustesEstado();
  }

  Future<void> _cargarAjustes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final editor = prefs.getBool('barraLateralEditor') ?? true;
      final inicio = prefs.getBool('barraLateralInicio') ?? false;
      final lado = prefs.getString('ladoBarra') ?? 'derecha';
      final vista = prefs.getString('vistaFichasDefault') ?? 'cuadricula';

      state = AjustesEstado(
        barraLateralEditor: editor,
        barraLateralInicio: inicio,
        ladoBarra: lado,
        vistaFichasDefault: vista,
      );
    } catch (_) {}
  }

  Future<void> toggleBarraEditor(bool valor) async {
    state = state.copyWith(barraLateralEditor: valor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('barraLateralEditor', valor);
  }

  Future<void> toggleBarraInicio(bool valor) async {
    state = state.copyWith(barraLateralInicio: valor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('barraLateralInicio', valor);
  }

  Future<void> cambiarLadoBarra(String lado) async {
    state = state.copyWith(ladoBarra: lado);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ladoBarra', lado);
  }

  Future<void> cambiarVistaDefault(String vista) async {
    state = state.copyWith(vistaFichasDefault: vista);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vistaFichasDefault', vista);
  }
}

final ajustesProvider = NotifierProvider<AjustesNotifier, AjustesEstado>(
  AjustesNotifier.new,
);
