# FEAT-001 — Validador de assets y paleta compartida

- **Estado**: hecha (revisada y aprobada por lead-architect)
- **Responsable**: technical-artist  **Revisor**: lead-architect
- **Fase del GSD**: transversal

## Objetivo
Que "el asset está bien" sea una comprobación objetiva y reproducible, no una opinión del agente. Hace ejecutable la regla de inmutabilidad de assets en Godot.

## Alcance y fuera de alcance
- Dentro: módulo de paleta compartido; script de validación en Blender headless; test en Godot; revisar los assets ya generados.
- Fuera: crear assets nuevos.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | `tools/blender_scripts/lib/palette.py` es la única fuente de los 6 materiales de la regla 02 y los scripts existentes lo usan | diff y ejecución de los scripts |
| 2 | `tools/blender_scripts/validate_asset.py` se ejecuta con `blender -b <archivo> -P ... -- <ficha>` y escribe un JSON con cada comprobación y un campo `pass` global | JSON de ejemplo |
| 3 | Comprueba: dimensiones dentro de ±1 % de la ficha, origen en la base central, escala y rotación aplicadas, materiales dentro de la paleta, sin nodos procedurales, malla `-col` si procede, nombres válidos, triángulos ≤ presupuesto | JSON con una prueba que falla a propósito por cada comprobación |
| 4 | Termina con código distinto de 0 si algo falla | ejecución sobre un asset roto |
| 5 | Se ejecuta sobre los assets existentes (`floor_*`, `wall_mahogany`, `thief_pawn`, `guard_pawn`, `safe_box_84`, `rotary_phone_84`) y se corrigen en Blender los que fallen | informe con antes y después |
| 6 | Test en Godot que carga cada `.glb`, instancia la escena y comprueba AABB (±1 %) y origen | test en verde |
| 7 | La skill `/asset` pasa a usar el validador en lugar de la lista manual | diff de `.agents/skills/asset/SKILL.md` (lo aplica lead-architect) |

## Contratos
Entrada: archivo `.blend` o `.glb` y ficha del asset (JSON con nombre, dimensiones, triángulos máximos, materiales, colisión). Salida: JSON `{ "asset": str, "checks": [ { "name": str, "pass": bool, "detail": str } ], "pass": bool }`.

## Impacto en red
Ninguno.

## Reparto y orden
technical-artist hace todo; el criterio 6 se coordina con gameplay-engineer (carpeta `tests/`).

## Riesgos y decisiones abiertas
- Hay que probarlo con Blender real y la versión instalada; fijar la versión en `tools/ci/`.
- El presupuesto de triángulos por tipo de asset lo decide el usuario.
