# FEAT-033 — Café y sueño 2

- **Estado**: en curso
- **Diseño**: `docs/gdd/systems/heist.md` R3 y R5b (aprobado por el usuario el 2026-10-28: «haz las baratas»)
- **Hito del PoC**: H5
- **Rama**: `feat/033-cafe-sueno-2`

## Objetivo
Las ideas baratas del brainstorming del 2026-10-28 que encajan con el golpe: el ladrón puede jugar con el sueño de los guardias, la alarma tiene un precio y el botín pesa.

## Criterios
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | El ladrón droga la cafetera (E, `drug_time` s, `drug_doses` por partida); el siguiente guardia que termina un café duerme `drug_nap_time` s y despierta agotado; la cafetera queda limpia | `test_coffee_sleep_2.gd::test_drugged_coffee_puts_the_next_guard_to_sleep` |
| 2 | Solo el ladrón recibe el estado de la cafetera (`#private`, audiencia `thief`); el público va vacío | mismo test |
| 3 | La alarma pone el sueño a 0; al apagarse las luces de alarma sube hasta `crash_level` | `test_alarm_wakes_and_flood_end_crashes` |
| 4 | El «Zzz» de una cabezada es público y cuelga de VisualRoot (la niebla lo oculta) | test 1 y captura del ladrón junto a un guardia dormido |
| 5 | El ladrón pierde `loot_slow` de velocidad por pieza, con un tope `loot_min_speed`; los guardias no | `test_loot_slows_the_thief` |

## Contratos
- `GuardSleepRules`: `drug_doses`, `drug_time`, `drug_nap_time`, `crash_level`. `HeistRules`: `loot_slow`, `loot_min_speed`.
- `GuardSleep.start_coffee(machine: CoffeeMachine3D = null)`, `wake_up()`, `crash()`, `drugged: bool`. Estado público `{"zzz": bool}`; privado añade `"drug"`.
- `CoffeeMachine3D`: `drugged`, `doses_left`, `take_cup() -> bool`; estado privado `{"drugged", "doses"}` al ladrón.
- `PlayerBase3D.speed_factor() -> float` (1 por defecto; el ladrón lo sobreescribe).

## Riesgos y decisiones abiertas
- **Descartado al implementar**: las ondas de colores en el suelo. El usuario ya rechazó los anillos de ruido en FEAT-012, y `test_no_noise_rings` lo protege.
- **Al backlog**: sortear salida, cámaras y cuadros por partida. Con 3 cámaras y 3 salidas, quitar una cambia el balance; necesita más posiciones candidatas en el nivel (`/level`).
- El parpadeo negro de las cabezadas ya existía (SleepHud84).

## Cierre
- **Revisión (reviewer)**: un guardia drogado podía cortarse la siesta con otro café. Ahora nadie se sirve café dando una cabezada, y el café normal limpia `drugged`.
- **Aceptado para el PoC**: `zzz` va a todos los peers por el estado público; un cliente modificado sabría qué guardia está dormido aunque no lo vea. La niebla lo oculta en pantalla. Moverlo al snapshot del actor, que ya se filtra por visibilidad, queda en el backlog.
- Durante la siesta drogada, el guardia puede andar a ciegas, igual que en las cabezadas.
