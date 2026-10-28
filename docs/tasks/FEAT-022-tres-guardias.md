# FEAT-022 — Hasta tres guardias en red

- **Estado**: hecha
- **Diseño**: decisión del usuario del 2026-10-28: «quiero poder poner hasta 4 jugadores, 1 ladrón y 3 guardias». Eligió que en red solo haya guardias humanos. Recogido en `museum_v2.md` (aparición G3) e `interaction.md` (casos límite de los relojes).
- **Hito del PoC**: H5
- **Rama**: `feat/022-tres-guardias`

## Objetivo
Jugar con 2, 3 o 4 personas: un ladrón y de 1 a 3 guardias, sin guardias de IA en red.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | El lobby ofrece las plazas GUARDIA 1, 2 y 3. «Empezar partida» exige el ladrón y al menos un guardia | `test_lobby_view.gd` y `test_guard_slots.gd` |
| 2 | Al empezar, los guardias ocupados se renumeran sin huecos (guard_1..guard_n) | `test_guard_slots.gd` y partida con un solo jugador en GUARDIA 3, que pasa a GUARDIA 1 |
| 3 | En red, el mapa deja un guardia por jugador guardia, todos sin IA | `test_guard_slots.gd`, `test_multiplayer_lobby.gd` y partida con 4 clientes |
| 4 | Sin red siguen los dos guardias de IA, uno por patrulla | `test_guard_slots.gd` |
| 5 | `museum_v2` tiene una tercera aparición G3 dentro de la garita | `museum_v2.json` y captura |

## Contratos
- `NetConfig.ROLES`: `thief`, `guard_1`, `guard_2` y `guard_3`.
- `NetRoleRegistry`: `can_start(players)`, `guard_count(players)` y `compact_guards(players)`.
- `HeistMap3D`:
  - `offline_guard_count`, que `museum_v2` fija a su número de patrullas;
  - `guard_slots()`.
- El servidor renumera y sincroniza la lista de jugadores antes del RPC de inicio. Los dos van por el mismo canal fiable, así que los clientes ya tienen su rol definitivo al cargar el mapa.

## Riesgos y decisiones abiertas
- El equilibrio del museo se diseñó para 2 guardias. Con 3, el ladrón lo tiene más difícil y con 1, más fácil. Se ajustará con TUNE tras jugar.
- Si un guardia se desconecta a media partida, su personaje se queda quieto (como antes): no pasa a la IA.

## Cierre
2026-10-28. Verificado en local con un servidor dedicado y 4 clientes (los 3 guardias aparecen en la garita), y con un ladrón y un solo guardia en la plaza 3, que pasa a GUARDIA 1.
