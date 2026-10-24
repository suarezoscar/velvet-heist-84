# FEAT-016 — Relojes de ronda con consecuencia

- **Estado**: hecha
- **Diseño**: `docs/gdd/systems/interaction.md`, parte R (aprobado el 2026-10-24)
- **Hito del PoC**: H3
- **Rama**: `feat/016-relojes-de-ronda`

## Objetivo
Que fichar los relojes importe: faltas en la hoja de ronda, final por tiempo según la ronda, tablilla en el HUD de los guardias y nada de eso filtrado al ladrón. Los monitores CCTV (parte M) van en otra FEAT.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Un reloj vencido v s aporta `1 + floor(v / round_duration)` faltas; fichar no las baja (R2, invariantes 1-2) | `tests/unit/test_round_rules.gd` |
| 2 | El final por tiempo sigue la tabla R4 en sus 4 casillas, con los estados nuevos `TIME_EXPIRED_BREACH` y `TIME_EXPIRED_DRAW` (R3-R4, invariante 3) | `test_round_rules.gd` |
| 3 | Los números salen de `data/balance/time_clock_rules.tres`; el nodo ya no tiene `round_duration` propio | `test_round_rules.gd` |
| 4 | Vencido: campana a `alarm_noise_radius` cada `alarm_pulse_interval` y banderola roja visible para todos (R5) | `test_noise_categories.gd` y captura |
| 5 | Los guardias ven la tablilla R1-R4 con segundos, ámbar a `warning_time`, rojo vencido, «Faltas F / allowed_misses», avisos y pitido de UI; el ladrón no ve nada (R6-R7) | captura y partida |
| 6 | El cliente del ladrón nunca recibe `time_left` ni las faltas; los guardias sí (R8, invariante 4) | `test_round_rules.gd` y partida en red con `--net-log` |
| 7 | La pantalla final muestra a todos las faltas de la hoja | captura |
| 8 | Un guardia de IA ficha los relojes que pasa en su patrulla | `test_round_rules.gd` |

## Contratos
- `TimeClockRules` (`src/systems/time_clock_rules.gd`, `Resource`): `round_duration`, `allowed_misses`, `warning_time`, `punch_noise_radius`, `alarm_noise_radius`, `alarm_pulse_interval`.
- `TimeClock3D`: grupo `time_clock`; `faults: int`, `reset_round()`, `get_net_state()` → `{"expired"}` (público), `get_net_state_private()` → `{"time_left", "faults"}` y `net_private_audience()` → `&"guard"`.
- `RoundRules` (estática): `team_faults(clocks)`, `any_expired(clocks)`, `is_on_time(faults, any_expired, allowed)`.
- `GameManager.MatchState`: añade `TIME_EXPIRED_BREACH` (5) y `TIME_EXPIRED_DRAW` (6) al final; `round_faults: int`, que va en `get_net_state()` solo con la partida terminada.

| Dato | Autoridad | A quién | Frecuencia |
|---|---|---|---|
| `expired` de cada reloj | servidor | todos | al cambiar |
| `time_left`, `faults` de cada reloj | servidor | solo guardias (`#private`) | `WORLD_STATE_HZ` al cambiar |
| `round_faults` | servidor | todos, solo al acabar | con el estado de la partida |

## Riesgos y decisiones abiertas
- El pitido ámbar es un tono generado en código; se cambia por un sonido de verdad si no convence.
- La tablilla se prototipa y se enseña al usuario antes de pulirla.

## Cierre
2026-10-24, PR #61. `reviewer` aprobó sin bloqueantes; se aplicaron sus sugerencias de borde en el tick final, tests de campana, banderola y caja fuerte privada, y redondeo de segundos. Partida en red verificada: el ladrón no recibe segundos ni faltas.
Backlog: las distancias de fichaje de la IA (`CLOCK_PUNCH_*`) a un `.tres` de la IA; un sonido de verdad para el pitido ámbar si no convence; medir en playtest que la vuelta de cada IA dura menos de 90 s (sobre plano: 32 s y 24 s andando).
