# FEAT-038 — La moneda se ve y se apunta

- **Estado**: en curso
- **Diseño**: `docs/gdd/systems/heist.md` R8, actualizado con lo aprobado por el usuario el 2026-10-29 (grilling)
- **Hito del PoC**: H5 (playtest: que las herramientas se entiendan)
- **Rama**: `feat/038-moneda`

## Objetivo
Tras jugar, el usuario vio dos fallos del ladrón: la tarjeta de inicio decía «El encargo del
coleccionista (0 piezas): ….» y la moneda no se veía ni se podía decidir dónde caía.

## Decisiones (grilling del 2026-10-29)
1. Se apunta manteniendo el clic derecho (arco y aro de caída); al soltar se lanza.
2. Se ve la moneda volar en arco y un destello al caer.
3. Suena al caer, no al lanzar.
4. La mira solo la ve el ladrón; la moneda en vuelo, quien la tenga en su zona visible.
5. Pasa por encima de los muebles bajos y por los vanos; se para contra muros y puertas.
6. Brilla unos segundos en el suelo y desaparece (dejarla como pista iría por `/design`).
7. El clic izquierdo cancela el lanzamiento sin gastar la moneda.
8. La mira muestra, tenue y discontinuo, hasta dónde se oirá.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | La tarjeta del ladrón dice el número real de piezas y sus nombres | `test_heist.gd` (`test_briefing_shows_the_drawn_contract`), captura |
| 2 | Mantener apunta, soltar lanza, el clic izquierdo cancela, un clic rápido lanza | `test_coin_throw.gd` |
| 3 | Alcance, arco y tiempo de vuelo | `test_coin_throw.gd` |
| 4 | El ruido llega al caer, una vez por moneda | `test_alert.gd` |
| 5 | La moneda se ve volar y brillar; la mira dibuja arco, aro y radio de oído | Capturas del 2026-10-29 |
| 6 | Con red, la moneda en vuelo solo llega a quien la ve | `NetSessionServer._on_coin_thrown` con `CoinFlightPresenter.visible_to`; revisión |

## Contratos
- `SignalBus.coin_thrown(from, landing, flight_time)` (commit propio): la emite quien tiene la autoridad.
- `CoinThrow` (reglas puras): `origin`, `landing`, `flight_time`, `arc_point`.
- `CoinTrigger.poll()` / `step(pressed, released, cancel)` y `aiming`.
- `CoinFlightPresenter.visible_to(actor, from, landing)`; `VisionLogic.sees_point(actor, point)`.
- RPC `NetSession._client_coin(from, landing, flight_time)` (servidor → cliente, no fiable).
- `heist_rules.tres`: `coin_flight_time` (0,5 s) y `coin_glint_time` (3 s).

## Riesgos y decisiones abiertas
- Con red, el servidor lanza hacia el último punto de mira que le llegó con el input: puede
  diferir unos centímetros de la mira que ve el cliente.
- La moneda se dibuja algo más grande que una real para que se lea con la cámara cenital.

## Cierre
