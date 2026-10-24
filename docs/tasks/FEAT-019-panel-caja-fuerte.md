# FEAT-019 — Panel del dial de la caja fuerte

- **Estado**: hecha
- **Diseño**: `n/a — interfaz`. Lo pidió el usuario el 2026-10-24: «se abre una especie de menú en medio de la pantalla que bloquea el movimiento; ahí se mueve el dial con flechas; Esc para salir o E para validar».
- **Hito del PoC**: H3
- **Rama**: `feat/019-panel-caja-fuerte`

## Objetivo
Que abrir la caja fuerte sea claro y cómodo: un panel central con el dial, sin que el ladrón se mueva, y sin pulsar 65 veces para llegar a un número.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Al pulsar E ante la caja se abre un panel central: dial de 100 marcas con el número actual, «Número N de 3», bolas de progreso y controles. Destella en verde al acertar y en rojo al fallar | `tests/unit/test_safe_dial_panel.gd` y captura |
| 2 | Mientras está abierto, el ladrón no se mueve (PR #66). Las flechas o A/D giran el dial, E prueba el número y Esc sale | `test_safe_dial_input.gd` y `test_safe_dial_panel.gd` |
| 3 | Al mantener la tecla, el dial gira seguido y acelera (`data/balance/safe_dial.tres`), sin red y en red | `test_safe_dial_panel.gd` |
| 4 | El aviso inferior del HUD desaparece mientras está el panel | `test_safe_dial_panel.gd` |

## Riesgos y decisiones abiertas
- Se abre al pulsar E, no al acercarse, para no atrapar al ladrón que solo cruza la sala.
- Que el dial gire seguido lo propuse yo, sin respuesta explícita del usuario. Se quita con `repeat_delay` muy alto en `safe_dial.tres`.

## Cierre
2026-10-24.
