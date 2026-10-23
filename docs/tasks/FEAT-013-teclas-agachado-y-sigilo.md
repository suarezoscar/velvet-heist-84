# FEAT-013 — Ctrl agacha, C es sigilo

- **Estado**: hecha (2026-10-23; decisión 1A del usuario tras probar el juego)
- **Diseño**: `n/a — técnica` (solo cambia qué tecla dispara cada acción; las reglas de `stealth.md` no cambian)
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`

## Objetivo
Al probar el juego, el usuario esperaba agacharse con Ctrl. Hoy Ctrl es sigilo (mantenido), y la animación de sigilo parece agachada aunque no lo es para los guardias. Agacharse está en C. Se intercambian las teclas.

## Alcance y fuera de alcance
- Dentro: `project.godot`. `crouch` pasa a Ctrl (pulsar para alternar, como hoy) y `sneak` pasa a C (mantener, como hoy).
- Fuera:
  - la lógica de `LocalInput3D` y `PlayerBase3D`, que no cambia;
  - la animación de sigilo;
  - el indicador del HUD.

## Criterios de aceptación
| # | Criterio | Evidencia |
|---|---|---|
| 1 | `InputMap` tiene un único evento en `crouch`: `InputEventKey` con `keycode == KEY_CTRL` (4194326) | Comprobación del revisor en Godot headless |
| 2 | `InputMap` tiene un único evento en `sneak`: `InputEventKey` con `keycode == KEY_C` (67) | Ídem |
| 3 | Ninguna otra acción usa Ctrl ni C | `grep` de `4194326` y de `"keycode":67` en `project.godot`: una aparición de cada uno |
| 4 | Los tests siguen en verde | `./tools/ci/run_tests.sh` |

## Contratos
Sin código. Solo se intercambian los valores de `keycode` (y `unicode`) de los eventos `crouch` y `sneak`:
- `crouch`: `"keycode":4194326`, `"unicode":0`;
- `sneak`: `"keycode":67`, `"unicode":99`.

El resto de cada objeto `InputEventKey` queda igual.

## Impacto en red
Ninguno.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | integrator | `feat/013-pkg1` | — | integrado | 0 | PR #34 |

## Paquetes de ejecución

### PKG-1 — Intercambio de teclas
- **Agente / rama**: `integrator` / `feat/013-pkg1`
- **Archivos permitidos**:
  ```allowed
  project.godot
  ```
- **Cambio**: el del contrato. Nada más en `project.godot`.
- **Tests**: no hay tests nuevos; el revisor comprueba los criterios 1 a 3 en Godot headless.
- **Comandos de cierre**: `./tools/ci/import.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh`.

## Cierre (2026-10-23)
- PR #34 integrado con CI verde. El revisor comprobó los criterios 1-3 en Godot headless (Ctrl dispara solo `crouch` y C solo `sneak`) y `run_tests` 98/98.
- Aviso para el futuro: no añadir coincidencia exacta (`exact_match`) a `crouch`, porque Ctrl llega con el modificador Ctrl activo.
