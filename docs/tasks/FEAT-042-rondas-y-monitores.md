# FEAT-042 — Rondas holgadas con flecha y monitores CCTV para el ladrón

- **Estado**: en curso
- **Diseño**: `docs/gdd/systems/interaction.md` M1b, R2b, R6b; `docs/gdd/systems/vision.md` (acordado el 2026-10-29)
- **Hito del PoC**: H4 (legibilidad y bucle de juego en museo v2)
- **Rama**: `feat/042-rondas-y-monitores`

## Objetivo
Resolver dos problemas clave de ritmo y juego asimétrico:
1. **Rondas imposibles y desorientación**: el margen de los tramos de ronda era demasiado estrecho (unos 32 s para 40 m), obligando a correr sin margen para observar o tomar café. Los guardias no tenían guía visual del camino óptimo y durante la alarma se seguían sumando faltas absurdas por no fichar mientras perseguían al ladrón.
2. **Utilidad de la garita para el ladrón**: la mesa CCTV solo la podían usar los guardias. Dar al ladrón la posibilidad de entrar en la garita (jugada de alto riesgo con puerta ruidosa) para sentarse en la misma mesa y ver dónde están los guardias iluminados por las cámaras.

## Decisiones
1. **Tramos con más margen**: `leg_walk_factor` pasa de 1,8 a 2,3 y `leg_margin` de 15 a 25 s (`data/balance/time_clock_rules.tres`). Un tramo de 40 m pasa de ~32 s a ~47 s.
2. **Fin de fichar con alarma**: al sonar la alarma la ronda se suspende (`GuardRound.suspend()`). No hay faltas nuevas ni retrasos. Si el tiempo expira durante la alarma, cuenta al día si las faltas previas no superaban el límite tolerado.
3. **Flecha de guía en suelo**: `RoundArrow3D` en cian (`#3de0e0`) a los pies del guardia local, apuntando por las puertas y salas reales hacia el siguiente reloj con etiqueta `R3 · 18 m`. Se oculta si la ronda está suspendida o la partida ha terminado.
4. **Monitores para el ladrón**: el ladrón usa la misma mesa y silla con `E`. Si un guardia está sentado, está ocupada y viceversa.
5. **Visión CCTV para el ladrón**: el ladrón en monitores ve a los guardias en las cámaras si están iluminados (lámpara o linterna), replicado con marca `cctv_only` y renderizado en capa 20 (`CctvLayer`), sin sombras ni presencia en la cámara principal del mundo.
6. **HUD y controles**: la tablilla muestra `«ALARMA: olvidaos de la ronda, a por él»` en rojo/ámbar; los catálogos de controles y la web incluyen la acción para el ladrón.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Más margen de tiempo en los tramos de ronda | `test_round_rules.gd` (`test_legs_have_more_room`) |
| 2 | Alarma suspende la ronda sin faltas ni expiración por tiempo | `test_round_rules.gd` (`test_alarm_suspends_the_round`, `test_alarm_round_in_a_real_match`) |
| 3 | Flecha guía en el suelo con camino real entre puertas | `test_round_rules.gd` (`test_arrow_follows_the_path`), `test_round_arrow.gd` |
| 4 | El ladrón puede interactuar y sentarse en la mesa libre de monitores | `test_thief_monitors.gd` (`test_thief_sits_at_the_desk_when_free`) |
| 5 | El ladrón ve a guardias iluminados en cámaras solo en las pantallas | `test_thief_monitors.gd` (`test_thief_marks_cctv_guards`, `test_guard_on_camera_shows_only_on_the_screens`, `test_network_marks_put_the_guard_on_the_screens`) |
| 6 | Controles y HUD reflejan el estado | `round_sheet_84.gd`, `controls_catalog.gd`, `site/index.html` |

## Contratos
- `GuardRound`: propiedad `suspended: bool`, método `suspend()`, serialización `"off": suspended`.
- `RoundPlanner.walk_between(from, to) -> Array[Vector3]`: camino navegable entre salas para la flecha.
- `RoundArrow3D`: nodo visual de flecha en el suelo para el jugador local.
- `CctvLayer.apply(node, cctv)`: mueve geometría a capa 20 (CCTV) o restaura capas de origen y sombras.
- `CCTVDesk3D.can_interact(actor)`: acepta `GuardController3D` y `ThiefController3D`.
- `VisionLogic.thief_view_of(...)`: retorna `&"cctv"` si está en monitores y alguna cámara ve al guardia con luz.
- `SecurityCamera3D.any_sees_guard(context, guard, lamps) -> bool`.
- Red: marca `cctv_only` para guardias en instantáneas del ladrón; `watch` en `actor_net_state.gd` para cualquier personaje.

## Riesgos y decisiones abiertas
- La alarma por cámara solo suma sospecha si es un guardia quien mira; el ladrón mirando monitores no activa alarmas de cámara sobre sí mismo ni sobre guardias.
- Si una cámara está en penumbra total, no ve nada (fiel a 1984, pilar 1).
- Con el ladrón sentado se encienden los pilotos de grabación (M4) y la mesa sale ocupada: un
  guardia que no ve a ningún compañero en la mesa puede deducir que es el ladrón. Decisión del
  usuario (2026-10-30): las cámaras se comportan igual las use quien las use; es el riesgo de
  esa jugada.
- Si el ladrón se desconecta sentado, se levanta (la mesa queda libre).

## Cierre

