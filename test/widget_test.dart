import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplista/main.dart';
import 'package:simplista/models/categoria.dart';
import 'package:simplista/models/ficha.dart';
import 'package:simplista/models/etiqueta.dart';
import 'package:simplista/providers/categorias_provider.dart';
import 'package:simplista/providers/fichas_provider.dart';
import 'package:simplista/providers/etiquetas_provider.dart';
import 'package:simplista/ui/screens/detalle_editor_screen.dart';
import 'package:simplista/ui/screens/categorias_screen.dart';

class TestCategoriasNotifier extends CategoriasNotifier {
  @override
  FutureOr<List<Categoria>> build() {
    return [
      const Categoria(id: 1, nombre: 'Documentos', descripcion: 'Fichas de documentos', colorHex: '#2196F3', orden: 0),
      const Categoria(id: 2, nombre: 'Recibos', descripcion: 'Comprobantes de pago', colorHex: '#FF9800', orden: 1),
      const Categoria(id: 3, nombre: 'Errante', descripcion: 'Fichas sin categoría asignada', colorHex: '#9E9E9E', orden: 2),
    ];
  }
}

class TestFichasNotifier extends FichasNotifier {
  @override
  FutureOr<List<Ficha>> build() {
    return [
      Ficha(
        id: 1,
        titulo: 'Factura de Luz',
        descripcion: 'Factura de luz del mes',
        categoriaId: 1,
        nombreCategoria: 'Documentos',
        colorCategoria: '#2196F3',
        fechaCreacion: DateTime.now(),
        fechaModificacion: DateTime.now(),
      ),
    ];
  }
}

class TestFichasRecientesNotifier extends FichasRecientesNotifier {
  @override
  FutureOr<List<Ficha>> build() {
    return [
      Ficha(
        id: 1,
        titulo: 'Factura de Luz',
        descripcion: 'Factura de luz del mes',
        categoriaId: 1,
        nombreCategoria: 'Documentos',
        colorCategoria: '#2196F3',
        fechaCreacion: DateTime.now(),
        fechaModificacion: DateTime.now(),
      ),
    ];
  }
}

class TestEtiquetasNotifier extends EtiquetasNotifier {
  @override
  FutureOr<List<Etiqueta>> build() {
    return [
      const Etiqueta(id: 1, nombre: 'Impuestos'),
      const Etiqueta(id: 2, nombre: 'Hogar'),
    ];
  }
}

void main() {
  testWidgets('Carga la pantalla de inicio Simplista, CategoriasScreen con ReorderableListView y DetalleEditorScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriasProvider.overrideWith(TestCategoriasNotifier.new),
          fichasProvider.overrideWith(TestFichasNotifier.new),
          fichasRecientesProvider.overrideWith(TestFichasRecientesNotifier.new),
          etiquetasProvider.overrideWith(TestEtiquetasNotifier.new),
        ],
        child: const SimplistaApp(),
      ),
    );

    // Renderizar widgets con los providers sobreescritos
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Validar elementos principales en la interfaz
    expect(find.text('Simplista'), findsWidgets);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Documentos'), findsWidgets);
    expect(find.text('Factura de Luz'), findsWidgets);

    // Validar el buscador de fichas
    expect(find.byType(SearchBar), findsOneWidget);

    // Navegar a CategoriasScreen y verificar que ReorderableListView esté presente allí
    final botonCategorias = find.byTooltip('Gestionar y ordenar categorías');
    expect(botonCategorias, findsOneWidget);
    await tester.tap(botonCategorias);
    await tester.pumpAndSettle();

    expect(find.byType(CategoriasScreen), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.text('Errante'), findsOneWidget);

    // Regresar al InicioScreen
    Navigator.of(tester.element(find.byType(CategoriasScreen))).pop();
    await tester.pumpAndSettle();

    // Buscar y presionar el botón de + Ficha
    final botonNuevaFicha = find.widgetWithText(FloatingActionButton, '+ Ficha');
    expect(botonNuevaFicha, findsOneWidget);

    await tester.tap(botonNuevaFicha);
    await tester.pumpAndSettle();

    // Verificar que navegamos a DetalleEditorScreen
    expect(find.byType(DetalleEditorScreen), findsOneWidget);
    expect(find.text('Título de la ficha...'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);

    // Verificar que el botón de modal de Etiquetas y la barra de acciones estén presentes
    expect(find.text('Etiquetas'), findsOneWidget);
    expect(find.text('Nota'), findsOneWidget);
  });
}

Type typeOf<T>() => T;
