import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/inicio_screen.dart';

void main() {
  // Asegura que los enlaces de Flutter estén inicializados antes de interactuar con SQLite
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // ProviderScope provee el contenedor de estado global para Riverpod
    const ProviderScope(
      child: ArchivadorDigitalApp(),
    ),
  );
}

/// Widget raíz de la aplicación Archivador Digital Visual.
class ArchivadorDigitalApp extends StatelessWidget {
  const ArchivadorDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archivador Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
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
