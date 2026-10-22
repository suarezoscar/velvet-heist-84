# FEAT-007 — Modos de movimiento y ruido de pasos

- **Estado**: aprobada
- **Diseño**: `docs/gdd/systems/stealth.md` (aprobado, parte 1): secciones "Modos de movimiento", "Ruido de pasos", "Números" e invariantes 1-6 y 10
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`

## Objetivo
Aplicar en el código las reglas de movimiento y ruido de `stealth.md`:
- Se eliminan TIPTOE, PRONE y WALL_COVER.
- El agachado es un modo solo del ladrón y anula el sigilo y la carrera.
- Moverse siempre emite al menos `min_radius`.
- Los guardias suenan ×1,2.
- Todos los números se leen de `data/balance/*.tres`.

Al quitar las posturas, `PlayerBase3D` baja de 586 a menos de 300 líneas y vuelve a pasar el lint. Lo pide el grupo B de la auditoría (`docs/decisions/2026-10-22-fase-1-auditoria.md`).

Este cambio **cambia el comportamiento a propósito**:
- el ladrón agachado pasa de 2,75 a 2,0 m/s;
- la carrera del guardia pasa de 6,2 a 6,3 m/s;
- el sigilo del guardia pasa de 2,0 a 2,016 m/s;
- los pasos de los guardias suenan ×1,2;
- ningún paso emite radio 0.

## Alcance y fuera de alcance
- Dentro:
  - dos recursos nuevos (`MovementProfile`, `StepNoiseProfile`) y sus tres `.tres`;
  - `PlayerBase3D` con modos en lugar de posturas;
  - dos ayudantes extraídos (`CrouchCollision`, `LocalInput3D`);
  - controladores de ladrón y guardia leyendo su perfil;
  - `CharacterAnimator3D` por modo;
  - `SurfaceDetector3D` sin código muerto;
  - quitar las acciones `prone` y `wall_cover` de `project.godot`;
  - borrar los tests de las posturas eliminadas y escribir los tests de aceptación nuevos.
- Fuera (FEAT-008, percepción cercana):
  - proximidad, arco ciego, puntos de visibilidad, porra y oído de la IA;
  - filtro de anillos por alcance;
  - superficies por tipo en el museo (`floorplan_blueprint.gd`).
- Fuera también:
  - el indicador de modo en el HUD (FEAT de UI posterior; esta FEAT deja las señales `crouch_changed` y `stand_up_blocked`);
  - la red (el modo no se sincroniza en el mapa del museo; eso va con la red autoritativa);
  - la estamina del guardia;
  - el botín pesado;
  - `main_menu.gd` y `net_manager.gd`.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Los modos son exactamente WALK, SNEAK, SPRINT y CROUCH. `get_move_mode()` devuelve CROUCH si `is_crouching`; si no, SNEAK si `is_sneaking`; si no, SPRINT si `is_sprinting`; si no, WALK. Con `sneak` y `sprint` a la vez gana SNEAK | `test_movement_modes.gd::test_mode_resolution_priority` |
| 2 | Invariante 1: en cada perfil, la velocidad cumple sneak < walk < sprint, y el multiplicador de ruido sigue el mismo orden | `test_movement_modes.gd::test_invariant_1_gait_order` |
| 3 | Invariante 2: en cada bando, ningún par de modos A y B cumple a la vez velocidad(A) ≥ velocidad(B), ruido(A) ≤ ruido(B) y altura(A) ≤ altura(B) con alguna desigualdad estricta. Altura: CROUCH = `CrouchCollision.CROUCH_HEIGHT`, el resto = `STAND_HEIGHT`. Los modos del guardia excluyen CROUCH | `test_movement_modes.gd::test_invariant_2_no_dominant_mode` |
| 4 | Invariante 3: con cualquier modo, bando y superficie (alfombra, parqué y mármol, leídos de sus `.tres`), `radius_for` ≥ `min_radius` > 0. Un personaje parado no emite `noise_emitted_3d` en 2 s de simulación | `test_step_noise.gd::test_invariant_3_never_silent` y `test_step_noise.gd::test_standing_still_emits_nothing` |
| 5 | Invariante 4: `sprint_mult` > `sprint_ratio` en los dos perfiles | `test_step_noise.gd::test_invariant_4_sprint_louder_per_metre` |
| 6 | Invariante 5: `crouch_ratio` < `sneak_ratio` y `crouch_mult` = `sneak_mult`. Con `is_crouching`, poner `is_sneaking` o `is_sprinting` a verdadero no cambia ni `current_speed` ni el radio del paso | `test_movement_modes.gd::test_invariant_5_crouch_overrides_gait` |
| 7 | Invariante 6: con el mismo modo y superficie, el radio del guardia ≥ el del ladrón, y `team_noise_mult` del guardia ≥ 1 | `test_step_noise.gd::test_invariant_6_guard_boots` |
| 8 | Invariante 10: alfombra < 1 ≤ mármol ≤ parqué, leído de `data/balance/surface_*.tres` | `test_step_noise.gd::test_invariant_10_surface_order` |
| 9 | Un paso real (`simulate_movement` sobre un `StaticBody3D` con el metadato `noise_multiplier` de cada `.tres`) emite el radio de `radius_for` con la superficie de ese suelo, con tolerancia de 0,001 | `test_step_noise.gd::test_real_step_on_each_surface` |
| 10 | El guardia no puede agacharse: `set_crouching(true)` devuelve `false` y `is_crouching` sigue en falso | `test_movement_modes.gd::test_guard_cannot_crouch` |
| 11 | Con un techo a 1,3 m, `set_crouching(false)` devuelve `false`, emite `stand_up_blocked` una vez y deja `is_crouching` en verdadero. Sin techo, devuelve `true` y emite `crouch_changed(false)` | `test_movement_modes.gd::test_stand_up_needs_headroom` |
| 12 | La cápsula mide 1,6 m de alto (origen en Y 0,8) de pie y 1,0 m (origen en Y 0,5) agachado, con radio 0,35 en ambos casos. Al cambiar la de un personaje no cambia la de otro de la misma escena | `test_movement_modes.gd::test_crouch_capsule_and_isolation` |
| 13 | El animador elige: WALK y SPRINT en movimiento → `walk`; SNEAK → `sneak_walk`; CROUCH → `crouch_walk`; parado de pie → `idle_stand`; parado agachado → `idle_crouch` | `test_movement_modes.gd::test_animator_mapping` |
| 14 | El código ya no contiene `Stance`, `TIPTOE`, `PRONE` ni `WALL_COVER`, y `project.godot` no tiene las acciones `prone` ni `wall_cover` | `grep -rnE 'Stance\|TIPTOE\|PRONE\|WALL_COVER' src tests scenes/entities` sin resultados; `grep -nE '^(prone\|wall_cover)=' project.godot` sin resultados |
| 15 | `player_base_3d.gd` tiene 300 líneas o menos y todos los archivos cambiados pasan `lint.sh` | Salida de `./tools/ci/lint.sh` en el informe de PKG-1 |
| 16 | Estrés: 1.000 cambios alternos de agachado en 1.000 ticks no dejan la cápsula en un tamaño intermedio, y el animador sin `AnimationPlayer` no falla | `tests/stress/test_movement_stress.gd` |

## Contratos

### `src/entities/components/movement_profile.gd` (nuevo)
```gdscript
## Perfil de movimiento de un bando (velocidades, cadencia de pasos y peso de botas).
## Valores en data/balance/movement_*.tres; diseño en docs/gdd/systems/stealth.md.
class_name MovementProfile
extends Resource

enum Mode { WALK = 0, SNEAK = 1, SPRINT = 2, CROUCH = 3 }

@export var walk_speed: float = 4.5
@export var sneak_ratio: float = 0.48
@export var sprint_ratio: float = 1.5
@export var crouch_ratio: float = 0.40
@export var can_crouch: bool = true
@export var team_noise_mult: float = 1.0
@export var step_interval_walk: float = 0.42
@export var step_interval_sneak: float = 0.60
@export var step_interval_sprint: float = 0.28
@export var step_interval_crouch: float = 0.55
@export var acceleration: float = 18.0
@export var friction: float = 22.0

## walk_speed × (1 | sneak_ratio | sprint_ratio | crouch_ratio) según el modo
func speed_for(mode: Mode) -> float
## step_interval_<modo>
func step_interval_for(mode: Mode) -> float
```
Los valores por defecto son los de `PlayerBase3D` hoy (4,5; aceleración 18; fricción 22) y las cadencias de `stealth.md`. Solo los usa un `PlayerBase3D` creado sin perfil, como en los tests.

### `src/entities/components/step_noise_profile.gd` (nuevo)
```gdscript
## Ruido de un paso: r = max(min_radius, base_radius × g_modo × superficie × bando).
class_name StepNoiseProfile
extends Resource

@export var base_radius: float = 3.5
@export var sneak_mult: float = 0.3
@export var sprint_mult: float = 2.0
@export var crouch_mult: float = 0.3
@export var min_radius: float = 0.5

## 1.0 para WALK; sneak_mult, sprint_mult o crouch_mult
func mode_mult(mode: MovementProfile.Mode) -> float
## maxf(min_radius, base_radius * mode_mult(mode) * surface_mult * team_mult)
func radius_for(mode: MovementProfile.Mode, surface_mult: float, team_mult: float) -> float
```

### `.tres` nuevos (valores de la tabla "Números" de `stealth.md`)
| Archivo | Campos |
|---|---|
| `data/balance/movement_thief.tres` | `walk_speed` 5.0 · `sneak_ratio` 0.48 · `sprint_ratio` 1.5 · `crouch_ratio` 0.40 · `can_crouch` true · `team_noise_mult` 1.0 · cadencias 0.42 / 0.60 / 0.28 / 0.55 · `acceleration` 18.0 · `friction` 22.0 |
| `data/balance/movement_guard.tres` | `walk_speed` 4.2 · `sneak_ratio` 0.48 · `sprint_ratio` 1.5 · `crouch_ratio` 0.40 · `can_crouch` false · `team_noise_mult` 1.2 · cadencias 0.42 / 0.60 / 0.28 / 0.55 · `acceleration` 18.0 · `friction` 22.0 |
| `data/balance/step_noise.tres` | `base_radius` 3.5 · `sneak_mult` 0.3 · `sprint_mult` 2.0 · `crouch_mult` 0.3 · `min_radius` 0.5 |

Mismo formato que `data/balance/surface_carpet.tres`: `[gd_resource type="Resource" script_class="..." load_steps=2 format=3]`, `ext_resource` del script y bloque `[resource]` con todos los campos escritos, aunque coincidan con el valor por defecto.

### `src/entities/components/crouch_collision.gd` (nuevo)
```gdscript
## Cápsula de pie y agachado, y comprobación de espacio libre para levantarse.
class_name CrouchCollision
extends RefCounted

const STAND_HEIGHT: float = 1.6
const CROUCH_HEIGHT: float = 1.0
const CAPSULE_RADIUS: float = 0.35
## Meta que marca la forma ya duplicada para este personaje (no se comparte con la escena)
const LOCAL_SHAPE_META: StringName = &"vh84_local_shape"

## Ajusta altura, radio y origen (altura / 2) de la cápsula. Si la forma es null crea una
## CapsuleShape3D; si no tiene LOCAL_SHAPE_META, la duplica una vez y la marca.
static func apply(shape_node: CollisionShape3D, crouching: bool) -> void
## Rayo desde body.global_position + (0, 0.1, 0) hasta + (0, height, 0), máscara 1, excluyendo
## al cuerpo. Devuelve true si no choca o si el cuerpo no está en el árbol.
static func has_headroom(body: CharacterBody3D, height: float) -> bool
```

### `src/entities/components/local_input_3d.gd` (nuevo)
```gdscript
## Lectura del teclado y ratón del jugador local (solo la usa PlayerBase3D.gather_input).
class_name LocalInput3D
extends RefCounted

## Diccionario con movement_vector (Vector2), is_sprinting, is_sneaking, crouch
## (just_pressed) y look_target (Vector3). Usa move_* o ui_* como hoy.
static func read(player: PlayerBase3D, cam: Camera3D) -> Dictionary
## Lo mismo que hoy hace PlayerBase3D.project_cursor_on_ground
static func project_cursor(player: PlayerBase3D, cam: Camera3D) -> Vector3
```

### `src/entities/player_base_3d.gd` (modificado)
- **Se elimina**:
  - el enum `Stance`, la señal `stance_changed` y `current_stance`;
  - `get_stance`, `set_stance`, `can_enter_stance`, `get_stance_speed_multiplier` y `get_stance_noise_multiplier`;
  - `_update_collision_for_stance`, `detect_wall_ahead`, `_align_to_wall`, `get_cover_wall_normal`, `get_cover_wall_tangent`, `current_wall_normal`, `current_wall_tangent` y `_is_shape_duplicated`;
  - los `@export` `move_speed`, `sprint_speed`, `sneak_speed`, `acceleration` y `friction`, y la variable `_step_interval`.
- **Se añade**:
  ```gdscript
  signal crouch_changed(is_crouching: bool)
  signal stand_up_blocked
  const GRAVITY: float = 19.6
  const DEFAULT_STEP_NOISE_PATH: String = "res://data/balance/step_noise.tres"
  @export var movement_profile: MovementProfile   # null → MovementProfile.new() en _ready
  @export var step_noise: StepNoiseProfile        # null → load(DEFAULT_STEP_NOISE_PATH) en _ready
  var is_crouching: bool = false
  func get_move_mode() -> MovementProfile.Mode
  func set_crouching(value: bool) -> bool
  func compute_step_radius() -> float
  ```
- **`set_crouching(value)`**, en este orden:
  1. Si `value == is_crouching`, devuelve `false`.
  2. Si `value` es verdadero y `movement_profile.can_crouch` es falso, devuelve `false`.
  3. Si `value` es falso y `CrouchCollision.has_headroom(self, CrouchCollision.STAND_HEIGHT)` es falso, emite `stand_up_blocked` y devuelve `false`.
  4. Si no: asigna, llama a `CrouchCollision.apply(collision_shape, value)`, emite `crouch_changed(value)` y devuelve `true`.
- **`compute_step_radius()`** devuelve `step_noise.radius_for(get_move_mode(), <multiplicador de superficie>, movement_profile.team_noise_mult)`. El multiplicador de superficie es `surface_detector.get_surface_noise_multiplier()`, o 1.0 si no hay detector.
- **`_apply_movement_speed`**: `current_speed = movement_profile.speed_for(get_move_mode())`; aceleración y fricción salen del perfil, y la cadencia de `step_interval_for(get_move_mode())`.
- **`_emit_step_sound`** emite `noise_emitted_3d(global_position, compute_step_radius(), team_id)` y `footprint_stepped_3d` como hoy. Nunca emite radio 0.
- **`apply_input`** acepta las mismas claves de movimiento, sigilo, carrera y mirada que hoy (incluidos los alias), y además:
  - `"crouch": true` alterna con `set_crouching(not is_crouching)`;
  - `"crouching": bool` fija el valor con `set_crouching(valor)`.

  Se quitan las claves `stance`, `target_stance`, `wall_cover`, `prone` y `tiptoe`.
- **`gather_input(cam)`** devuelve `LocalInput3D.read(self, cam)`, y **`project_cursor_on_ground(cam)`** devuelve `LocalInput3D.project_cursor(self, cam)`. Las firmas públicas no cambian.
- **`set_net_state(pos: Vector3, vel: Vector3, crouching: bool)`** llama a `set_net_transform(pos, vel)` y después a `set_crouching(crouching)`.
- **`simulate_movement`**: la rama de WALL_COVER desaparece y la lógica de los demás modos queda igual. Para orientar el cuerpo, `update_presentation` deja de usar la normal del muro.
- El archivo queda en 300 líneas o menos, con el orden de definiciones de gdlint (`class-definitions-order`).

### Controladores
- **`src/entities/thief/thief_controller_3d.gd`**:
  - `const MOVEMENT_PROFILE_PATH: String = "res://data/balance/movement_thief.tres"`;
  - en `_ready`, **antes** de `super._ready()`: `if movement_profile == null: movement_profile = load(MOVEMENT_PROFILE_PATH)`;
  - se borran las líneas `move_speed = …`, `sprint_speed = …` y `sneak_speed = …`;
  - se corrige el `class-definitions-order` de la línea 141.
- **`src/entities/guard/guard_controller_3d.gd`**:
  - lo mismo con `"res://data/balance/movement_guard.tres"`;
  - se mueven las constantes de las líneas 12-15 antes de los `@export`, y se corrige la línea 187 (`class-definitions-order`);
  - la estamina y la porra no cambian.

### `src/entities/components/character_animator_3d.gd` (modificado)
- `func resolve_animation_name(mode: MovementProfile.Mode, horizontal_speed: float) -> StringName`, con el mapeo del criterio 13.
- `_process` llama a `resolve_animation_name(_player.get_move_mode(), horizontal_speed)`.
- Se quitan:
  - la conexión a `stance_changed` y `_on_stance_changed`;
  - `ROOT_MOTION_ANIMATIONS` y `_strip_horizontal_hips_motion`;
  - las entradas de `tiptoe_walk`, `prone_*` y `cover_*` en `LOOPED_ANIMATIONS` y `ANIMATION_REFERENCE_SPEED`.
- Quedan:
  - `LOOPED_ANIMATIONS = [walk, sneak_walk, crouch_walk]`;
  - `ANIMATION_REFERENCE_SPEED = {walk: 1.6, sneak_walk: 1.2, crouch_walk: 1.2}`;
  - `play_action` y `POSES` sin cambios.

### `src/entities/components/surface_detector_3d.gd` (modificado)
- Se borran `CARPET_NOISE_MULTIPLIER`, `WOOD_PARQUET_NOISE_MULTIPLIER`, `MARBLE_NOISE_MULTIPLIER` y `calculate_step_noise_radius`. Los valores viven en los `.tres`, y el cálculo, en `StepNoiseProfile`.
- `get_surface_noise_multiplier()` no cambia.

### `project.godot` (modificado)
Se borran los bloques de las acciones `prone` y `wall_cover`. `crouch` sigue en la tecla C.

## Assets necesarios
Ninguno. Las animaciones `tiptoe_walk`, `prone_*` y `cover_*` siguen dentro de los `.glb`, sin usarse; los personajes se sustituirán según `characters.md`.

## Impacto en red
- El modo no se replica en el museo hoy; tampoco lo hacía la postura.
- `set_net_state` cambia su tercer parámetro a `crouching: bool`, y solo lo usan los tests.
- La replicación del modo va con la red autoritativa (grupo F de la auditoría).

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | gameplay-engineer | `feat/007-pkg1` | — | en curso | 0 | |
| PKG-2 | integrator | `feat/007-pkg2` | — | en curso | 0 | En paralelo con PKG-1; no comparten archivos |
| PKG-QA | qa-engineer | `feat/007-pkgqa` | PKG-1 | pendiente | 0 | |

## Paquetes de ejecución

### PKG-1 — Modos de movimiento y perfiles
- **Agente / rama**: `gameplay-engineer` / `feat/007-pkg1`
- **Archivos permitidos**:
  ```allowed
  src/entities/components/movement_profile.gd
  src/entities/components/step_noise_profile.gd
  src/entities/components/crouch_collision.gd
  src/entities/components/local_input_3d.gd
  src/entities/player_base_3d.gd
  src/entities/thief/thief_controller_3d.gd
  src/entities/guard/guard_controller_3d.gd
  src/entities/components/character_animator_3d.gd
  src/entities/components/surface_detector_3d.gd
  data/balance/movement_thief.tres  # excepción: valores aprobados en stealth.md, copiados tal cual de esta spec
  data/balance/movement_guard.tres  # excepción: valores aprobados en stealth.md, copiados tal cual de esta spec
  data/balance/step_noise.tres  # excepción: valores aprobados en stealth.md, copiados tal cual de esta spec
  tests/unit/test_stealth_mechanics.gd
  tests/unit/test_net_readiness.gd
  tests/unit/test_surface_detector_noise.gd  # excepción: se borra; prueba API eliminada (la sustituye PKG-QA)
  tests/stress/test_stealth_stress.gd  # excepción: se borra; prueba posturas eliminadas (la sustituye PKG-QA)
  ```
  Los `.uid` que Godot genere para los scripts nuevos entran con su script (`<script>.gd.uid`).
- **Contratos**: los de la sección Contratos, exactamente.
- **Valores**: solo los de las tablas de Contratos. No inventes ningún número. Si falta uno, para y repórtalo.
- **Tests existentes** (solo los cambios que impone la API; los de aceptación los escribe PKG-QA):
  - **`tests/unit/test_stealth_mechanics.gd`**:
    - Borra estas funciones: `test_criterio_2_stance_enum_and_capsule_dimensions`, `test_criterio_3_tiptoe_and_prone_noise_emission`, `test_criterio_4_prone_passes_under_laser_at_60cm`, `test_headroom_check_blocks_stand_under_low_ceiling`, `test_criterio_5_wall_cover_detection_and_lateral_kinematics`, `test_criterio_6_character_animator_state_mapping` y `test_stance_speed_multipliers_and_kinematic_convergence`.
    - Borra también los ayudantes que queden sin uso (`_create_player`, `_create_solid_box`).
    - Actualiza el docstring de la cabecera: el archivo comprueba los modelos y las pistas de animación de FEAT-005.
    - Conserva `test_criterio_1_*` y `test_criterio_6_all_11_animation_tracks_exist_in_glb_assets` sin cambios.
  - **`tests/unit/test_net_readiness.gd`**:
    - En la línea 133, sustituye `thief.sprint_speed` por `thief.movement_profile.speed_for(MovementProfile.Mode.SPRINT)`.
    - Ajusta el comentario de la línea 129 a "velocidad de carrera del perfil".
    - Nada más.
  - Borra `tests/unit/test_surface_detector_noise.gd` y `tests/stress/test_stealth_stress.gd` con `git rm`.
- **Formato**: ejecuta `gdformat` sobre cada `.gd` que cambies o crees antes de los comandos de cierre.
- **Comandos de cierre**:
  - `./tools/ci/import.sh`
  - `./tools/ci/check_scripts.sh`
  - `./tools/ci/lint.sh` (0 errores en los archivos cambiados; pega la salida)
  - `./tools/ci/check_patterns.sh`
  - `python3 tools/ci/check_scope.py`
  - `./tools/ci/run_tests.sh` (todo verde)
  - `wc -l src/entities/player_base_3d.gd` (300 o menos)
  - `grep -rnE 'Stance|TIPTOE|PRONE|WALL_COVER' src tests scenes/entities` (sin resultados)
- **Fuera de alcance**:
  - `guard_ai_3d.gd`, `heist_map_3d.gd`, la percepción (`guard_controller_3d.gd:107-183`), `thief_controller_3d.gd` fuera de `_ready` y del orden de definiciones, `floorplan_blueprint.gd` y `museum_velvet_84.gd`;
  - `project.godot` (es de PKG-2);
  - cualquier escena `.tscn`.

### PKG-2 — Acciones de entrada obsoletas
- **Agente / rama**: `integrator` / `feat/007-pkg2`
- **Archivos permitidos**:
  ```allowed
  project.godot
  ```
- **Contrato**: borra completos los bloques `prone={…}` y `wall_cover={…}` de la sección `[input]`. No toques nada más del archivo. `gather_input` ya comprueba `InputMap.has_action`, así que el cambio es seguro antes y después de PKG-1.
- **Comandos de cierre**:
  - `grep -nE '^(prone|wall_cover)=' project.godot` (sin resultados)
  - `./tools/ci/import.sh` · `./tools/ci/check_scripts.sh` · `./tools/ci/run_tests.sh` · `python3 tools/ci/check_scope.py`

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/007-pkgqa` (sale de `master` con PKG-1 integrado)
- **Archivos permitidos**:
  ```allowed
  tests/unit/test_movement_modes.gd
  tests/unit/test_step_noise.gd
  tests/stress/test_movement_stress.gd
  ```
- **Reglas**:
  - Los valores se leen de los `.tres` (`load("res://data/balance/…")`) o de las constantes de `CrouchCollision`; ningún test repite un número de balance.
  - Única excepción, de geometría del escenario: las alturas de techo (1,3 m) y las posiciones de los suelos.
  - Para los perfiles se usan los `.tres`, no `MovementProfile.new()`.
  - Cada archivo tiene 300 líneas o menos.
  - Sin `get_node("/root/…")`: se usa el autoload `SignalBus` por su nombre global.
- **Tests obligatorios**:
  - `tests/unit/test_movement_modes.gd`: `test_mode_resolution_priority` (1), `test_invariant_1_gait_order` (2), `test_invariant_2_no_dominant_mode` (3), `test_invariant_5_crouch_overrides_gait` (6), `test_guard_cannot_crouch` (10), `test_stand_up_needs_headroom` (11), `test_crouch_capsule_and_isolation` (12) y `test_animator_mapping` (13).
  - `tests/unit/test_step_noise.gd`: `test_invariant_3_never_silent` y `test_standing_still_emits_nothing` (4), `test_invariant_4_sprint_louder_per_metre` (5), `test_invariant_6_guard_boots` (7), `test_invariant_10_surface_order` (8) y `test_real_step_on_each_surface` (9).
  - `tests/stress/test_movement_stress.gd`: `test_crouch_toggle_spam` y `test_animator_without_animation_player` (16).
- **Montaje de los tests con física**:
  - Instancia `ThiefController3D` o `GuardController3D` con `.new()`, con un `CollisionShape3D` hijo llamado `CollisionShape3D`.
  - Usa como suelo un `StaticBody3D` de capa 1 con una `BoxShape3D` de 20 × 0,2 × 20 m y el metadato `noise_multiplier`.
  - Para el criterio 4, escucha `SignalBus.noise_emitted_3d` con `watch_signals(SignalBus)`.
  - Avanza la simulación con `simulate_movement(1.0 / 60.0)` en un bucle, esperando un `await wait_physics_frames(1)` cada 10 ticks para que el rayo del detector se actualice.
- **Comandos de cierre**:
  - `./tools/ci/run_tests.sh` (todo verde; pega el resumen)
  - `./tools/ci/lint.sh` · `./tools/ci/check_patterns.sh` · `python3 tools/ci/check_scope.py`

## Riesgos y decisiones abiertas
- **Sensación**: el ladrón agachado será notablemente más lento (2,0 frente a 2,75 m/s). Es lo que pide el diseño; se valida jugando antes del cierre.
- **El arco ciego, los puntos de visibilidad y la porra a 1,5 m no están en esta FEAT** (FEAT-008). Mientras tanto, agacharse sigue sin ocultar.
- **`CrouchCollision.has_headroom`** usa un rayo, no un `ShapeCast3D`. Basta para techos; las vigas estrechas se revisarán en FEAT-008 si aparecen en `/level`.
- **Animación del sigilo**: se queda con `sneak_walk`. `stealth.md` permite usar `tiptoe_walk`, pero eso es estético y se decide con los personajes nuevos.
