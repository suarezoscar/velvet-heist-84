# FEAT-027 — Legibilidad, objetivo al empezar y resumen al acabar

- **Estado**: hecha
- **Diseño**: `n/a — interfaz y presentación` (H4 «Legibilidad» del roadmap del PoC). El usuario aprobó el escalón 1 («jugable») el 2026-10-28.
- **Hito del PoC**: H4
- **Rama**: `feat/027-legibilidad`

## Objetivo
Que un jugador nuevo sepa quién es quién, hacia dónde mira cada uno, qué tiene que hacer y, al acabar, por qué ha ganado o perdido.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Cada personaje lleva a sus pies un anillo del color de su bando (ladrón rosa, guardias cian) con una flecha hacia donde mira. Los guardias llevan su número encima y el jugador local lleva «TÚ» | `test_legibility.gd` y capturas a 1600×900 (vista del ladrón y de un guardia) |
| 2 | La marca nunca delata a nadie: cuelga de VisualRoot y se oculta o pasa a la capa CCTV con el cuerpo (ladrón oculto o solo en cámaras, guardia que el ladrón no ve) | `test_marker_hides_and_goes_cctv_with_the_body` |
| 3 | Al empezar, una tarjeta dice el bando y el objetivo con las cifras de la partida (cuota, minutos, relojes). Se cierra sola a los 8 s o con cualquier tecla o clic, sin frenar la partida | `test_briefing_lines_use_match_numbers` y captura |
| 4 | Al acabar, el panel dice «HAS GANADO», «HAS PERDIDO» o «EMPATE» en el color del bando ganador, el motivo y las cifras (botín, Pieza Maestra, tiempo y faltas) | `test_summary_verdict_per_side` y captura |

## Contratos
- `TeamMarker3D.attach(actor, color, tag)` y `set_local(is_local)`. Las crea `LocalViewPresenter` y las salta en el servidor dedicado.
- `RoleBriefing84` (la crea `HeistMap3D`) y `RoleBriefing84.objectives(...)`.
- `MatchSummary`: `winner(state)`, `verdict(state, side)`, `stats(...)` y `local_side(map)`.

## Riesgos y decisiones abiertas
- Las etiquetas y anillos se dibujan después de la niebla: un compañero en la niebla se ve con su anillo, como ya se veía su cuerpo.
- Sin animaciones (aparcadas), la flecha es la que dice hacia dónde mira cada uno.

## Cierre
2026-10-28.
