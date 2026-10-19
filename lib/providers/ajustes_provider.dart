import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AjustesEstado {
  final bool barraLateralEditor;
  final bool barraLateralInicio;
  final bool barraLateralSistema; // Superposición fuera de la app (System Overlay)
  final String ladoBarra; // 'derecha' o 'izquierda'
  final String vistaFichasDefault; // 'cuadricula', 'lista', 'tabla'
  final bool googleConectado;
  final String correoGoogle;
  final String frecuenciaRespaldo;

  const AjustesEstado({
    this.barraLateralEditor = true,
    this.barraLateralInicio = false, // Desactivada por default
    this.barraLateralSistema = false, // Desactivada por default (Segundo plano)
    this.ladoBarra = 'derecha',
    this.vistaFichasDefault = 'cuadricula',
    this.googleConectado = false,
    this.correoGoogle = 'usuario@gmail.com',
    this.frecuenciaRespaldo = 'Al cerrar la app',
  });

  AjustesEstado copyWith({
    bool? barraLateralEditor,
    bool? barraLateralInicio,
    bool? barraLateralSistema,
    String? ladoBarra,
    String? vistaFichasDefault,
    bool? googleConectado,
    String? correoGoogle,
    String? frecuenciaRespaldo,
  }) {
    return AjustesEstado(
      barraLateralEditor: barraLateralEditor ?? this.barraLateralEditor,
      barraLateralInicio: barraLateralInicio ?? this.barraLateralInicio,
      barraLateralSistema: barraLateralSistema ?? this.barraLateralSistema,
      ladoBarra: ladoBarra ?? this.ladoBarra,
      vistaFichasDefault: vistaFichasDefault ?? this.vistaFichasDefault,
      googleConectado: googleConectado ?? this.googleConectado,
      correoGoogle: correoGoogle ?? this.correoGoogle,
      frecuenciaRespaldo: frecuenciaRespaldo ?? this.frecuenciaRespaldo,
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
      final sistema = prefs.getBool('barraLateralSistema') ?? false;
      final lado = prefs.getString('ladoBarra') ?? 'derecha';
      final vista = prefs.getString('vistaFichasDefault') ?? 'cuadricula';
      final google = prefs.getBool('googleConectado') ?? false;
      final correo = prefs.getString('correoGoogle') ?? 'usuario@gmail.com';
      final frecuencia = prefs.getString('frecuenciaRespaldo') ?? 'Al cerrar la app';

      state = AjustesEstado(
        barraLateralEditor: editor,
        barraLateralInicio: inicio,
        barraLateralSistema: sistema,
        ladoBarra: lado,
        vistaFichasDefault: vista,
        googleConectado: google,
        correoGoogle: correo,
        frecuenciaRespaldo: frecuencia,
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

  Future<void> toggleBarraSistema(bool valor) async {
    state = state.copyWith(barraLateralSistema: valor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('barraLateralSistema', valor);
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

  Future<void> alternarConexionGoogle({String? correo}) async {
    final nuevoEstado = !state.googleConectado;
    final nuevoCorreo = correo ?? state.correoGoogle;
    state = state.copyWith(
      googleConectado: nuevoEstado,
      correoGoogle: nuevoCorreo,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('googleConectado', nuevoEstado);
    await prefs.setString('correoGoogle', nuevoCorreo);
  }

  Future<void> cambiarFrecuenciaRespaldo(String frecuencia) async {
    state = state.copyWith(frecuenciaRespaldo: frecuencia);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('frecuenciaRespaldo', frecuencia);
  }
}

final ajustesProvider = NotifierProvider<AjustesNotifier, AjustesEstado>(
  AjustesNotifier.new,
);
