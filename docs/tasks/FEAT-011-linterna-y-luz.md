# FEAT-011 — Linterna, lámparas y percepción por guardia

- **Estado**: hecha (2026-10-23; decisiones 1–3 según la propuesta)
- **Diseño**: `docs/gdd/systems/stealth.md`, parte 2 (aprobada el 2026-10-23): P2.1, P2.2, P2.3 (solo percepción por guardia), O2 (datos) y O4. Invariantes 13 a 21.
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`

## Objetivo
La parte 2 de sigilo convierte la luz en el eje del juego del guardia: la linterna detecta exactamente lo que dibuja, las lámparas detectan sin linterna y el ladrón puede apagarlas dejando rastro.

Además corrige dos fugas de información del código actual (comprobadas por Claude el 2026-10-23):
- `ThiefController3D.set_stealth_visibility` deja siempre visible al ladrón: un guardia humano lo ve en todo momento.
- `HeistMap3D._process_guards_perception` emite `SignalBus.thief_spotted` en cuanto un guardia cualquiera lo ve, y todas las IA reaccionan. Son avisos implícitos entre IA que el diseño prohíbe.

## Alcance y fuera de alcance
- Dentro:
  - cono horizontal de la linterna con datos en `.tres`;
  - linterna que se apaga y se enciende;
  - entidades `Lamp3D` y `LightSwitch3D`;
  - interruptores y bombillas;
  - detección por luz;
  - percepción por guardia (visibilidad local del ladrón y alertas de la IA);
  - datos de última posición vista (O2);
  - ruidos de porra y captura a `.tres` (O4);
  - acción de input `toggle_flashlight`;
  - lámparas de prueba en `test_isometric_gym.tscn`.
- Fuera:
  - FEAT-012: aspecto de los anillos (P2.4), indicador de exposición (O1) y silueta de última posición vista (la presentación de O2);
  - walkie (ping y voz): va con la red autoritativa;
  - colocar lámparas en el museo y la mansión: va con `/level` y el generador de niveles;
  - cuerda de piano: `gadgets.md`;
  - panel de pilotos (O3): `interaction.md`;
  - red: todo funciona en local y la autoridad del servidor llega con el paquete F;
  - telemetría.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Inv. 13: `flashlight_range > proximity_radius` y `flashlight_half_angle_deg ≤ (360 − rear_blind_arc_deg) / 2`, leídos de `perception_guard.tres` | `test_light_perception.gd::test_inv13_cone_in_front_field` |
| 2 | Inv. 14: la `SpotLight3D` del guardia, tras `_ready`, tiene `spot_range == flashlight_range`, `spot_angle == flashlight_half_angle_deg` y altura local `flashlight_height` | `test_inv14_beam_is_truth` |
| 3 | Inv. 15: ladrón de pie en el eje, fuera de proximidad y sin luz: a `flashlight_range − 0.01` se detecta y a `+ 0.01` no; a `flashlight_half_angle_deg − 0.5°` se detecta y a `+ 0.5°` no | `test_inv15_cone_edges` |
| 4 | Inv. 16: con una cobertura de 1,0 m de alto a 0,3 m del ladrón agachado y el guardia a 3 m, la linterna no lo detecta; de pie, sí | `test_inv16_crouch_hides_from_flashlight` |
| 5 | Linterna apagada: el cono no detecta y la `SpotLight3D` está oculta; cada cambio emite `noise_emitted_3d` con `flashlight_toggle_noise_radius` y equipo `&"guard"` | `test_flashlight_toggle` |
| 6 | Inv. 17: ladrón iluminado por una lámpara encendida, fuera del arco ciego, a `lit_sight_range − 0.01` y con rayo libre, se detecta con la linterna apagada; sin la lámpara, no | `test_inv17_light_detects` |
| 7 | Inv. 18: un punto dentro de `lit_radius` con el rayo desde la bombilla bloqueado no está iluminado | `test_inv18_furniture_casts_shadow` |
| 8 | Inv. 19 y 20, leídos de los `.tres`: `lit_sight_range ≥ flashlight_range`; los tres ruidos ≥ `min_radius` de `step_noise.tres`; `unscrew_time > switch_time`; `unscrew_noise_radius ≤ switch_noise_radius`; `rescrew_time ≥ unscrew_time` | `test_inv19_inv20_light_rules` |
| 9 | Interruptor: tras `switch_time` con el foco mantenido, alterna todas las lámparas de su circuito y emite `switch_noise_radius`; si se pierde el foco antes, no cambia nada ni suena | `test_switch_toggles_circuit` |
| 10 | Bombilla: el ladrón la desenrosca en `unscrew_time` (el ruido suena al empezar); queda apagada aunque se use el interruptor; un guardia la enrosca en `rescrew_time`; solo en tipos con `unscrewable = true`; si el ladrón se interrumpe, sigue encendida | `test_unscrew_and_rescrew` |
| 11 | Inv. 21 (local): con dos guardias, si solo A detecta al ladrón, el ladrón es visible cuando el jugador local es A y no cuando es B; con el ladrón como jugador local, siempre es visible | `test_inv21_per_guard_visibility` |
| 12 | Las IA solo reaccionan a lo que percibe su propio guardia (o a una cámara de seguridad): si A detecta al ladrón, la IA de B no pasa a persecución | `test_ai_not_alerted_by_other_guard` |
| 13 | O2: cuando un guardia deja de percibir al ladrón, `last_seen_position` guarda su última posición y `last_seen_time_left` vale `last_seen_linger` y baja hasta 0 | `test_last_seen_data` |
| 14 | O4: la porra y la captura emiten `baton_swing_noise_radius` y `capture_noise_radius` de `perception_guard.tres`; no quedan constantes de radio en `guard_controller_3d.gd` | `test_o4_noises_from_tres` y `grep -n "NOISE_RADIUS" src/entities/guard/guard_controller_3d.gd` vacío |
| 15 | El guardia mira hacia su objetivo de apuntado (`look_target_position`) aunque se mueva; el ladrón sigue mirando hacia donde camina | `test_guard_faces_aim` |
| 16 | `test_isometric_gym.tscn` tiene una lámpara de techo con su interruptor, una de mesa y una farola, e importa sin errores | `./tools/ci/import.sh` en 0 y revisión de la escena |

## Contratos

### Datos (`data/balance/`)
**`PerceptionProfile`**: se añaden estos campos a `src/entities/components/perception_profile.gd` y `perception_guard.tres`:

| Campo | Tipo | Valor |
|---|---|---|
| `flashlight_range` | float | 9.0 |
| `flashlight_half_angle_deg` | float | 32.0 |
| `flashlight_height` | float | 1.4 |
| `flashlight_toggle_noise_radius` | float | 1.0 |
| `lit_sight_range` | float | 12.0 |
| `last_seen_linger` | float | 1.5 |
| `baton_swing_noise_radius` | float | 4.5 |
| `capture_noise_radius` | float | 8.0 |

**`LampProfile`** (nuevo, `src/systems/lighting/lamp_profile.gd`, `class_name LampProfile extends Resource`):
- `lamp_type: StringName`;
- `lit_radius: float`;
- `has_switch: bool`;
- `unscrewable: bool`;
- `light_color: Color`;
- `light_energy: float`.

Tres recursos:

| Archivo | `lamp_type` | `lit_radius` | `has_switch` | `unscrewable` | `light_color` | `light_energy` |
|---|---|---|---|---|---|---|
| `lamp_ceiling.tres` | `&"ceiling"` | 4.0 | true | false | `Color(1.0, 0.85, 0.6)` | 1.3 |
| `lamp_desk.tres` | `&"desk"` | 2.0 | true | true | `Color(1.0, 0.8, 0.5)` | 1.0 |
| `lamp_street.tres` | `&"street"` | 3.0 | false | false | `Color(0.75, 0.85, 1.0)` | 1.1 |

Los colores y energías no son balance: son los de las `OmniLight3D` que ya hay en `museum_level_builder_3d.gd`.

**`LightRulesProfile`** (nuevo, `src/systems/lighting/light_rules_profile.gd`), con valores en `light_rules.tres`:
- `switch_time` 0.5;
- `switch_noise_radius` 2.0;
- `unscrew_time` 2.0;
- `unscrew_noise_radius` 1.0;
- `rescrew_time` 3.0.

### `PerceptionRules` (se añade)
```gdscript
## Sector horizontal: d_h <= range y ángulo en XZ entre axis y (target - origin) <= half_angle_deg
## (el borde pertenece al cono). Si alguna proyección XZ mide < 0.001, devuelve false.
static func is_in_flashlight_cone(origin: Vector3, axis: Vector3, target: Vector3,
		range_m: float, half_angle_deg: float) -> bool
```

### `LightingRules` (nuevo, `src/systems/lighting/lighting_rules.gd`, `class_name LightingRules extends RefCounted`)
```gdscript
## true si alguna lámpara de `lamps` con is_lit() cumple horizontal_distance(lamp, point) <= lit_radius
## y el rayo (máscara 1) desde lamp.global_position hasta point está libre
static func is_point_lit(space: PhysicsDirectSpaceState3D, point: Vector3, lamps: Array[Lamp3D]) -> bool
```

### `Lamp3D` (nuevo)
- Archivos: `src/systems/lighting/lamp_3d.gd` y `scenes/entities/lamp.tscn`.
- Nodos: raíz `Node3D` (`class_name Lamp3D`), con hijos `Visuals` (`OmniLight3D` llamado `Bulb`) y `Sensors` (`Area3D` llamado `InteractionArea`).
  - La raíz está en la posición de la bombilla y en el grupo `&"lamps"`.
  - No tiene colisión en la capa 1, para no bloquear sus propios rayos.
  - `InteractionArea`: capa 4, máscara 0, con una `BoxShape3D` de 0,6 × 3,0 × 0,6 m centrada 1,5 m por debajo de la raíz, para que el rayo del `Interactor3D` (a la altura de los pies) la alcance.
- `@export var profile: LampProfile`, `@export var circuit_id: int = 0` y `@export var start_on: bool = true`.
- Estado:
  - `is_switched_on: bool`;
  - `is_unscrewed: bool`;
  - `func is_lit() -> bool` devuelve `is_switched_on and not is_unscrewed`;
  - `func set_switched(on: bool) -> void`;
  - señal `lit_changed(is_lit: bool)`.
- `Bulb.omni_range = profile.lit_radius`; `Bulb.visible = is_lit()`.
- Interacción (solo si `profile.unscrewable`). `can_interact(actor)`:
  - el ladrón puede si `not is_unscrewed`;
  - un guardia puede si `is_unscrewed`.
- `interact(actor)` empieza un trabajo:
  - ladrón: `unscrew_time`, y el ruido `unscrew_noise_radius` suena al empezar;
  - guardia: `rescrew_time`, sin ruido.
- El trabajo termina en `_physics_process` si el `interactor.current_target` del actor sigue siendo esta lámpara durante todo el tiempo; si lo pierde, se cancela.
- `get_interaction_text(actor)`: `"Desenroscar bombilla"` o `"Enroscar bombilla"`.
- **Añadido tras la revisión de PKG-1**:
  - el `InteractionArea` lleva su propio script, `src/systems/lighting/lamp_interaction_area.gd` (`class_name LampInteractionArea extends Area3D`), con `@export var lamp: Lamp3D` y `can_interact`, `interact` y `get_interaction_text` tipados, que delegan en `lamp`; está asignado en `lamp.tscn`, y nunca se compila código desde un texto;
  - si el perfil no es `unscrewable`, `InteractionArea.collision_layer = 0`, para no tapar otros interactuables;
  - el acceso a `actor.interactor` se hace con un cast a `ThiefController3D` o `GuardController3D`.

### `LightSwitch3D` (nuevo)
- Archivos: `src/systems/lighting/light_switch_3d.gd` y `scenes/entities/light_switch.tscn`.
- Raíz `StaticBody3D` en la capa 4 con su `CollisionShape3D` (caja de 0,6 × 2,0 × 0,6 m, de la altura de los pies a 2 m) y `@export var circuit_id: int = 0`.
- `can_interact` es true para ladrón y guardia.
- `interact(actor)` empieza un trabajo de `switch_time` con la misma regla de foco. Al terminar:
  - emite `noise_emitted_3d(global_position, switch_noise_radius, actor.team_id)`;
  - alterna todas las `Lamp3D` del grupo `&"lamps"` con ese `circuit_id` y `profile.has_switch == true` (añadido tras la revisión: una farola nunca se apaga por interruptor). Si alguna tenía `is_switched_on`, que es el estado del circuito y no `is_lit()`, apaga todas; si no, enciende todas.
- `get_interaction_text`: `"Interruptor"`.

### `GuardController3D`
- **Linterna**:
  - `var flashlight_on: bool = true` y `func set_flashlight(on: bool) -> void`, que emite el ruido del criterio 5 y oculta o muestra `maglite_light`;
  - la acción `toggle_flashlight` (si existe en `InputMap`) la alterna en `_process_local_actions`.
- **`_ready`**:
  - `maglite_light.spot_range = perception.flashlight_range`;
  - `maglite_light.spot_angle = perception.flashlight_half_angle_deg`;
  - `maglite_light.position = Vector3(0, perception.flashlight_height, -0.4)`.
- **Orientación**: el guardia mira siempre hacia `look_target_position` (proyectado en XZ), salvo que esté a menos de 0,1 m; entonces mira hacia su velocidad. El eje del cono es `-global_basis.z` proyectado en XZ.
- **Detección**: se mueve a un componente nuevo, para que `guard_controller_3d.gd` no pase de 300 líneas:
  - archivo `src/entities/guard/guard_senses.gd`, `class_name GuardSenses extends RefCounted`;
  - método `func detects(guard: GuardController3D, thief: ThiefController3D, lamps: Array[Lamp3D]) -> StringName`;
  - devuelve `&"proximity"`, `&"cone"`, `&"light"` o `&""`, evaluando en ese orden:
    - **proximidad**: como hoy;
    - **cono**: `flashlight_on`, `is_in_flashlight_cone(guard_pos, eje, thief_pos, flashlight_range, flashlight_half_angle_deg)` y rayo libre desde `guard_pos + (0, flashlight_height, 0)` hasta algún punto de visibilidad;
    - **luz**: algún punto de visibilidad iluminado (`LightingRules.is_point_lit`), el centro del ladrón fuera del arco ciego, `horizontal_distance ≤ lit_sight_range` y rayo libre desde los ojos hasta ese mismo punto.
  - `check_detection_on_thief(thief)` se mantiene y devuelve `detects(...) != &""`, con las lámparas del grupo `&"lamps"`.
- **O2**:
  - `var is_perceiving_thief: bool`, `var last_seen_position: Vector3` y `var last_seen_time_left: float`;
  - `func update_perception(thief: ThiefController3D, lamps: Array[Lamp3D], delta: float) -> void` los actualiza;
  - emite la señal propia `thief_perceived(position: Vector3)` cada tick en que percibe.
- **O4**: se borran `BATON_SWING_NOISE_RADIUS` y `CAPTURE_NOISE_RADIUS`, y se usan los campos del perfil.

### `HeistMap3D`
- `_process_guards_perception(delta)`: llama a `guard.update_perception(thief, lamps, delta)` para cada guardia y ya no emite `SignalBus.thief_spotted`.
- Visibilidad local del ladrón:
  - `thief.set_visible_to_local_viewer(v)` con `v = local_player == thief or (local_player is GuardController3D and local_player.is_perceiving_thief)`;
  - se recalcula también al cambiar de personaje (F1–F5).
- `thief.is_detected_by_guard` sigue siendo "algún guardia lo percibe", para la red futura.

### `ThiefController3D`
- `set_stealth_visibility(is_visible_to_guards)` se mantiene para `is_detected_by_guard`, sin tocar `visual_root`.
- Nuevo `set_visible_to_local_viewer(v: bool)`, que pone `visual_root.visible = v`.

### `GuardAI3D`
- Se conecta a `thief_perceived` de su propio guardia para pasar a persecución.
- Sigue escuchando `SignalBus.thief_spotted`, que ahora solo emiten las cámaras de seguridad.

### Input (`project.godot`)
Acción `toggle_flashlight`, tecla F.

### `test_isometric_gym.tscn`
Instancias, en zonas libres del gimnasio:
- `lamp.tscn` con `lamp_ceiling.tres` (`circuit_id = 1`, altura 2,8 m) y un `light_switch.tscn` con `circuit_id = 1` en un muro, a menos de 6 m;
- `lamp.tscn` con `lamp_desk.tres` (`circuit_id = 2`) a 1,0 m de altura;
- `lamp.tscn` con `lamp_street.tres` (`circuit_id = 3`) a 3,0 m.

Las posiciones las elige el paquete dentro de los límites del gimnasio y las anota en su entrega.

## Assets necesarios
Ninguno: las lámparas son luces sin modelo. El aspecto (pantalla, flexo) llegará con `/level` y FEAT-010 o posteriores.

## Impacto en red
- Ninguno en esta FEAT: todo es local y el servidor no decide nada nuevo.
- El paquete F de la auditoría hará autoritativos `GuardSenses`, el estado de `Lamp3D` y `flashlight_on`. Se replicarán a todos, y la posición del ladrón solo al cliente del guardia que lo percibe.
- Los contratos están pensados para eso: `detects` es puro respecto al estado de la escena, y `set_visible_to_local_viewer` es solo presentación.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | gameplay-engineer | `feat/011-pkg1` | — | integrado | 1 | `bloqueado` previsto: el test de FEAT-005 espera la Maglite a 0,9 m; lo adapta en la vuelta 1 |
| PKG-2 | integrator | `feat/011-pkg2` | — | integrado | 0 | |
| PKG-QA | qa-engineer | `feat/011-pkgqa` | PKG-1, PKG-2 | integrado | 1 | |

## Paquetes de ejecución

### PKG-1 — Linterna, lámparas y percepción por guardia
- **Agente / rama**: `gameplay-engineer` / `feat/011-pkg1`
- **Archivos permitidos**:
  ```allowed
  src/entities/components/perception_profile.gd
  src/entities/components/perception_rules.gd
  src/entities/guard/guard_controller_3d.gd
  src/entities/guard/guard_senses.gd
  src/entities/guard/guard_senses.gd.uid
  src/entities/guard/guard_ai_3d.gd
  src/entities/thief/thief_controller_3d.gd
  src/maps/heist_map_3d.gd
  src/systems/lighting/lamp_profile.gd
  src/systems/lighting/lamp_profile.gd.uid
  src/systems/lighting/light_rules_profile.gd
  src/systems/lighting/light_rules_profile.gd.uid
  src/systems/lighting/lighting_rules.gd
  src/systems/lighting/lighting_rules.gd.uid
  src/systems/lighting/lamp_3d.gd
  src/systems/lighting/lamp_3d.gd.uid
  src/systems/lighting/lamp_interaction_area.gd
  src/systems/lighting/lamp_interaction_area.gd.uid
  src/systems/lighting/light_switch_3d.gd
  src/systems/lighting/light_switch_3d.gd.uid
  scenes/entities/lamp.tscn
  scenes/entities/light_switch.tscn
  scenes/entities/guard_player.tscn
  data/balance/perception_guard.tres  # excepción: campos nuevos aprobados en stealth.md parte 2
  data/balance/lamp_ceiling.tres  # excepción: valores de stealth.md parte 2
  data/balance/lamp_desk.tres  # excepción: valores de stealth.md parte 2
  data/balance/lamp_street.tres  # excepción: valores de stealth.md parte 2
  data/balance/light_rules.tres  # excepción: valores de stealth.md parte 2
  scenes/maps/test_isometric_gym.tscn  # excepción: lámparas de prueba que pide esta FEAT
  tests/unit/test_stealth_mechanics.gd  # excepción: la altura esperada de la Maglite pasa de 0,9 a `flashlight_height` de perception_guard.tres
  ```
- **Contratos y valores**: los de esta spec. No inventes números: si falta uno, entrega `bloqueado`.
- **`guard_player.tscn`**: solo la `transform` de `MagliteSpotLight` (altura 1,4); `spot_range` y `spot_angle` los fija el código.
- **Tests**: ninguno de aceptación (los escribe PKG-QA). Los tests existentes deben seguir en verde. Si alguno dependía de que el ladrón fuera siempre visible o de `thief_spotted` desde el mapa, entrega `bloqueado` con la salida. Excepción: en `test_stealth_mechanics.gd::test_criterio_1_guard_scene_model_and_anchors`, la altura esperada de la Maglite se lee de `perception_guard.tres` (`flashlight_height`) en lugar de 0,9; nada más de ese archivo cambia.
- **Comandos de cierre**: `./tools/ci/import.sh` · `./tools/ci/check_scripts.sh` · `./tools/ci/lint.sh` · `./tools/ci/check_patterns.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh`.
- **Fuera de alcance**:
  - anillos, HUD y silueta de O2;
  - walkie;
  - red;
  - las `OmniLight3D` decorativas del museo y la mansión;
  - `project.godot`.

### PKG-2 — Acción de input
- **Agente / rama**: `integrator` / `feat/011-pkg2`
- **Archivos permitidos**:
  ```allowed
  project.godot
  ```
- **Cambio**: acción `toggle_flashlight` con la tecla F (`physical_keycode` 70), con el mismo formato que `crouch`.
- **Comandos de cierre**: `./tools/ci/import.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh`.

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/011-pkgqa` (sale de `master` con PKG-1 y PKG-2 integrados)
- **Archivos permitidos**:
  ```allowed
  tests/unit/test_light_perception.gd
  tests/unit/test_light_perception.gd.uid
  tests/unit/test_lamps.gd
  tests/unit/test_lamps.gd.uid
  tests/unit/test_per_guard_perception.gd
  tests/unit/test_per_guard_perception.gd.uid
  ```
- **Tests obligatorios**:
  - Los nombres de la columna "Evidencia" de los criterios 1 a 15, repartidos así:
    - linterna y luz → `test_light_perception.gd`;
    - interruptor y bombilla → `test_lamps.gd`;
    - criterios 11 a 13 → `test_per_guard_perception.gd`.
  - Cada invariante lee sus valores de los `.tres` y no repite literales.
  - Geometría fija en el test (posiciones elegidas para el caso), nunca derivada de un valor de balance, salvo los bordes del criterio 3.
  - Sin la `SpotLight3D` como fuente de la verdad: el criterio 3 debe fallar si `GuardSenses` usa el ángulo 3D del foco en lugar del sector horizontal. Comprueba ese caso con el foco inclinado hacia el suelo.
- **Montaje**:
  - `./tools/ci/import.sh` primero;
  - `position` antes de `add_child_autofree`;
  - personajes al árbol antes de usar sus perfiles;
  - `set_physics_process(false)` si simulas a mano;
  - ninguna pieza de escenario solapada con una cápsula;
  - las coberturas son `StaticBody3D` en la capa 1;
  - lámparas: `lamp.tscn` con su perfil.
- **Comandos de cierre**: los de PKG-1.

## Cierre (2026-10-23)
- **`/verify` en `master` (`3070c02`)**: import y check_scripts en 0, run_tests 115/115, run_blender_tests 46/46.
- **Criterios**:
  - 1 a 15: `test_light_perception.gd`, `test_lamps.gd` y `test_per_guard_perception.gd`;
  - 16: escena del gimnasio e import en 0;
  - el usuario confirmó jugando que la linterna funciona con el guardia (F2 y F).
- **PR**:
  - #26: PKG-2;
  - #29: PKG-1, con una vuelta;
  - #38: PKG-QA, con una vuelta;
  - #27, #28 y #36: ajustes de spec.
- **Mutation testing del revisor**: de 17 mutaciones sobreviven 1. Es el `<` en el borde exacto del ángulo, que se acepta por precisión de coma flotante.
- **Lecciones**:
  - `set_physics_process(false)` va después de `add_child` (ya en `_TEMPLATE.md`);
  - un paquete que cambia un contrato adapta los tests existentes que lo comprueban;
  - en la spec, los títulos de contrato no pueden empezar por `### PKG-N`.
- **Riesgo aceptado por el usuario**: en red, los guardias de clientes remotos no ven al ladrón hasta el paquete F (red autoritativa).
- **Pendiente**:
  - lámparas en el museo y la mansión (con `/level`);
  - animación de sujetar la linterna (FEAT de personajes);
  - `test_light_perception.gd` está en 298 líneas, así que los tests nuevos de linterna van en otro archivo;
  - la interpolación de red está duplicada en `GuardController3D`.

## Riesgos y decisiones abiertas
1. **Orientación del guardia.** Hoy mira hacia donde camina y la linterna apunta al cursor, de modo que el haz puede apuntar hacia atrás mientras anda y meterse en su arco ciego. Propuesta: el guardia mira siempre hacia el cursor (postura de apuntar, criterio 15) y el eje del cono es su frente, como pide P2.1. La alternativa es que el cono siga al cursor con independencia del cuerpo, pero entonces el arco ciego deja de estar "detrás de la linterna".
2. **Lámparas de prueba en `test_isometric_gym.tscn`.** Es un mapa tuyo. Sin lámparas en ningún mapa la mecánica no se puede probar jugando. Propuesta: una excepción para añadir tres lámparas y un interruptor solo en el gimnasio. El museo y la mansión, con `/level`.
3. **La IA deja de avisarse sola.** Es lo que pide el diseño ("sin pings implícitos entre IA"). En la práctica, los guardias de IA serán menos eficaces hasta que exista el walkie.
4. **El ladrón deja de verse en la pantalla del guardia** salvo cuando ese guardia lo percibe. Es el cambio más grande en la sensación de juego desde FEAT-005. Conviene probarlo jugando nada más integrarlo.
