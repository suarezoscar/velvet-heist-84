# Velvet Heist '84 — Framework de Pruebas Unitarias (GUT)

Este directorio contiene la suite de pruebas unitarias y de caracterización del proyecto, basada en **GUT (Godot Unit Test)** versión 9.6.1, compatible con **Godot 4.7+**.

## Estructura de Directorios

```text
tests/
├── README.md                           # Esta documentación
└── unit/                               # Tests unitarios y de caracterización
    ├── test_surface_detector_noise.gd  # Criterio 3: Acústica y multiplicadores de superficie
    ├── test_thief_visibility.gd        # Criterio 4: Visibilidad y cono de detección
    ├── test_loot_weight.gd             # Criterio 5: Penalización de botín pesado
    ├── test_guard_capture.gd           # Criterio 6: Mecánica de captura por porra
    └── test_time_clock.gd              # Criterio 7: Reloj mecánico de ronda (90s)
```

## Configuración

El framework se configura mediante `.gutconfig.json` en la raíz del proyecto:
- Directorios de búsqueda: `res://tests/`, `res://tests/unit/`
- Búsqueda recursiva: `include_subdirs: true`
- Salida automática en headless tras finalizar la ejecución.

## Comandos de Ejecución

### 1. Vía script de CI (Recomendado)
```bash
./tools/ci/run_tests.sh
```

### 2. Vía CLI de Godot directamente
```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```

### 3. Ejecutar un único script de test
```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gselect=res://tests/unit/test_surface_detector_noise.gd -gexit
```

### 4. Filtrar por nombre de test
```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -gunit_test_name=test_carpet -gexit
```

## Convenciones de Código para Tests
- Todos los scripts de test heredan de `GutTest`.
- Tipado estático completo en variables, parámetros y tipos de retorno (`-> void`).
- Comentarios y docstrings en español utilizando prefijo `##`.
- Gestión de memoria limpia: utilizar `autofree()` o `add_child_autofree()` para evitar fugas de `Node` en el árbol de escena.
