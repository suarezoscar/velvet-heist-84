# FEAT-034 — Museo ampliado

- **Estado**: en curso
- **Diseño**: `docs/gdd/levels/museum_v2.md` §0, `docs/gdd/systems/heist.md` R1, R9-R11 e `interaction.md` R1-R8 (aprobados por el usuario el 2026-10-28, sesión de preguntas)
- **Hito del PoC**: H5
- **Rama**: `feat/034-museo-ampliado`

## Objetivo
Un museo más bonito y más rejugable:
- 20 obras candidatas en un mapa más grande con ala este;
- paredes altas que dejan ver al jugador detrás;
- ventilación para el ladrón;
- garita con puerta;
- rondas de fichaje de una en una, con una ruta distinta para cada guardia.

## Criterios
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | 22 salas (ala este de 6), 36 puertas, 4 salidas, 5 cámaras, 8 relojes, 11 rejillas, 20 candidatas 7/7/6, 4 alas | `test_level_builder.gd::test_museum_v2_data_matches_design` |
| 2 | Muros a 3,2 m con material WallXRay; el recorte sigue al jugador local | `test_walls_full_height_with_xray_material`, `test_dressing_spots_and_xray`, capturas |
| 3 | Cada cuadro existe y tiene créditos CC0; un foco por pieza | `test_paintings_have_images_and_credits`, `test_dressing_spots_and_xray` |
| 4 | Puerta de la garita: guardia al momento, ladrón en `pick_time`, se cierra sola salvo con alguien en el hueco, tapa la vista; la IA la abre | `test_garita_door_opens_closes_and_blocks`, `test_ai_guard_opens_the_door` |
| 5 | Ventilación: entrar, elegir salida, viajar `distancia / travel_speed`, invisible e intocable, rejillas abiertas que cierra un guardia; estado solo al ladrón | `test_vent_travel_hides_the_thief`, `test_vent_state_only_reaches_the_thief` |
| 6 | Rondas: solo cuenta el siguiente reloj, faltas por tramo, tolerancia por guardia, rutas por zonas, tramos por el grafo de salas, IA ficha el suyo, campana y banderola | `test_round_rules.gd` |
| 7 | Plano (M) desde los datos del nivel: el ladrón ve su encargo y las rejillas; los guardias, las candidatas con su protección y rastros, su ruta y el walkie. Contador «CANDIDATAS · RASTROS» en el HUD de los guardias | `test_guards_see_a_counter_and_the_map_has_the_level`, capturas |
| 8 | 17 assets nuevos validados en `pass` con su ficha y licencia | validador, `test_asset_import.gd` |

## Contratos
- Datos de nivel nuevos: `art`, `decor`, `vents`, `replica_tables`, `offline_guards`, `match_minutes`, `clocks[].zone`, `doors[].leaf`, `targets[].size|tint|painting`.
- `DoorRules` (`door_rules.tres`), `VentRules` (`vent_rules.tres`), `TimeClockRules.route_length|leg_walk_factor|leg_margin`.
- `ThiefController3D.in_vent`; `GuardRound` (hijo «Round» de cada guardia); `RoundPlanner` («Rounds»); `VentTravel` («Vents»); `RoomGraph.path/distance`.
- Red: `Door3D` público `{"open"}`; `Vent3D` público `{"open"}`; `VentTravel` privado al ladrón; `GuardRound` privado a los guardias; `TimeClock3D` público `{"expired"}`.

## Riesgos y decisiones abiertas
- Sin navmesh: la IA va de puerta en puerta en línea recta y puede rozar muebles.
- Sorteo de seguridad por partida (salidas, cámaras): sigue en el backlog.
- El plano (M) se rehace aquí, con los datos del nivel (Q20).

## Cierre
