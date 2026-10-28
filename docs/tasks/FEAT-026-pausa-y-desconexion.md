# FEAT-026 — Menú de pausa y vuelta al menú si se cae el servidor

- **Estado**: hecha
- **Diseño**: `n/a — flujo e interfaz`. El usuario eligió hacer las dos juntas el 2026-10-28.
- **Hito del PoC**: H5
- **Rama**: `feat/026-pausa-y-desconexion`

## Objetivo
Poder salir de una partida y consultar los controles sin cerrar el juego, y no quedarse colgado en el mapa si el servidor se cae.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Esc abre y cierra el menú de pausa (Continuar, Controles, Menú principal). Sin red pausa el juego; con red la partida sigue y el personaje propio se queda quieto (no se mueve ni actúa, tampoco con el clic) | `test_pause_menu.gd` y script con el mapa (`paused=true` y cierre con Esc) |
| 2 | No se abre con la partida terminada ni con el dial de la caja fuerte abierto (allí Esc suelta el dial) | `test_pause_menu.gd` |
| 3 | «Menú principal» pide una segunda pulsación y sale de la red | `test_pause_menu.gd` |
| 4 | Si se cae el servidor a media partida, el jugador vuelve al lobby con el aviso «Se perdió la conexión con el servidor durante la partida.» | prueba en red: servidor cerrado de golpe y cliente en el lobby con el aviso |
| 5 | ENet da por perdida una conexión muda en unos segundos, no en ~30 | prueba en red: detectado en 4 s |

## Contratos
- `PauseMenu84` (lo crea `HeistMap3D` en los clientes) y `LocalInput3D.blocked`.
- `MenuReturn.to_main_menu(tree, message)`, con `notice` y `take_notice()`. `MatchEndMenu84` lo usa también.
- `LobbyView.show_notice(text)`.
- `NetStats`: plazo de ENet `set_timeout(32, 3000, 8000)` en los dos extremos.

## Riesgos y decisiones abiertas
- Con red, pausar no detiene a nadie más: tu personaje se queda quieto y expuesto.
- Una conexión que deja de responder se da por perdida en unos 5 s en LAN, y hasta 8 s por internet. Un congelón de más de unos 5 s (carga lenta del mapa, el depurador) expulsa al jugador. Si se ven expulsiones al empezar la partida, se suben `TIMEOUT_MIN_MS` o `TIMEOUT_LIMIT` en `net_stats.gd`.
- Si la partida acaba con la pausa abierta (con red), la pausa se cierra sola para dejar paso al menú de fin.

## Cierre
2026-10-28.
