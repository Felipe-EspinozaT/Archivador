import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/inicio_screen.dart';

void main() {
  // Asegura que los enlaces de Flutter estén inicializados antes de interactuar con SQLite
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // ProviderScope provee el contenedor de estado global para Riverpod
    const ProviderScope(
      child: SimplistaApp(),
    ),
  );
}

/// Widget raíz de la aplicación Simplista.
class SimplistaApp extends StatelessWidget {
  const SimplistaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simplista',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF825385),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const InicioScreen(),
    );
  }
}

/// Alias para mantener retrocompatibilidad en pruebas
typedef ArchivadorDigitalApp = SimplistaApp;
