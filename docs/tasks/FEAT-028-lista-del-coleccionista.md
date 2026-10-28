# FEAT-028 — La lista del coleccionista (entrega 1 del golpe)

- **Estado**: hecha
- **Diseño**: `docs/gdd/systems/heist.md` (aprobado el 2026-10-28), entrega 1: R1-R4 y, de R9, la combinación y el robo a lo bruto.
- **Hito del PoC**: rediseño posterior a H4, antes del playtest
- **Rama**: `feat/028-lista-coleccionista`

## Objetivo
Que los guardias no sepan qué defender ni por dónde saldrá el ladrón: un encargo secreto de varias piezas entre 6 candidatas y la salida por cualquier puerta exterior.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Al empezar, el servidor (o la partida sin red) sortea 4, 3 o 2 piezas distintas según haya 1, 2 o 3 guardias | `test_heist.gd` y partida en red con 1 guardia: 4 piezas |
| 2 | Solo el ladrón sabe cuáles son (estado privado). Los guardias saben cuántas, ven la carta y ven las 6 candidatas con marca cian. Al acabar se revela todo | `test_museum_contract_and_who_knows_what` y partida en red (guardia: `targets=[]`, `size=4`) |
| 3 | Protecciones: vitrina y caja fuerte con dial (abiertas, E coge la pieza en silencio); la vitrina se rompe con Q y la caja fuerte no; los pedestales de presión y sensor solo se roban a lo bruto (E o Q) en esta entrega. A lo bruto suena con radio 15 m | `test_steal_each_protection_and_escape` |
| 4 | Fuera del encargo no se puede tocar ninguna pieza; el dial de su candado ni se activa | `test_steal_each_protection_and_escape` |
| 5 | Con el encargo completo, el ladrón gana al cruzar cualquiera de las 3 salidas; sin él, no pasa nada. El coche es decorado | `test_steal_each_protection_and_escape`, `test_exit_without_contract_does_nothing` y prueba con el mapa |
| 6 | Si se acaba el tiempo con la ronda rota, es empate (el ladrón siempre tiene que escapar) | `GameManager.time_expired_state` con encargo |
| 7 | HUD: el ladrón ve «ENCARGO n / N» y la lista con salas; los guardias, «LA CARTA: SE LLEVARÁ N PIEZAS». Tarjeta de objetivo y resumen de fin con el encargo | capturas y `test_guards_see_the_letter_not_the_contract` |

## Contratos
- `HeistRules` (`data/balance/heist_rules.tres`): `pieces_by_guards` y `brute_radius`.
- `HeistDirector`, que registra `GameManager.heist`:
  - `targets`, `contract_size`, `stolen`;
  - `is_in_contract`, `is_complete`, `mark_stolen` y `draw(...)`;
  - estado público `size` y privado (ladrón) `targets` y `stolen`.
- `TargetPiece3D`:
  - `piece_id`, `protection`, `variant` (`pedestal`, `case` o `safe`) y `lock`;
  - `is_available`, `can_interact`, `can_force`, `force` y `steal`.
- `ExitZone3D`, `HeistReach.forceable(thief)` y `HeistBuilder`.
- Datos del nivel: secciones `targets` y `exits`; el museo pierde `loot`, `safe` y el pedestal de la Pieza Maestra.
- `SafeBox3D`: `lock_name`, `breakable`, `contained_target` y `break_open()`.
- Acción `force` (Q), en su propio commit de `project.godot` y en `NetConfig.ACTIONS`.
- Mapas sin `targets` (los antiguos y el nivel de pruebas): siguen con la cuota y la Pieza Maestra.

## Riesgos y decisiones abiertas
- El plano (M) dibuja todavía el museo antiguo: el ladrón se orienta con la lista y las marcas rosas. Rehacer el plano para `museum_v2` va al backlog.
- Las combinaciones son fijas por pieza (están en los datos); sortearlas por partida, más adelante.
- A lo bruto aún no sube la alerta (entrega 3): de momento solo suena.

## Cierre
2026-10-28.
