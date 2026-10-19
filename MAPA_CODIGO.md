# Mapa de Arquitectura y Código — Simplista (Archivador Digital)

Este documento describe la arquitectura, capas, proveedores de estado, configuraciones nativas y flujos de E/S del proyecto para servir como referencia completa sin necesidad de releer todo el código fuente.

---

## 1. Estructura de Directorios (`lib/`, `android/`, `assets/`)

```text
archivador_digital/
├── android/app/src/main/
│   ├── AndroidManifest.xml                  # Permisos de Cámara, Almacenamiento, SYSTEM_ALERT_WINDOW y FOREGROUND_SERVICE
│   └── kotlin/com/example/archivador_digital/
│       ├── MainActivity.kt                  # MethodChannel 'simplista/overlay' e intents de acciones rápidas
│       └── XiaomiOverlayService.kt          # Servicio nativo ligero en 2do plano para barra flotante sobre otras apps
├── assets/icon/
│   └── app_icon.png                         # Icono maestro generado desde web/icons/SimplistaIcon
├── web/icons/
│   ├── SimplistaIcon.jfif                   # Icono original proporcionado por el usuario
│   └── SimplistaIcon.png                    # Versión PNG para launcher icons
└── lib/
    ├── core/database/
    │   └── app_database.dart                # Inicialización SQLite (tablas: categorias, fichas, etiquetas, relaciones)
    ├── models/
    │   ├── bloque_contenido.dart            # BloqueContenido (nota, imagen, formula, fecha) + serialización JSON embebida
    │   ├── categoria.dart                   # Modelo Categoria (id, nombre, colorHex, orden, rutaImagenFondo)
    │   ├── etiqueta.dart                    # Modelo Etiqueta (id, nombre)
    │   └── ficha.dart                       # Modelo Ficha + getter descripcionLimpia
    ├── providers/                           # Capa de Estado (Riverpod Notifier / AsyncNotifier)
    │   ├── ajustes_provider.dart            # Estado persistente (SharedPreferences): barras Xiaomi, Google Account, frecuencia backup, vistas Notion
    │   ├── categorias_provider.dart         # CRUD reactivo y reordenamiento de categorías
    │   ├── database_provider.dart           # Inyección de repositorios (CategoriaRepository, FichaRepository, EtiquetaRepository)
    │   ├── etiquetas_provider.dart          # Lista global de etiquetas
    │   └── fichas_provider.dart             # Lista de fichas filtradas, búsqueda por texto/etiquetas y fichasRecientesProvider
    ├── repositories/                        # Capa de Acceso a Datos SQLite
    │   ├── categoria_repository.dart        # CRUD categorías, categoría 'Errante' y ordenamiento batch
    │   ├── etiqueta_repository.dart         # CRUD etiquetas y asociación por ficha
    │   └── ficha_repository.dart            # Consultas optimizadas con GROUP_CONCAT (sin N+1) y restaurarFicha (ConflictAlgorithm.replace)
    ├── services/                            # Servicios de Plataforma y Archivos
    │   ├── overlay_service.dart             # Puente MethodChannel ('simplista/overlay') hacia XiaomiOverlayService.kt
    │   └── storage_service.dart             # Copia y limpieza de imágenes en el almacenamiento interno de la app
    ├── ui/
    │   ├── screens/
    │   │   ├── ajustes_screen.dart          # Conexión Google Account, switches de barra Xiaomi (2do plano, editor, inicio) y vista Notion default
    │   │   ├── backup_screen.dart           # Selector de "Frecuencia de Respaldo" y Exportar/Importar copia JSON local/portapapeles
    │   │   ├── categorias_screen.dart       # Gestión, fondos y ReorderableListView de categorías
    │   │   ├── detalle_editor_screen.dart   # Diario de Campo / Bitácora: portada, notas, imágenes, fechas y fórmulas (modo vista/edición al tocar)
    │   │   ├── inicio_screen.dart           # Pantalla principal: buscador, recientes, carrusel de categorías y escucha de atajos de 2do plano
    │   │   └── lista_fichas_screen.dart     # Vistas estilo Notion (Galería, Lista, Tabla) y ordenamiento (reciente, A-Z, antiguo)
    │   └── widgets/
    │       ├── barra_lateral_xiaomi.dart    # Pestaña lateral deslizable in-app (Fórmula, Imagen, Nota, Fecha)
    │       ├── categoria_card.dart          # Tarjeta cuadrada de categoría con imagen de fondo o color
    │       ├── etiqueta_chip.dart           # Chip visual de etiqueta
    │       ├── ficha_card.dart              # FichaCard (con imagen de fondo) y FichaDetalleCard
    │       ├── recorte_imagen_modal.dart    # Recorte real de píxeles con RepaintBoundary.toImage (1:1, 2:1, 3:1 Fórmula, 3:4)
    │       ├── renderizador_formula_matematica.dart # Renderizador tipo Word (fracciones apiladas, raíces, sumatorias, matrices e imágenes sin recortar)
    │       └── visor_imagen_completa_modal.dart     # Visor fullscreen con InteractiveViewer (pinch-to-zoom hasta 6x)
    └── main.dart                            # Inicialización de SQLite FFI (escritorio/web) y ProviderScope
```

---

## 2. Flujos Críticos de Entrada/Salida y Nativo

1. **Recorte Real de Imágenes (`recorte_imagen_modal.dart`)**:
   - Captura el encuadre exacto elegido por el usuario mediante `RepaintBoundary` -> `boundary.toImage(pixelRatio: 2.5)` y guarda un archivo `.png` físico en el directorio temporal antes de pasarlo a `StorageService`.
2. **Bloques de Fórmula (`detalle_editor_screen.dart` + `renderizador_formula_matematica.dart`)**:
   - **Prioridad al contenido**: Por defecto se muestra únicamente la ecuación renderizada o la imagen enmarcada (`_bloqueFormulaEnEdicionId == null`). Al tocar el bloque, se despliegan el `TextFormField` y `TecladoSimbolosIngenieria`.
   - **Imágenes de Fórmula (`[[IMG_FORMULA]]:`)**: Se recortan con proporción `3:1` al seleccionarse y se visualizan con `BoxFit.contain` a ancho completo sin recortar bordes.
3. **Barra Rápida en Segundo Plano (`XiaomiOverlayService.kt` + `overlay_service.dart`)**:
   - Usa `SYSTEM_ALERT_WINDOW` y un servicio `foregroundServiceType="specialUse"` ultra ligero en Kotlin nativo (0% consumo de CPU cuando está en reposo).
   - Viene **desactivada por defecto** en `ajustes_provider.dart`.
4. **Cuenta vs Backup (`ajustes_screen.dart` vs `backup_screen.dart`)**:
   - **Cuenta y Ajustes**: Gestiona la vinculación con la cuenta de Google (`googleConectado`, `correoGoogle`).
   - **Backup**: Gestiona la **Frecuencia de Respaldo** y la **Exportación / Importación local**, usando `fichaRepo.restaurarFicha` con `ConflictAlgorithm.replace` para que la importación en móvil nunca falle por IDs existentes.
