# FEAT-036 — Actualizaciones desde el menú (Velopack)

- **Estado**: en curso
- **Diseño**: `n/a — técnica`
- **Hito del PoC**: H5 (playtests: que todos tengan la misma versión sin bajar nada a mano)
- **Rama**: `feat/036-actualizaciones` (viene del spike `spike/velopack`)

## Objetivo
Con una release casi en cada integración, los jugadores se quedan atrás de versión y en red
hace falta la misma. El juego se instala con Velopack (instalador en Windows, AppImage en
Linux) y desde el menú principal avisa de la versión publicada y se actualiza solo: descarga,
se cierra, se instala y vuelve a abrirse. Solo GitHub Releases; avisa sin obligar. Los .zip y
.tar.gz se siguen publicando y no se actualizan solos.

## Decisiones (grilling del 2026-10-29)
- Velopack en vez de un lanzador propio; plan B, un lanzador en Go si Velopack no sirviera.
- Interfaz en el menú: aviso «HA LLEGADO LA VERSIÓN X», botón «ACTUALIZAR Y REINICIAR» y barra.
- El juego hace la parte de red en GDScript (no hay librería de Velopack para Godot) y usa el
  programa Update de Velopack para montar e instalar.

## Cómo funciona
1. `GameUpdater.check()` (solo si existe Update: instalación de Velopack) lee
   `releases/latest/download/releases.<win|linux>.json`.
2. `UpdatePlan.make()` elige diferencias (todas las versiones intermedias, si pesan menos y
   está en `packages/` el completo de la versión instalada) o el paquete completo.
3. Cada paquete se baja de la release de su versión (`releases/download/vX.Y.Z/…`) y se
   comprueba su SHA256.
4. Con diferencias, `Update patch --old <completo instalado> --delta … --output <completo nuevo>`
   en otro hilo («PREPARANDO…»). En `packages/` queda solo el completo nuevo: la base de la
   siguiente actualización.
5. Un único `Update apply --package <completo> --waitPid <juego>` y el juego se cierra; Update
   instala, llama a los avisos del juego (`--veloapp-*`, el menú cierra en el acto) y lo reabre.

## Criterios
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Elige diferencias o completo según el índice, la base y el peso | `test_game_updater.gd` |
| 2 | Windows: de 0.9.4 a 0.9.6 desde el menú, con diferencias (16 KB en vez de 171 MB) | Wine, 2026-10-29: 18 s, reabre en 0.9.6 |
| 3 | Linux: de 0.9.4 a 0.9.6 con diferencias y con el completo (primer AppImage) | 2026-10-29: 7 s y 3 s, reabre en 0.9.6 |
| 4 | Los avisos de Velopack no abren el juego: cierra en ~2 s | Registro de Velopack (`Hook executed successfully`) |
| 5 | La release publica instalador, AppImage, índices y paquetes, además de .zip y .tar.gz | Release de la rama tras integrar |
| 6 | Una instalación de la release anterior se actualiza a la siguiente desde GitHub | Prueba manual tras la segunda release |

## Contratos
- `GameUpdater` (Node): señales `update_found(version)`, `progress(fraction)`, `preparing`,
  `ready_to_apply`, `failed(reason)`; métodos `check()`, `download()`, `apply()`.
  `VELVET_UPDATE_URL` (entorno) sirve el índice y los paquetes desde otra dirección (pruebas).
- `UpdatePlan.make(feed, current, has_base) -> Array[Dictionary]`, `UpdatePlan.is_newer(a, b)`.
- `UpdateNotice` (PanelContainer) en el menú principal.
- `tools/build/velopack.sh` (VERSION, GITHUB_TOKEN) → `build/velopack/`; `VPK_VERSION` en
  `tools/ci/godot_version.env`.

## Riesgos y decisiones abiertas
- Windows: Update no puede mover `current/` si es su carpeta de trabajo, heredada del juego. Se
  lanza con `cmd /c cd /d <instalación> && Update.exe apply …` en una sola línea sin comillas
  (Godot entrecomilla los argumentos con `&`). Un nombre de usuario con `&` o `^` la rompería.
- Encadenar un `apply` por versión no funciona: cada Update cierra los procesos de la carpeta,
  incluido el otro Update. Por eso se suman las diferencias con `patch`.
- Bajo Wine, `--waitPid` no puede esperar al juego («Acceso denegado») y sigue; en Windows real
  debería esperar. Comprobar en un Windows real.
- Sin firmar: SmartScreen avisa en el instalador.
- La primera release con Velopack no tiene anterior: sin diferencias hasta la segunda.

## Cierre
