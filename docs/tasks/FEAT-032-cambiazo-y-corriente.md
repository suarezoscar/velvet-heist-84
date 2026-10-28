# FEAT-032 — El cambiazo y el corte de corriente (entrega 4 del golpe)

- **Estado**: hecha
- **Diseño**: `docs/gdd/systems/heist.md` R9 (aprobado el 2026-10-28), con la idea del usuario de que las piezas de pega no sean iguales al original y sea el guardia quien tenga que verlo
- **Hito del PoC**: rediseño contra la acampada, antes del playtest
- **Rama**: `feat/032-cambiazo-corriente`

## Objetivo
Dar al ladrón formas elegantes de robar las piezas de presión y de sensor sin hacer saltar la alarma. Cada una tiene su contrajuego para los guardias.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | El ladrón coge una pieza de pega en la mesa de réplicas del taller (solo una cada vez) | `test_swap_leaves_a_fake_that_must_be_inspected` |
| 2 | En un pedestal de presión de su encargo, E da el cambiazo en 2 s en silencio; si se aleja, se cancela. La copia queda con un fallo sorteado (color, tamaño o pose) y no es un rastro | el mismo test y el script en el museo (`flaw=2`, en calma) |
| 3 | Un guardia examina una pieza (E, 2 s): si es de pega, rastro descubierto («✘»); si es auténtica, queda marcada «✔» | `test_swap_leaves_a_fake…` y `test_inspecting_an_authentic_piece_marks_it` |
| 4 | En el cuadro eléctrico de un ala, el ladrón corta la alarma (E, 3 s): las piezas de sensor de esa ala se cogen en silencio y sus lámparas se apagan. Un guardia la restablece (E, 3 s) y las lámparas vuelven a como estaban | `test_power_cut_silences_sensor_pieces_and_pilot_tells_guards` |
| 5 | El panel de pilotos de la garita marca el ala sin corriente. Un guardia a 4 m del panel o dentro del ala se entera, y el corte cuenta como rastro (aunque luego se restablezca) | el mismo test y el script (`noticed=true`, alerta sube) |
| 6 | La lista del encargo dice cómo robar cada pieza en silencio | `ContractList84.hint` |

## Contratos
- `TargetPiece3D`: `flaw`, `is_faked()`, `inspected`, `can_inspect()` y `power_box`. El aspecto pasa a `TargetPieceLook` (`build`, `apply_flaw` y `update_marker`).
- `TimedTask` para las acciones que tardan.
- `PowerBox3D` (sección `wings` del nivel), `ReplicaTable3D` (`replica_table`) y `PilotPanel3D` (`pilot_panel`).
- `HeistDirector.carrying_fake`: estado privado del ladrón.
- `AlertDirector`: las piezas de pega no son rastro; los cortes vistos cuentan en `discovered_count()`.
- `HeistRules`: `swap_time`, `inspect_time`, `cut_time`, `restore_time`, `task_leash` y `pilot_sight`.
- Museo: ala oeste (galerías, circuitos 6 y 7) y ala de servicio (taller y mantenimiento, 11 y 12).

## Riesgos y decisiones abiertas
- El fallo de la copia viaja en el estado público de la pieza, porque todos tienen que verlo. Un cliente modificado podría saber qué piezas son de pega sin mirarlas. Se acepta en el PoC, como el estado vacío u ocupado del pedestal.
- Los guardias aparecen a unos 3 m del panel de pilotos: mientras estén en la garita ven los cortes al momento. Es lo que pide el diseño, pero conviene tenerlo en cuenta en el playtest.

## Cierre
2026-10-28.
