# FEAT-004 — Modelado y Pipeline de Gadgets Analógicos de 1984

- **Estado**: hecha parcialmente (auditoría de la Fase 1, 2026-10-22: `docs/decisions/2026-10-22-fase-1-auditoria.md`)
- **Responsable**: technical-artist  **Revisor**: lead-architect
- **Fase del GSD**: 3 (El Maletín y el Cinturón)

## Objetivo
Generar y validar objetivamente mediante el pipeline de Blender headless (FEAT-001) los 5 modelos 3D de gadgets analógicos clave de 1984 especificados en el GSD, listos para ser utilizados por el Ladrón y los Guardias tanto en el mundo de juego como en la UI de equipamiento.

## Alcance y fuera de alcance
- **Dentro**:
  1. Scripts `bpy` idempotentes en `tools/blender_scripts/` usando la paleta unificada `tools/blender_scripts/lib/palette.py`.
  2. Fichas de especificación JSON en `tools/blender_scripts/specs/` (y `data/asset_specs/`) con dimensiones, presupuesto de polígonos, paleta y pivotes.
  3. Cinco modelos `.glb` en `assets/models/`:
     - `alarm_clock.glb`: Despertador mecánico de doble campana y martillo oscilante (`BrassGold`, `BakeliteBlack`, `Steel80s`).
     - `wood_wedge.glb`: Cuña de bloqueo para puertas (`MahoganyWood`).
     - `stethoscope.glb`: Estetoscopio médico de tubo y campana metálica (`BakeliteBlack`, `Steel80s`, `BrassGold`).
     - `inspection_mirror.glb`: Espejo telescópico de inspección para esquinas y puertas (`Steel80s`, `ChromeTrim`).
     - `tripwire_bell.glb`: Campanilla mecánica con soporte y percutor para cable trampa (`BrassGold`, `Steel80s`).
  4. Validación formal por CLI headless con `validate_asset.py` (exigiendo `pass: true` y código de salida 0 en los 5 modelos).
  5. Renders de previsualización isométrica ortográfica (-35.264°, 45°) en `assets/previews/`.
  6. Actualización de la suite de tests unitarios de importación en Godot `tests/unit/test_asset_import.gd`.
- **Fuera**:
  - Lógica GDScript de activación de los gadgets en tiempo de juego (se programa en FEAT-005).

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Módulo de generación `tools/blender_scripts/gen_gadgets_assets.py` escrito con `bpy` e importando `palette.py` | código fuente y ejecución limpia |
| 2 | Fichas JSON creadas para los 5 gadgets con dimensiones exactas de escala 1:1 métrica, pivote inferior centrado y presupuesto de triángulos $\le 1.000$ tris por prop | fichas en `tools/blender_scripts/specs/` |
| 3 | Los 5 archivos `.glb` generados y exportados por CLI headless con `export_yup=True` y `export_apply=True` | existencia y tamaño > 0 en `assets/models/` |
| 4 | Validación estricta con `validate_asset.py` reporta `pass: true` y código de salida 0 para los 5 gadgets | salida JSON de validación |
| 5 | Renders de previsualización isométrica generados con iluminación de 3 puntos en `assets/previews/` | imágenes PNG en `assets/previews/` |
| 6 | Test en Godot `tests/unit/test_asset_import.gd` comprueba que los 5 `.glb` cargan, tienen AABB en $\pm 1\%$ y pivote base en $Y=0$ | `./tools/ci/run_tests.sh` en verde |
| 7 | Todos los 55 tests previos se mantienen en verde (total 56+ tests) | reporte de `./tools/ci/run_tests.sh` |

## Contratos
### Especificaciones de los Assets
| Asset | Dimensiones (X, Y, Z en Blender) | Pivote | Presupuesto Máx | Materiales | Colisión `-col` |
|---|---|---|:---:|---|:---:|
| `alarm_clock` | 0.18 m ancho × 0.12 m fondo × 0.22 m alto | Base inferior central ($Z=0$) | 800 tris | `BrassGold`, `BakeliteBlack`, `Steel80s` | Sí (`alarm_clock-col`) |
| `wood_wedge` | 0.25 m largo × 0.08 m ancho × 0.08 m alto | Base inferior central ($Z=0$) | 300 tris | `MahoganyWood` | Sí (`wood_wedge-col`) |
| `stethoscope` | 0.26 m ancho × 0.32 m largo × 0.05 m alto | Base inferior central ($Z=0$) | 800 tris | `BakeliteBlack`, `Steel80s`, `BrassGold` | No |
| `inspection_mirror` | 0.10 m ancho × 0.38 m largo × 0.04 m alto | Base inferior central ($Z=0$) | 500 tris | `Steel80s`, `ChromeTrim` | No |
| `tripwire_bell` | 0.12 m ancho × 0.14 m fondo × 0.18 m alto | Base inferior central ($Z=0$) | 600 tris | `BrassGold`, `Steel80s` | Sí (`tripwire_bell-col`) |

## Impacto en red
Ninguno (los modelos son estáticos; la red se aborda en la lógica de FEAT-005).

## Reparto y orden
1. `technical-artist`: redacta `gen_gadgets_assets.py`, genera fichas, valida con `validate_asset.py` y renderiza previsualizaciones.
2. `technical-artist`: añade expectativas en `tests/unit/test_asset_import.gd`.
3. `lead-architect`: revisa con `/review`.
