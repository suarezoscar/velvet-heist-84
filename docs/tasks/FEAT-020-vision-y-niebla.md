# FEAT-020 — Visión y niebla de guerra

- **Estado**: hecha
- **Diseño**: `docs/gdd/systems/vision.md` (aprobado el 2026-10-24)
- **Hito del PoC**: H4
- **Rama**: `feat/020-vision`

## Objetivo
Que cada jugador vea solo lo que su personaje puede ver. El ladrón deja de ver a los guardias a través de los muros, y el sigilo recupera la sorpresa.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | La zona visible es de 360° desde los ojos, cortada solo por muros y tabiques (nueva capa de colisión `walls`) y limitada a `thief_view_radius` o `guard_view_radius` (`data/balance/vision_rules.tres`) | `tests/unit/test_vision.gd` |
| 2 | La niebla oscurece y desatura lo que queda fuera de la zona visible, con borde suave. No se dibuja en las imágenes CCTV y desaparece al acabar la partida | captura y `test_vision.gd` |
| 3 | El ladrón ve a un guardia de su zona visible si está iluminado, lleva la linterna encendida o está a ≤ `dark_sight_radius` (R3). Si no lo ve pero lleva la linterna encendida, solo ve el haz | `test_vision.gd` |
| 4 | Red: el ladrón no recibe a los guardias que no ve, salvo `beam_only` con la linterna encendida. Los guardias se reciben siempre entre sí. Al acabar la partida no hay filtro | `test_vision.gd`, `test_vision_net.gd` (partida con `--net-log`: backlog) |
| 5 | Sin red, la misma regla se aplica desde el jugador local | `test_vision_net.gd` |
| 6 | Memoria del botín (D4): si el botín desaparece de un sitio que no ves, sigues viendo un fantasma hasta que vuelves a mirar | `test_vision.gd` |

## Contratos
- `VisionProfile` (`src/systems/vision/vision_profile.gd`) y `data/balance/vision_rules.tres`.
- `VisionLogic` (estática):
  - `wall_free(space, from, to)`;
  - `thief_sees_guard(thief, guard, lamps)`;
  - `view_radius(actor)`.
- `LevelArchitectureBuilder.LAYER_WALLS`, la capa 9: muros, tabiques y alféizares. `Interactor3D` usa esta capa para no interactuar a través de muros, en lugar del grupo `walls`.
- `GuardController3D.set_body_visible(on)`.
- `FogOfWar3D`:
  - malla de pantalla completa en la capa de render `FOG_LAYER` (19), que las cámaras CCTV excluyen;
  - `viewer`, `is_point_visible(pos)` y `enabled`.
- `FogMemory`: fantasmas del botín desaparecido en la niebla.
- `NetSnapshots.build(...)`: estados por peer con las marcas `cctv_only` y `beam_only`.

| Dato | A quién | Cuándo |
|---|---|---|
| Guarda completo | ladrón | si `thief_sees_guard` |
| Guarda `beam_only` (posición, mirada, linterna) | ladrón | si no lo ve y la linterna está encendida |
| Guarda | otros guardias | siempre |
| Todos | todos | con la partida terminada |

## Riesgos y decisiones abiertas
- La memoria (D4) cubre el botín. Las banderolas de los relojes y la puerta de la caja fuerte se dejan para después: el ladrón ya oye la campana, y la caja solo la abre él.
- La niebla se dibuja reconstruyendo la posición de cada píxel desde la profundidad, con Forward+.

## Cierre
2026-10-28. Integrada en el PR #69. La auditoría posterior (`reviewer`) encontró dos bloqueantes, que se arreglan en la rama `fix/020-review`:
- **La niebla tapaba todo lo transparente**, incluida la silueta O2: ahora se dibuja la primera del pase transparente (`render_priority` mínima).
- **Haz congelado en el cliente del ladrón**: un guardia que sale del snapshot apaga también su linterna en ese cliente.

En la misma rama se arreglan:
- **Filtro de red**:
  - ante un dato que falta, oculta;
  - `beam_only` solo lleva posición, giro, mirada y linterna;
  - un guardia sin rol, o antes del primer snapshot, no se ve.
- **Luces en la niebla (D5)**: los pilotos y las bombillas la atraviesan (`fog_light_keep`).
- **Memoria del botín**:
  - oculta los hijos visuales, así que la red no la deshace;
  - un objeto movido en la niebla deja de verse en su sitio nuevo.
- **Rendimiento**: la zona se recalcula solo si el jugador se mueve, con una sola consulta de rayo, y sin mipmaps de la pantalla.
- **Tests**: los criterios 4 y 5, el borde de `dark_sight_radius` y la exclusión del CCTV, en `tests/unit/test_vision_net.gd`.

Backlog:
- partida en red con `--net-log` como evidencia del criterio 4: los clientes aún no se pueden automatizar por CLI;
- al reconectar a media partida, la memoria del botín se siembra antes del estado completo del mundo (hoy no hay reconexión);
- la vista con 1-3 rayos en lugar de uno;
- una escena de prueba aislada del VFX de niebla (regla 04).
