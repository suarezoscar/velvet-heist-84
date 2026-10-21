# FEAT-000 — Línea base de verificación

- **Estado**: hecha (revisada y aprobada por lead-architect con GUT)
- **Responsable**: gameplay-engineer  **Revisor**: lead-architect
- **Fase del GSD**: transversal (antes de la Fase 3)
- **Decisión del framework**: GUT (aprobado por el usuario el 2026-10-21)

## Objetivo
Crear la red de seguridad que permite a los agentes cambiar el proyecto sin romper lo que ya funciona: comandos de verificación, tests de caracterización y CI.

## Alcance y fuera de alcance
- Dentro: elegir el framework de tests (GdUnit4 o GUT) y documentarlo; carpeta `tests/`; scripts en `tools/ci/`; tests de caracterización de lo existente; lint; CI.
- Fuera: cambiar comportamiento del juego. No se modifican scripts ni escenas existentes, salvo extraer constantes imprescindibles para poder testear (cada cambio queda anotado en esta FEAT).

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Framework de tests elegido, instalado y documentado en `tests/README.md` | archivo y ejecución de un test de ejemplo en headless |
| 2 | `tools/ci/` con scripts de importación, parseo de scripts y ejecución de tests, que fallan con código distinto de 0 | salida de los tres comandos |
| 3 | Test de ruido por superficie: `noise_multiplier` 0.2 (alfombra), 1.5 (parqué) y 1.2 (mármol) | test en verde |
| 4 | Test de visibilidad del ladrón: detección por proximidad (1.8 m sin paredes) y por `SpotLight3D` con `RayCast3D` | test en verde |
| 5 | Test de botín pesado: velocidad ×0.8 y bloqueo de gadgets mientras se carga | test en verde |
| 6 | Test de captura: dos impactos de porra a 1.5 m atrapan al ladrón | test en verde |
| 7 | Test del reloj de fichar: ciclo de ronda de 90 s | test en verde |
| 8 | `gdlint` y `gdformat --check` configurados (no bloqueantes al inicio) | salida de ambos |
| 9 | Workflow de CI (GitHub Actions) que ejecuta importación, parseo y tests en cada PR con la versión de Godot fijada | ejecución en verde del workflow |

## Contratos
Los scripts de `tools/ci/` se ejecutan desde la raíz del proyecto y devuelven 0 solo si todo pasa. Los valores de los tests salen del GSD (secciones 3 y 4).

## Impacto en red
Ninguno.

## Reparto y orden
1. gameplay-engineer: criterios 1, 2, 8 y 9.
2. gameplay-engineer: criterios 3 a 7.
3. lead-architect: revisión y actualización de `AGENTS.md` con los comandos reales.

## Riesgos y decisiones abiertas
- ¿GdUnit4 o GUT?: Decidido: GUT aprobado por el usuario. CLI headless: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`.
- Algunos sistemas pueden depender del árbol de escena y no ser testeables sin cambios; si ocurre, se documenta aquí en lugar de refactorizar.

## Constantes extraídas y adaptaciones mínimas para testeo
- `SurfaceDetector3D`: Extraídas constantes `CARPET_NOISE_MULTIPLIER = 0.2`, `WOOD_PARQUET_NOISE_MULTIPLIER = 1.5`, `MARBLE_NOISE_MULTIPLIER = 1.2` según GSD 4.1. Creados recursos de balance en `data/balance/surface_*.tres` y clase `SurfaceAcousticData`.
- `ThiefController3D`: Extraídas constantes `HEAVY_LOOT_SPEED_MULTIPLIER = 0.8` (GSD 4.3) y `REQUIRED_HITS_TO_CAPTURE = 2` (GSD 1.0). Añadidos métodos de consulta `can_use_gadgets() -> bool`, `register_baton_hit() -> bool` y `reset_baton_hits() -> void`.
- `GuardController3D`: Extraída constante `BATON_COOLDOWN_TIME = 0.75`. En `swing_baton()`, delega el conteo de impactos en `register_baton_hit()` para requerir los 2 impactos de porra especificados en el GSD. Control de colinealidad con `Vector3.UP` en orientación de linterna.
- `TimeClock3D`: Extraída constante `DEFAULT_ROUND_DURATION = 90.0` (GSD 3.0).
