# FEAT-024 — Revancha sin reiniciar, controles y tecla del panel de red

- **Estado**: hecha
- **Diseño**: `n/a — flujo e interfaz`. Lo pidió el usuario el 2026-10-28: «sigue con la revancha, integra también un menú de opciones para ver las teclas, y asigna una tecla para hacer toggle de la nueva UI con los datos de red».
- **Hito del PoC**: H5
- **Rama**: `feat/024-revancha-controles`

## Objetivo
Encadenar partidas sin cerrar el juego (la meta del PoC son 5 partidas seguidas), que cualquiera pueda consultar las teclas y que el panel de red tenga su propia acción.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Al acabar la partida, el panel de fin muestra «Revancha [R]» y «Menú principal [Esc]» | `test_rematch_controls.gd` y captura |
| 2 | Sin red, la revancha recarga el mapa y empieza una partida nueva | script: `reloaded=true`, `state=1` (en curso) |
| 3 | En red, cada jugador con bando vota (o retira el voto) y se ve «Revancha: n de m listos». Cuando han votado todos y hay ladrón y al menos un guardia, el servidor relanza el mapa para todos con los mismos bandos. Sin ladrón o sin guardia, no hay revancha | `test_rematch_controls.gd` y partida en red con montaje `capture` (captura, votos de los 2 clientes y 2 «Partida iniciada» sin errores) |
| 4 | «Menú principal» sale de la red, si la hay, y vuelve al menú | código y prueba manual |
| 5 | Opciones → «Ver controles» muestra las teclas de todos, del ladrón, de los guardias y del fin de partida, leídas del InputMap | `test_rematch_controls.gd` y captura |
| 6 | El panel de red tiene la acción `toggle_perf_overlay` (F9), que aparece en los controles | `test_rematch_controls.gd` |

## Contratos
- Acciones `toggle_perf_overlay` (F9) y `rematch` (R) en `project.godot`, en su propio commit.
- `NetRematch` (hija de `NetSession` con el nombre «Rematch»):
  - `vote(on)`, `register_vote(peer, on)` y `players_needed(players)`;
  - señal `votes_changed(votes, needed)`.
- RPC: `_server_vote(on)` (cualquier peer → servidor, fiable) y `_client_votes(voters, needed)` (servidor → todos, fiable).
- `MatchEndMenu84`, `ControlsCatalog` y `ControlsPanel`.
- `NetSession` ignora las RPC que llegan mientras se recarga el mapa.

## Riesgos y decisiones abiertas
- La revancha mantiene los bandos. Para cambiarlos: «Menú principal», volver a unirse y elegir.
- Dentro de la partida no hay menú de pausa: los controles se consultan desde el menú principal.

## Cierre
2026-10-28.
