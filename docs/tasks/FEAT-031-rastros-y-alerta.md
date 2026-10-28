# FEAT-031 — Rastros, nivel de alerta, monedas y walkie (entrega 3 del golpe)

- **Estado**: hecha
- **Diseño**: `docs/gdd/systems/heist.md` R6-R8 (aprobado el 2026-10-28) y sus decisiones 1 (luces de alarma) y 2 (el ladrón ve la alerta)
- **Hito del PoC**: rediseño contra la acampada, antes del playtest
- **Rama**: `feat/031-rastros-alerta`

## Objetivo
Que patrullar dé información y la partida vaya escalando: los guardias descubren lo robado, la alerta sube hasta la caza, y cada bando tiene una herramienta con su contrajuego.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Un pedestal vacío queda descubierto si lo ve un guardia (a 10 m o menos, sin muros y sin estar en una cabezada) o una cámara mientras alguien mira los monitores. Su marca pasa de ◆ cian a ✘ roja para los guardias, y en su HUD aparece «DESCUBIERTAS n» | `test_silent_theft_is_found_by_a_guard_and_raises_suspicion` y captura |
| 2 | Alerta calma → sospecha (1 rastro) → alarma (2 rastros, un guardia o una cámara vigilada ve al ladrón, o se roba a lo bruto). Nunca baja y la ven los dos bandos | `test_brute_theft_or_sighting_means_alarm_and_it_never_drops`, `test_guard_seeing_thief_raises_alarm` y partida en red (nivel replicado) |
| 3 | Ladrón: 3 monedas con clic derecho, que caen a 10 m como mucho (contra el muro si lo hay) y hacen un ruido de 9 m como del ladrón | `test_coins_make_thief_noise_where_they_land` y partida en red (al ladrón le quedan 2, estado privado) |
| 4 | Guardias: con el walkie (T) marcan un punto en el plano del equipo durante 8 s. El chasquido (6 m) delata a quien habla. Hay que esperar 10 s entre usos y las marcas solo llegan a los guardias | `test_walkie_pings_team_and_clicks` y partida en red (guardia `pings=1`, ladrón 0) |
| 5 | Guardias en alarma: con las luces de alarma (Q) encienden las lámparas a 14 m durante 30 s; después vuelven a como estaban. El equipo espera 60 s entre usos | `test_alarm_lights_only_in_alarm_and_restore` |
| 6 | En alarma el sueño deja de subir | `GuardSleep.step` y código |

## Contratos
- `AlertDirector` (hijo «Alert» del `HeistDirector`): `level`, `scan()`, `raise(level)`, `discovered_count()`, `add_ping(pos)` y `flood(pos)`.
  - Estado público: `level`.
  - Estado privado de `guard`: las marcas del walkie y la espera de las luces.
- `HeistActions.handle(actor, action)` para `throw_coin`, `walkie` y `alarm_lights`:
  - con red, lo llama `NetSessionServer.on_action`;
  - sin red, lo llama `HeistInput`.
- `TargetPiece3D.discovered` (público), `HeistDirector.coins_left` (privado del ladrón) y `SecurityCamera3D.sees(target)`.
- `HeistRules`: `trace_sight`, `alarm_traces`, `flood_*`, `coins`, `throw_range`, `coin_radius`, `ping_time`, `walkie_radius` y `walkie_cooldown`.
- Acciones `throw_coin` (clic derecho), `walkie` (T) y `alarm_lights` (Q), en su propio commit de `project.godot`.
- `AlertHud84`: nivel de alerta, monedas, walkie y luces de alarma.

## Riesgos y decisiones abiertas
- La moneda usa de momento el sonido de «mecanismo» (un clic metálico). Con un sonido de moneda CC0 quedaría mejor.
- Las luces de alarma usan un radio de 14 m alrededor del guardia, no un «ala» del plano: el nivel no define alas.
- Los guardias de la IA (sin red) no usan el walkie ni las luces.

## Cierre
2026-10-28.
