import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:archivador_digital/main.dart';
import 'package:archivador_digital/models/categoria.dart';
import 'package:archivador_digital/models/ficha.dart';
import 'package:archivador_digital/providers/categorias_provider.dart';
import 'package:archivador_digital/providers/fichas_provider.dart';
import 'package:archivador_digital/ui/screens/detalle_editor_screen.dart';

class TestCategoriasNotifier extends CategoriasNotifier {
  @override
  FutureOr<List<Categoria>> build() {
    return [
      const Categoria(id: 1, nombre: 'Documentos', descripcion: 'Fichas de documentos', colorHex: '#2196F3'),
      const Categoria(id: 2, nombre: 'Recibos', descripcion: 'Comprobantes de pago', colorHex: '#FF9800'),
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

void main() {
  testWidgets('Carga la pantalla de inicio y navega hacia DetalleEditorScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriasProvider.overrideWith(TestCategoriasNotifier.new),
          fichasProvider.overrideWith(TestFichasNotifier.new),
        ],
        child: const ArchivadorDigitalApp(),
      ),
    );

    // Renderizar widgets con los providers sobreescritos
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Validar elementos principales de la interfaz
    expect(find.text('Archivador Digital'), findsOneWidget);
    expect(find.text('Modo Offline Activo'), findsOneWidget);
    expect(find.text('Categorías'), findsNWidgets(2));
    expect(find.text('Documentos'), findsNWidgets(2));
    expect(find.text('Factura de Luz'), findsOneWidget);

    // Buscar y presionar el botón de Nueva Ficha
    final botonNuevaFicha = find.widgetWithText(FloatingActionButton, 'Nueva Ficha');
    expect(botonNuevaFicha, findsOneWidget);

    await tester.tap(botonNuevaFicha);
    await tester.pumpAndSettle();

    // Verificar que navegamos a DetalleEditorScreen
    expect(find.byType(DetalleEditorScreen), findsOneWidget);
    expect(find.text('Nueva Ficha'), findsOneWidget);
    expect(find.text('Título de la ficha *'), findsOneWidget);
    expect(find.text('Guardar Ficha'), findsOneWidget);
  });
}
