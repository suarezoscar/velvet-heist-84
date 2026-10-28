# FEAT-023 — Versiones y releases en GitHub

- **Estado**: hecha
- **Diseño**: `n/a — técnica`. Lo pidió el usuario el 2026-10-28: «pipelines de GitHub Actions que puedan compilar y lanzar release del juego para Linux y Windows, para que se puedan descargar las últimas versiones desde GitHub; versiona el juego también».
- **Hito del PoC**: H5 (prueba por internet)
- **Rama**: `feat/023-releases`

## Objetivo
Que cualquiera descargue la última versión del juego desde GitHub sin compilar, y que todos sepan qué versión tienen.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | El juego tiene versión (`application/config/version`, base `0.1.0`). Se ve en el menú, en el panel F9, en la consola del servidor y en el `LEEME.txt` | `test_main_menu.gd` y servidor exportado (`… puerto 7891 (v0.1.0-dev+91666af)`) |
| 2 | `tools/build/export.sh` pone la versión en el nombre de los paquetes. Usa `VERSION`, la etiqueta exacta o `<base>-dev+<commit>`, y deja `project.godot` como estaba | exportación local |
| 3 | Con cada integración en `master` que no sea solo documentación (versión de `tools/build/next_version.sh`: el último número sube solo y `config/version` da los saltos), al subir una etiqueta `vX.Y.Z` o con «Run workflow», la pipeline `Release` pasa los tests, exporta Linux y Windows y publica la release con los dos paquetes. Una versión con guion sale como *pre-release* | primera release `v0.1.0` |
| 4 | El manual explica cómo descargar (`/releases/latest`) y cómo publicar | `docs/manual-compilacion.md` |

## Contratos
- `GameVersion.current()` (`src/systems/game_version.gd`).
- `tools/build/version.sh` y `tools/build/next_version.sh`.
- `.github/workflows/release.yml`.

## Riesgos y decisiones abiertas
- Los ejecutables no están firmados: Windows SmartScreen avisa al abrirlos.
- No se comprueba que el cliente y el servidor tengan la misma versión al conectar; va al backlog.

## Cierre
2026-10-28. PR #73 y, a petición del usuario, la release automática en cada integración en master (`feat/023b-auto-release`).
