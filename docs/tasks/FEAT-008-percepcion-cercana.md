# FEAT-008 — Percepción cercana, porra y anillos por alcance

- **Estado**: aprobada
- **Diseño**: `docs/gdd/systems/stealth.md` (aprobado, parte 1): secciones "Quién ve qué anillo", "Percepción cercana (proximidad) y puntos de visibilidad", "Porra", "Números" e invariantes 7, 8, 9, 11 y 12
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`

## Objetivo
Aplicar las reglas de percepción de `stealth.md`. Hoy el guardia percibe con un único punto fijo a 0,9 m y una distancia 3D desde los ojos (~1,70 m reales en horizontal), sin arco ciego. La porra llega a 1,6 m, la IA oye a 1,5 veces el anillo dibujado y todos los jugadores ven todos los anillos (auditoría de la Fase 1, bugs 6 y 7).

**Comportamiento que cambia a propósito:**
- La proximidad se mide en horizontal (1,8 m) y no cubre un arco de 120° a la espalda del guardia. El molde de cera pasa a ser posible.
- El guardia ve al ladrón si tiene línea de visión con al menos uno de sus dos puntos de visibilidad. De pie son la cabeza (1,6 m) y el pecho (1,2 m); agachado, dos puntos bajos (0,9 y 0,6 m). Agacharse tras una cobertura de 1 m oculta; estar de pie, no.
- El cono de la linterna usa los mismos puntos.
- Porra a 1,5 m en horizontal (antes 1,6 m en 3D).
- La IA oye exactamente hasta el radio del anillo, en horizontal.
- Un guardia jugador solo ve los anillos que le alcanzan; el ladrón y la vista sin jugador local los ven todos.

## Alcance y fuera de alcance
- Dentro:
  - el recurso `PerceptionProfile` y `perception_guard.tres`;
  - las funciones puras de `PerceptionRules`;
  - la percepción, la porra y la carga del perfil en `GuardController3D`;
  - el oído de `GuardAI3D`;
  - el filtro de anillos en `HeistMap3D`;
  - ajustes mecánicos de los tests existentes que dependían de la regla antigua;
  - los tests de aceptación.
- Fuera:
  - el alcance, el ángulo y la oclusión del cono de la linterna (parte 2 de `stealth.md`);
  - si un guardia ve los anillos de sus compañeros (parte 2);
  - el aspecto de los anillos (`SoundWave3D`);
  - la red: el filtro de anillos es de presentación local, y la replicación de la detección va con la red autoritativa;
  - `scenes/maps/museum_velvet_84.gd`;
  - las superficies por tipo del museo (`floorplan_blueprint.gd`), que van con `/level`;
  - el HUD.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | `perception_guard.tres` cumple los invariantes 7, 8 y 9: `melee_range` < `proximity_radius`; `rear_blind_arc_deg` > 0; los dos `crouch_points` < 1,0 y el mayor de `stand_points` > 1,0 | `test_perception.gd::test_profile_invariants` |
| 2 | Invariante 12: con los dos personajes en el suelo (Y = 0), sin linterna y el ladrón delante del guardia, se detecta a `proximity_radius` − 0,01 m y no a `proximity_radius` + 0,01 m | `test_perception.gd::test_proximity_horizontal_edge` |
| 3 | La altura no cuenta en la distancia: el ladrón a `proximity_radius` − 0,01 m en horizontal y 0,8 m más alto que el guardia, delante, se detecta | `test_perception.gd::test_proximity_ignores_height` |
| 4 | Arco ciego: un ladrón a 1,0 m detrás del guardia (180°) no se detecta por proximidad. A 1,0 m y a un ángulo de 180° − `rear_blind_arc_deg`/2 − 1° respecto al frente, sí; a 180° − `rear_blind_arc_deg`/2 + 1°, no | `test_perception.gd::test_rear_blind_arc` |
| 5 | Puntos de visibilidad: guardia en el origen mirando a −Z y ladrón en z = −1,2; caja de 1,0 m de alto y 0,2 m de fondo centrada en z = −1,0 (pegada al ladrón). De pie se detecta y agachado no. (Con la caja a mitad de camino el rayo a 0,9 m pasa por encima: no es un caso válido) | `test_perception.gd::test_low_cover_hides_crouched_only` |
| 6 | Un muro de 3 m entre los dos impide la detección por proximidad | `test_perception.gd::test_full_wall_blocks_proximity` |
| 7 | Cono: linterna apuntando al ladrón en z = −5,0; caja de 1,0 m de alto y 0,2 m de fondo centrada en z = −4,8. De pie se detecta y agachado no | `test_perception.gd::test_cone_uses_visibility_points` |
| 8 | Porra: `validate_melee_hit` acierta a `melee_range` − 0,01 m y falla a `melee_range` + 0,01 m (horizontal), acierta con 0,5 m de diferencia de altura y falla con un muro de por medio | `test_perception.gd::test_melee_range_edge` |
| 9 | Invariante 11 (IA): un ruido de radio R del ladrón a R − 0,01 m en horizontal pone a la IA en `INVESTIGATE`; a R + 0,01 m no cambia su estado | `test_perception.gd::test_ai_hears_exactly_the_ring` |
| 10 | Invariante 11 (anillos): `PerceptionRules.ring_visible_to` devuelve verdadero para un guardia a R − 0,01 m y falso a R + 0,01 m; verdadero para el ladrón a cualquier distancia, y verdadero si no hay espectador (`null`) | `test_perception.gd::test_ring_visibility_rule` |
| 11 | `HeistMap3D` no crea un `SoundWave3D` para un ruido fuera del alcance del guardia local y sí para uno dentro | `test_perception.gd::test_map_filters_rings_for_local_guard` |
| 12 | Ningún número de percepción queda en el código: desaparecen `HEARING_RADIUS_FACTOR`, `@export var melee_range`, la comparación `<= 1.8` y los desplazamientos fijos de ojos, torso y punto de visibilidad (`Vector3(0.0, 0.9/1.5/1.0, 0.0)`). Otras constantes que no son de percepción (`INVESTIGATE_REACHED_DISTANCE`, el `0.98` de la linterna y `reach_distance`) no se tocan | `grep -nE 'HEARING_RADIUS_FACTOR\|var melee_range\|<= 1\.8\|Vector3\(0\.0, (0\.9\|1\.5\|1\.0), 0\.0\)' src/entities/guard/*.gd` sin resultados |
| 13 | Suite en verde y lint limpio en los archivos cambiados | `run_tests.sh` y `lint.sh` en el informe de PKG-1 y en CI |

## Contratos

### `src/entities/components/perception_profile.gd` (nuevo)
```gdscript
## Percepción cercana del guardia: proximidad, arco ciego, puntos de visibilidad, porra y oído.
## Valores en data/balance/perception_guard.tres; diseño en docs/gdd/systems/stealth.md.
class_name PerceptionProfile
extends Resource

@export var proximity_radius: float = 1.8
@export var rear_blind_arc_deg: float = 120.0
## Alturas (m) sobre los pies del objetivo: [cabeza, pecho] de pie y [alto, bajo] agachado
@export var stand_points: PackedFloat32Array = PackedFloat32Array([1.6, 1.2])
@export var crouch_points: PackedFloat32Array = PackedFloat32Array([0.9, 0.6])
@export var melee_range: float = 1.5
@export var ai_hearing_factor: float = 1.0
## Geometría del guardia (no es balance): ojos para la vista, torso para la porra
@export var eye_height: float = 1.5
@export var torso_height: float = 1.0
```
Origen de los valores: tabla "Números" de `stealth.md`. `eye_height` (1,5) y `torso_height` (1,0) son los que usa hoy `guard_controller_3d.gd:102,134`.

### `data/balance/perception_guard.tres` (nuevo)
Mismo formato que `data/balance/movement_guard.tres`, con todos los campos escritos:
- `proximity_radius = 1.8`
- `rear_blind_arc_deg = 120.0`
- `stand_points = PackedFloat32Array(1.6, 1.2)`
- `crouch_points = PackedFloat32Array(0.9, 0.6)`
- `melee_range = 1.5`
- `ai_hearing_factor = 1.0`
- `eye_height = 1.5`
- `torso_height = 1.0`

### `src/entities/components/perception_rules.gd` (nuevo)
```gdscript
## Reglas puras de percepción cercana (sin estado ni física); las usan guardia, IA y mapa.
class_name PerceptionRules
extends RefCounted

## Distancia en el plano XZ
static func horizontal_distance(a: Vector3, b: Vector3) -> float
## Verdadero si target está en el arco ciego trasero del observador. Se usan las proyecciones
## XZ de observer_forward y de (target_pos - observer_pos). Si alguna mide < 0.001, devuelve
## false. Ángulo en grados entre ellas; devuelve ángulo > 180.0 - arc_deg / 2.0 (el borde
## pertenece al arco visible).
static func is_in_rear_blind_arc(
	observer_pos: Vector3, observer_forward: Vector3, target_pos: Vector3, arc_deg: float
) -> bool
## Puntos del mundo: target.global_position + Vector3(0, h, 0) para cada h de
## profile.crouch_points si target.is_crouching, o de profile.stand_points si no
static func visibility_points(target: PlayerBase3D, profile: PerceptionProfile) -> Array[Vector3]
## true si viewer es null o viewer.team_id != &"guard"; si es guardia,
## horizontal_distance(viewer.global_position, origin) <= radius
static func ring_visible_to(viewer: PlayerBase3D, origin: Vector3, radius: float) -> bool
```

### `src/entities/guard/guard_controller_3d.gd` (modificado)
- **Se añade** `const PERCEPTION_PROFILE_PATH: String = "res://data/balance/perception_guard.tres"` y `@export var perception: PerceptionProfile`. En `_ready`, junto a la carga del perfil de movimiento y **antes** de `super._ready()`: `if perception == null: perception = load(PERCEPTION_PROFILE_PATH)`.
- **Se borra** `@export var melee_range: float = 1.6`.
- **`check_detection_on_thief(thief)`**:
  - `eyes = global_position + Vector3(0, perception.eye_height, 0)`
  - `forward = -global_transform.basis.z`
  - `points = PerceptionRules.visibility_points(thief, perception)`
  - **Proximidad:** se cumple si `horizontal_distance(global_position, thief.global_position) <= perception.proximity_radius`, `is_in_rear_blind_arc(global_position, forward, thief.global_position, perception.rear_blind_arc_deg)` es falso y hay línea de visión desde `eyes` a **algún** punto. Entonces devuelve `true`.
  - **Cono:** la lógica actual (`maglite_light` visible, distancia ≤ `spot_range` y ángulo ≤ `spot_angle`), pero evaluada para cada punto en lugar de `thief_torso`. Si algún punto cumple las tres condiciones y tiene línea de visión desde el origen de la luz, devuelve `true`.
  - Si no se cumple ninguna, `false`.
- **`validate_melee_hit(target_thief)`**: falla si `horizontal_distance(global_position, target_thief.global_position) > perception.melee_range`. La línea de visión va de torso a torso con `perception.torso_height` en los dos. El resto no cambia.
- `_has_line_of_sight`, `swing_baton`, la estamina y la linterna no cambian.

### `src/entities/guard/guard_ai_3d.gd` (modificado)
- Se borra `HEARING_RADIUS_FACTOR`.
- `_on_noise_emitted` usa `PerceptionRules.horizontal_distance(_guard.global_position, pos) <= radius * _guard.perception.ai_hearing_factor`.
- En la línea que compara con `_guard.melee_range`, ahora es `_guard.perception.melee_range`.
- Nada más.

### `src/maps/heist_map_3d.gd` (modificado)
- `_on_noise_emitted`: después de la guarda de `radius <= 0.0`, `if not PerceptionRules.ring_visible_to(local_player, pos, radius): return`.
- Nada más.

## Assets necesarios
Ninguno.

## Impacto en red
- **Ninguno nuevo.** La detección sigue calculándose donde hoy (`HeistMap3D._process_guards_perception`).
- El filtro de anillos es local a cada cliente y depende de su `local_player`.
- La replicación del modo y de la detección va con la red autoritativa (grupo F de la auditoría), que debe usar `PerceptionRules` en el servidor.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | gameplay-engineer | `feat/008-pkg1` | FEAT-007 integrada | pendiente | 0 | |
| PKG-QA | qa-engineer | `feat/008-pkgqa` | PKG-1 | pendiente | 0 | |

## Paquetes de ejecución

### PKG-1 — Percepción cercana, porra y anillos
- **Agente / rama**: `gameplay-engineer` / `feat/008-pkg1`
- **Archivos permitidos**:
  ```allowed
  src/entities/components/perception_profile.gd
  src/entities/components/perception_rules.gd
  data/balance/perception_guard.tres  # excepción: valores aprobados en stealth.md, copiados tal cual de esta spec
  src/entities/guard/guard_controller_3d.gd
  src/entities/guard/guard_ai_3d.gd
  src/maps/heist_map_3d.gd
  tests/unit/test_thief_visibility.gd
  tests/unit/test_net_readiness.gd
  ```
- **Contratos**: los de la sección Contratos, exactamente.
- **Valores**: solo los de esta spec. No inventes ningún número.
- **Tests existentes**: solo cambios mecánicos, porque el guardia de los tests mira a −Z (rotación 0) y la regla nueva no detecta lo que está a su espalda:
  - `tests/unit/test_thief_visibility.gd`, funciones `test_proximity_detection_within_1_8m_no_wall`, `test_proximity_detection_beyond_1_8m_without_light` y `test_proximity_detection_blocked_by_wall`: cambia el signo de la coordenada Z del ladrón (1.2 → -1.2, 2.5 → -2.5, 1.4 → -1.4) y de la Z del muro (0.7 → -0.7). Nada más.
  - `tests/unit/test_net_readiness.gd`, funciones `test_authoritative_thief_visibility_within_proximity` y `test_authoritative_thief_hidden_behind_wall`: el mismo cambio de signo en la Z del ladrón (1.2 → -1.2, 1.4 → -1.4) y del muro (0.7 → -0.7). Nada más.
  - Si después de esos cambios falla algún otro test existente, **para** y entrega como `bloqueado` con el nombre del test y el error.
- **Formato**: `gdformat` sobre cada `.gd` que cambies o crees.
- **Comandos de cierre**:
  - `./tools/ci/import.sh`
  - `./tools/ci/check_scripts.sh`
  - `./tools/ci/lint.sh`
  - `./tools/ci/check_patterns.sh`
  - `python3 tools/ci/check_scope.py`
  - `./tools/ci/run_tests.sh`
  - `grep -nE 'HEARING_RADIUS_FACTOR|var melee_range|<= 1\.8|Vector3\(0\.0, (0\.9|1\.5|1\.0), 0\.0\)' src/entities/guard/guard_controller_3d.gd src/entities/guard/guard_ai_3d.gd` (sin resultados). Si el grep encontrara algo que no es de percepción, entrega como `bloqueado`: no reescribas código para esquivarlo
- **Fuera de alcance**:
  - `player_base_3d.gd`, `thief_controller_3d.gd`, `sound_wave_3d.gd`, `museum_velvet_84.gd` y cualquier `.tscn`;
  - la estamina, la linterna y `swing_baton`.

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/008-pkgqa` (sale de `master` con PKG-1 integrado)
- **Archivos permitidos**:
  ```allowed
  tests/unit/test_perception.gd
  ```
- **Reglas**:
  - Los valores de percepción se leen de `load("res://data/balance/perception_guard.tres")`; ningún test repite 1,8, 1,5, 120, 1,6, 1,2, 0,9 ni 0,6.
  - Las posiciones se construyen a partir del perfil (por ejemplo, `profile.proximity_radius - 0.01`).
  - Los obstáculos usan geometría fija del escenario: caja de 1,0 m de alto, muro de 3 m y diferencia de altura de 0,5 y 0,8 m.
  - Cada personaje se añade al árbol con `add_child_autofree` **antes** de usarlo: los perfiles se cargan en `_ready`.
  - Asigna `position` (no `global_position`) antes de `add_child_autofree`, y llama a `set_physics_process(false)` en cada personaje para que la física no lo mueva entre esperas.
  - El guardia, sin rotar, mira a −Z.
  - Sin `get_node("/root/…")`. El archivo tiene 300 líneas o menos.
  - Para el criterio 11, instancia un `HeistMap3D` mínimo (`HeistMap3D.new()` con un guardia hijo como `local_player` vía `set_local_player`), emite `SignalBus.noise_emitted_3d` y cuenta los hijos `SoundWave3D` del mapa.
- **Tests obligatorios** (`tests/unit/test_perception.gd`):
  - `test_profile_invariants` (1)
  - `test_proximity_horizontal_edge` (2)
  - `test_proximity_ignores_height` (3)
  - `test_rear_blind_arc` (4)
  - `test_low_cover_hides_crouched_only` (5)
  - `test_full_wall_blocks_proximity` (6)
  - `test_cone_uses_visibility_points` (7)
  - `test_melee_range_edge` (8)
  - `test_ai_hears_exactly_the_ring` (9)
  - `test_ring_visibility_rule` (10)
  - `test_map_filters_rings_for_local_guard` (11)
- **Comandos de cierre**: `./tools/ci/import.sh` (obligatorio primero: el worktree es nuevo y sin `.godot/`) · `./tools/ci/run_tests.sh` · `./tools/ci/lint.sh` · `./tools/ci/check_patterns.sh` · `python3 tools/ci/check_scope.py`

## Riesgos y decisiones abiertas
- **El frente del guardia es su orientación (`rotation.y`)**, que `update_presentation` gira hacia donde camina o, parado, hacia el cursor. Un guardia humano que mira con el ratón hacia un lado deja la espalda donde no mira. Es lo que pide el diseño. Se valida jugando antes del cierre.
- **Más difícil de ver:** con los puntos en 1,6 y 1,2 m, un ladrón de pie tras una vitrina de más de 1,6 m ya no se ve, y uno agachado tras una de 1 m tampoco. El nivel necesita coberturas bajas de ~1,0 m, que es una tarea de `/level` (`stealth.md`, efectos en otras partes).
- **`HeistMap3D` sin jugador local** (vista de espectador o de servidor) muestra todos los anillos. Si un servidor dedicado debe mostrar algo, se decidirá con la red autoritativa.
