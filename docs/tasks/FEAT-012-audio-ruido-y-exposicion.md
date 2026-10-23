# FEAT-012 — Audio de ruido, vúmetro e indicador de exposición

- **Estado**: aprobada (reescrita y aprobada el 2026-10-23)
- **Diseño**: `docs/gdd/systems/stealth.md` parte 2 (aprobada; P2.4 reescrita el 2026-10-23): P2.4 (cómo se percibe un ruido), O1 (exposición), O2 (última posición vista), D8–D11. Invariantes 11, 21, 22 y 24. Pilar 3 de `docs/gdd/pillars.md` ("ve linternas y oye más lejos").
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`

## Historia
La primera versión de esta FEAT ("Anillos de ruido radar de 1984") construyó anillos 3D (PR #40). Al verlos, el usuario los rechazó: "quita los anillos no me gusta quizas algun sonido de pasos sutil mejor o algun aviso de ruido un medidor pequeños en el hud". El PR #40 se cerró sin integrar; la rama `feat/012-pkg3` se conserva hasta el cierre de la FEAT porque PKG-5 rescata de ella el HUD de exposición, el chevron y la silueta. PKG-1 (señal `noise_event_3d`) ya está integrado y sigue valiendo.

## Objetivo
Sustituir los anillos por lo que aprobó el usuario:
- audio posicional: un ruido suena solo a quien alcanza, más fuerte cuanto más cerca;
- pasos propios sutiles;
- vúmetro pequeño de ruido en el HUD del ladrón;
- chevron en el borde para golpes y mecanismos fuera de pantalla;
- el ladrón oye los ruidos de guardia a 1,5 × su radio.

Se mantienen el indicador de exposición (O1) y la silueta de última posición vista (O2).

## Alcance y fuera de alcance
- Dentro:
  - categoría y emisor en cada ruido (`NoiseEmit`);
  - reglas de alcance y ganancia (`PerceptionRules.noise_reaches`, `NoiseAudioRules`);
  - 25 muestras CC0 de Kenney y su mezcla;
  - presentador de audio, vúmetro y chevron;
  - indicador de exposición y silueta;
  - borrado de `SoundWave3D` y su shader.
- Fuera:
  - muestras propias para caja fuerte, coche, reloj de fichar y walkie: de momento usan la familia "mecanismo";
  - fuentes sostenidas con pulsos (`pulse_interval`): aún no hay ninguna; la alarma del reloj de fichar sigue siendo una emisión;
  - subtítulos de accesibilidad;
  - música y buses de audio;
  - red: todo es presentación local; el paquete F decidirá qué ruidos recibe cada cliente;
  - IA: sigue oyendo por `noise_emitted_3d` sin cambios.

## Valores
**`data/balance/noise_feedback.tres`** (tabla "Números (parte 2)" de `stealth.md`):

| Campo | Valor |
|---|---|
| `pulse_interval` | 0.6 |
| `meter_full_scale` | 10.0 |
| `meter_hold_time` | 0.15 |
| `meter_fall_time` | 0.4 |
| `audio_edge_floor` | 0.2 |
| `own_step_volume_db` | -22.0 |
| `pitch_jitter` | 0.06 |
| `thief_hearing_mult` | 1.5 |
| `offscreen_marker_time` | 2.0 |

**`assets/audio/noise_mix.tres`** (mezcla, no balance; P2.4):

| Campo | Valor |
|---|---|
| `step_db` | -14.0 |
| `impact_db` | -6.0 |
| `mechanism_db` | -10.0 |
| `soft_surface_max` | 0.7 (multiplicador de suelo ≤ este valor → `step_soft`) |
| `hard_surface_min` | 1.3 (multiplicador ≥ este valor → `step_hard`; entre ambos, `step_wood`) |
| `step_soft` | `footstep_carpet_000`…`004` |
| `step_wood` | `footstep_wood_000`…`004` |
| `step_hard` | `footstep_concrete_000`…`004` |
| `impact` | `impact_punch_000`…`004` |
| `mechanism` | `switch_001`…`005` |

Los suelos no tienen identificador de superficie, solo `metadata/noise_multiplier`, así que la familia de pasos se elige por umbrales de ese multiplicador. En el museo, las salas a 0,4 y 0,6 suenan a alfombra, las de 1,0 a 1,2 a parqué y las de 1,4 a 1,6 a mármol.

**Paleta del HUD** (`assets/ui/hud_palette.tres`, sustituye a `noise_ring_style.tres`):

| Campo | Valor |
|---|---|
| `color_own` | `#F2B84B` |
| `color_guard` | `#4FC3F7` |
| `color_other` | `#B8E6C1` |
| `color_meter_low` | `#B8E6C1` (segmentos 1–7) |
| `color_meter_mid` | `#F2B84B` (segmentos 8–9) |
| `color_meter_high` | `#FF6B5A` (segmento 10 y LED de saturación) |

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Cada ruido lleva categoría (`&"step"`, `&"impact"` o `&"mechanism"`) y emisor según la tabla de emisores | `test_noise_categories.gd::test_each_emitter_category` |
| 2 | Inv. 24: con un ruido de radio `r`, el oyente local a `r − 0.01` recibe exactamente un `AudioStreamPlayer3D` en el grupo `&"noise_audio"` y a `r + 0.01` ninguno | `test_noise_audio.gd::test_inv24_audio_iff_reaches` |
| 3 | D8: con el ladrón local, un ruido de equipo `&"guard"` suena hasta `r × thief_hearing_mult`; con un guardia local, un ruido del ladrón suena solo hasta `r` | `test_noise_audio.gd::test_thief_hearing_mult` |
| 4 | Ganancia: `NoiseAudioRules.gain(d, r, f)` vale 1 en `d = 0`, `f` en `d = r`, 0.5429 ± 0.001 en `d = 3, r = 5.25, f = 0.2` y 0 en `d > r`. El reproductor creado tiene `attenuation_model = ATTENUATION_DISABLED` y `volume_db = v_cat + linear_to_db(g)` (± 0.01) | `test_noise_audio.gd::test_gain_formula` |
| 5 | Ruido propio (emisor = jugador local): `AudioStreamPlayer` sin posición. En un paso, `volume_db = own_step_volume_db + linear_to_db(clamp(r / meter_full_scale, 0.05, 1.0))`; en golpe o mecanismo, `v_cat`. `pitch_scale` en `[1 − pitch_jitter, 1 + pitch_jitter]` | `test_noise_audio.gd::test_own_noise_audio` |
| 6 | Familia de pasos: con suelo de multiplicador 0.4, el `stream` está en `step_soft`; con 1.0, en `step_wood`; con 1.6, en `step_hard` | `test_noise_audio.gd::test_step_surface_family` |
| 7 | Inv. 22: `meter_hold_time + meter_fall_time ≤ step_interval_sneak` y `≤ step_interval_crouch` de `movement_thief.tres`, y `meter_full_scale ≥ min_radius × 10` (`step_noise.tres`) | `test_noise_meter.gd::test_inv22_meter_rhythm` |
| 8 | Vúmetro: con el ladrón local, un ruido propio de radio 3.5 deja el nivel en 3.5 y 4 segmentos encendidos; sigue igual a los `meter_hold_time`, vale 0 tras `hold + fall`, y a mitad de la caída vale 1.75 ± 0.05. Un radio de 10.5 enciende el LED de saturación. Los ruidos de guardia no lo mueven. Con un guardia local, el vúmetro está oculto | `test_noise_meter.gd::test_meter_dynamics` |
| 9 | Chevron: un golpe o mecanismo que alcanza al local con el origen fuera del frustum muestra un chevron durante `offscreen_marker_time`; un paso en la misma situación no; un origen dentro de pantalla no | `test_noise_audio.gd::test_offscreen_marker` |
| 10 | O1: con el ladrón local, el HUD muestra `shadow`, `lit` o `beam` con prioridad `beam` > `lit` > `shadow`, con las reglas de `GuardSenses`; con otro jugador local, `&""` | `test_local_view.gd::test_thief_exposure` |
| 11 | O2: con un guardia local que deja de percibir al ladrón, aparece la silueta en `last_seen_position` y desaparece cuando `last_seen_time_left` llega a 0 | `test_local_view.gd::test_last_seen_marker` |
| 12 | No quedan anillos: no existen `src/vfx/sound_wave_3d.gd` ni `assets/shaders/sound_wave_3d.gdshader`, y ningún nodo de la escena de mapa tiene un `MeshInstance3D` creado por un ruido | `test_noise_audio.gd::test_no_noise_rings` |
| 13 | Las 25 muestras existen, cargan como `AudioStream` y están en `assets/audio/CREDITS.md` con origen y licencia CC0 | `test_noise_audio.gd::test_noise_mix_streams` |
| 14 | Al jugarlo, los pasos propios se oyen flojos y el vúmetro se lee de un vistazo | Captura del HUD que hace el planificador y aprobación del usuario |

## Contratos

### Contrato de PKG-1 (integrado): `core/signal_bus.gd`
```gdscript
## Ruido con categoría y emisor; noise_emitted_3d se sigue emitiendo para quien ya lo escucha
signal noise_event_3d(world_position: Vector3, radius: float, source_team: StringName,
		category: StringName, emitter: Node)
```

### Contrato de PKG-4: muestras
Desde los paquetes CC0 de Kenney (los zips se comprueban por SHA-256):

| Paquete | SHA-256 |
|---|---|
| `kenney_impact-sounds.zip` | `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8` |
| `kenney_interface-sounds.zip` | `f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232` |

| Destino en `assets/audio/sfx/` | Origen en el zip |
|---|---|
| `step_carpet/footstep_carpet_000.ogg` … `_004.ogg` | impact-sounds `Audio/footstep_carpet_000.ogg` … `_004.ogg` |
| `step_wood/footstep_wood_000.ogg` … `_004.ogg` | impact-sounds `Audio/footstep_wood_000.ogg` … `_004.ogg` |
| `step_hard/footstep_concrete_000.ogg` … `_004.ogg` | impact-sounds `Audio/footstep_concrete_000.ogg` … `_004.ogg` |
| `impact/impact_punch_000.ogg` … `_004.ogg` | impact-sounds `Audio/impactPunch_medium_000.ogg` … `_004.ogg` |
| `mechanism/switch_001.ogg` … `_005.ogg` | interface-sounds `Audio/switch_001.ogg` … `_005.ogg` |

`assets/audio/CREDITS.md` lista cada carpeta con su origen, URL del paquete, licencia CC0 y SHA-256 del zip.

### Contrato de PKG-5: presentación (`vfx-ui-engineer`)
- **`NoiseMix`** (`src/vfx/noise_mix.gd`, `class_name NoiseMix extends Resource`):
  ```gdscript
  @export var step_db: float = -14.0
  @export var impact_db: float = -6.0
  @export var mechanism_db: float = -10.0
  @export var soft_surface_max: float = 0.7
  @export var hard_surface_min: float = 1.3
  @export var step_soft: Array[AudioStream] = []
  @export var step_wood: Array[AudioStream] = []
  @export var step_hard: Array[AudioStream] = []
  @export var impact: Array[AudioStream] = []
  @export var mechanism: Array[AudioStream] = []
  ## dB base de la categoría; 0.0 si la categoría no existe
  func category_db(category: StringName) -> float
  ## Familia de muestras: step según surface_mult y los umbrales; impact; mechanism; [] si no existe
  func streams_for(category: StringName, surface_mult: float) -> Array[AudioStream]
  ```
  Valores en `assets/audio/noise_mix.tres` (tabla "Valores").
- **`HudPalette`** (`src/ui/hud_palette.gd`, `class_name HudPalette extends Resource`): los seis `@export var color_*: Color` de la tabla "Paleta del HUD". Vive en `assets/ui/hud_palette.tres`.
- **`NoiseMeter84`** (`src/ui/noise_meter_84.gd`, `class_name NoiseMeter84 extends Control`):
  ```gdscript
  const SEGMENTS: int = 10
  func configure(full_scale: float, hold_time: float, fall_time: float, mark_radius: float) -> void
  ## Nuevo pico: level = max(level, radius) y reinicia la retención
  func push(radius: float) -> void
  func get_level() -> float          # metros que muestra ahora
  func lit_segments() -> int         # ceil(min(level, full_scale) / full_scale × SEGMENTS)
  func is_over() -> bool             # level > full_scale
  ```
  - Dinámica en `_process`: tras `hold_time` sin pico nuevo, el nivel baja de forma lineal desde el pico hasta 0 en `fall_time`.
  - Dibujo (`_draw`):
    - tamaño mínimo 120 × 14 px;
    - 10 segmentos con 2 px de separación, más un LED de saturación de 8 × 14 px a la derecha;
    - colores de `HudPalette`: encendido al 100 %, apagado al 15 %;
    - una marca vertical de 1 px en blanco al 60 % en `mark_radius / full_scale` del ancho;
    - rótulo "RUIDO" a la izquierda, con la fuente del HUD.
- **`HUD84`** (rescate de `feat/012-pkg3`):
  - `set_exposure(state: StringName)` y `show_offscreen_noise(world_pos: Vector3, lifetime: float, role: StringName)`, tal como están en esa rama, cambiando `NoiseRingStyle` por `HudPalette`;
  - `func get_noise_meter() -> NoiseMeter84`;
  - `func set_noise_meter_visible(visible: bool) -> void`;
  - el vúmetro va dentro de `ExposurePanel`, debajo del texto de exposición, en un único bloque;
  - `ExposurePanel` se muestra si hay estado de exposición o el vúmetro es visible.
  - Para no pasar de 300 líneas, la clase interna del chevron sale a `src/ui/offscreen_chevron_84.gd` (`class_name OffscreenChevron84 extends Control`) sin cambiar su comportamiento.
- **`LastSeenMarker3D`** (`src/vfx/last_seen_marker_3d.gd`): se rescata tal cual de `feat/012-pkg3`, con `color_other` leído de `HudPalette`.

### Contrato de PKG-2: reglas, emisión y presentadores (`gameplay-engineer`)
**`NoiseEmit`** (`src/systems/noise/noise_emit.gd`):
```gdscript
class_name NoiseEmit extends RefCounted
const STEP: StringName = &"step"
const IMPACT: StringName = &"impact"
const MECHANISM: StringName = &"mechanism"
## Emite noise_emitted_3d(pos, radius, team) y después noise_event_3d(pos, radius, team, category, emitter)
static func emit(pos: Vector3, radius: float, team: StringName, category: StringName, emitter: Node) -> void
```

Tabla de emisores (todos pasan a `NoiseEmit.emit`):

| Emisor | Categoría | `emitter` |
|---|---|---|
| `player_base_3d.gd` (paso) | step | `self` |
| `guard_controller_3d.gd` (porra, captura) | impact | `self` |
| `guard_controller_3d.gd` (clic de linterna) | mechanism | `self` |
| `loot_item_3d.gd` (2,5 y 3,5 m) | impact | el ladrón que lo coge o lo deja |
| `safe_box_3d.gd` | mechanism | el ladrón activo, o `self` si no lo hay |
| `escape_car_3d.gd` | mechanism | `self` |
| `time_clock_3d.gd` (fichar y alarma) | mechanism | el guardia que ficha, o `self` en la alarma |
| `lamp_3d.gd` (desenroscar) | mechanism | el actor |
| `light_switch_3d.gd` | mechanism | el actor |

**`NoiseFeedbackProfile`** (`src/systems/noise/noise_feedback_profile.gd`, `class_name NoiseFeedbackProfile extends Resource`): un `@export var` `float` por cada campo de la tabla `noise_feedback.tres`, con esos valores por defecto. Valores en `data/balance/noise_feedback.tres`.

**`PerceptionRules.noise_reaches`** (sustituye a `ring_visible_to`, en `src/entities/components/perception_rules.gd`):
```gdscript
## false si listener es null. r_ef = radius × thief_hearing_mult si listener.team_id == &"thief"
## y source_team == &"guard"; si no, radius. true si horizontal_distance(listener, origin) <= r_ef
static func noise_reaches(listener: PlayerBase3D, origin: Vector3, radius: float,
		source_team: StringName, thief_hearing_mult: float) -> bool
## r_ef de la regla anterior (para la ganancia)
static func effective_radius(listener: PlayerBase3D, radius: float, source_team: StringName,
		thief_hearing_mult: float) -> float
```

**`NoiseAudioRules`** (`src/systems/noise/noise_audio_rules.gd`):
```gdscript
class_name NoiseAudioRules extends RefCounted
## f + (1 - f) × (1 - d / r) si d <= r y r > 0; 0.0 en otro caso
static func gain(d: float, r: float, edge_floor: float) -> float
```

**`ThiefExposure`** (`src/systems/lighting/thief_exposure.gd`):
```gdscript
class_name ThiefExposure extends RefCounted
## &"beam" si algún guardia con flashlight_on lo tiene en el cono con rayo libre desde
## flashlight_height a algún punto de visibilidad; si no, &"lit" si algún punto está iluminado
## (LightingRules.is_point_lit); si no, &"shadow"
static func compute(thief: ThiefController3D, guards: Array[GuardController3D], lamps: Array[Lamp3D]) -> StringName
```

Para no duplicar reglas, `GuardSenses` expone dos funciones que `detects` reutiliza:
- `func cone_sees(guard, thief) -> bool`;
- `func light_point_lit(thief, lamps) -> bool`, la parte de iluminación sin el arco ciego del guardia.

**`NoiseAudioPresenter`** (`src/maps/noise_audio_presenter.gd`, `class_name NoiseAudioPresenter extends Node`):
```gdscript
var rng: RandomNumberGenerator = RandomNumberGenerator.new()  # los tests fijan la semilla
func setup(map: HeistMap3D, feedback: NoiseFeedbackProfile, mix: NoiseMix) -> void
```
- Crea un `AudioListener3D` hijo. En cada `_physics_process`, si `map.local_player` no es null:
  - pone su transformación en `Transform3D(map.camera.global_basis, map.local_player.global_position)`;
  - lo hace actual con `make_current()`.
- Escucha `SignalBus.noise_event_3d`. Por cada ruido con `radius > 0`, siendo `local = map.local_player`:
  1. Si `local` es null, no hace nada.
  2. Si el ladrón es el jugador local (`local == map.thief`) y `source_team == &"thief"`, llama a `hud.get_noise_meter().push(radius)`.
  3. Si `emitter == local` (ruido propio), crea un `AudioStreamPlayer`:
     - `volume_db`: en un paso, `own_step_volume_db + linear_to_db(clamp(radius / meter_full_scale, 0.05, 1.0))`; en golpe o mecanismo, `mix.category_db(category)`;
     - termina en el paso 6.
  4. Si `not PerceptionRules.noise_reaches(local, pos, radius, source_team, thief_hearing_mult)`, no hace nada más.
  5. Si no, crea un `AudioStreamPlayer3D`:
     - `global_position = pos`;
     - `attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED`;
     - `max_distance = 0.0`;
     - `volume_db = mix.category_db(category) + linear_to_db(NoiseAudioRules.gain(d, r_ef, audio_edge_floor))`, con `d` la distancia horizontal y `r_ef = PerceptionRules.effective_radius(...)`.

     Si `category != &"step"` y `not map.camera.is_position_in_frustum(pos)`, llama a `hud.show_offscreen_noise(pos, offscreen_marker_time, role)`, con `role = &"guard"` si el ladrón es el jugador local y `source_team == &"guard"`, y `&"other"` en otro caso.
  6. Para el reproductor creado:
     - `stream`: elemento al azar (`rng`) de `mix.streams_for(category, m)`. `m` es `emitter.surface_detector.get_surface_noise_multiplier()` si `emitter` es `PlayerBase3D` con `surface_detector`; si no, 1.0;
     - `pitch_scale = 1.0 + rng.randf_range(-pitch_jitter, pitch_jitter)`;
     - se añade como hijo del presentador, en el grupo `&"noise_audio"`;
     - `play()`, y `queue_free` al recibir `finished`.

     Si la familia está vacía, no crea nada.
- Al cambiar `map.local_player`, en cada `_physics_process` llama a `hud.set_noise_meter_visible(map.local_player == map.thief and map.thief != null)`.

**`LocalViewPresenter`** (`src/maps/local_view_presenter.gd`, `class_name LocalViewPresenter extends Node`, `func setup(map: HeistMap3D) -> void`):
- En cada `_physics_process`, si el ladrón es el jugador local, llama a `hud.set_exposure(ThiefExposure.compute(map.thief, map.guards, lamps))`, con las lámparas del grupo `&"lamps"`. En otro caso, `hud.set_exposure(&"")`.
- Gestiona un `LastSeenMarker3D` para el guardia local:
  - `show_at(guard.last_seen_position, guard.last_seen_time_left)` cuando pasa de percibir a no percibir (`last_seen_time_left > 0`);
  - `hide_marker()` cuando llega a 0 o cambia el jugador local.

**`HeistMap3D`**:
- En `_ready`, crea los dos presentadores y les llama a `setup`, con `preload` de `data/balance/noise_feedback.tres` y `assets/audio/noise_mix.tres`.
- Borra `_on_noise_emitted` y su conexión a `noise_emitted_3d`.

## Impacto en red
Ninguno: es presentación local. `noise_event_3d` es local; la red autoritativa decidirá en el paquete F qué ruidos recibe cada cliente. Mientras tanto, en red cada cliente decide con su posición local, como ya pasaba con los anillos.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | integrator | `feat/012-pkg1` | — | integrado | 0 | |
| PKG-3 | vfx-ui-engineer | `feat/012-pkg3` | — | descartado | 2 | Anillos rechazados por el usuario; PR #40 cerrado. La rama se conserva para el rescate de PKG-5 |
| PKG-4 | vfx-ui-engineer (lo ejecuta Claude) | `feat/012-pkg4` | — | integrado | 0 | `agy` no tiene permiso para copiar binarios |
| PKG-5 | vfx-ui-engineer | `feat/012-pkg5` | PKG-4 | integrado | 0 | |
| PKG-2 | gameplay-engineer | `feat/012-pkg2` | PKG-5 | en curso | 0 | |
| PKG-QA | qa-engineer | `feat/012-pkgqa` | PKG-2 | pendiente | 0 | |

## Paquetes de ejecución

### PKG-1 — Señal con categoría
- **Agente / rama**: `integrator` / `feat/012-pkg1`
- **Archivos permitidos**:
  ```allowed
  core/signal_bus.gd
  ```
- **Cambio**: añadir la señal del contrato, con su comentario. Nada más.
- **Comandos de cierre**: `./tools/ci/import.sh` · `./tools/ci/check_scripts.sh` · `./tools/ci/lint.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh`.

### PKG-3 — Anillos (descartado)
- **Agente / rama**: `vfx-ui-engineer` / `feat/012-pkg3`
- **Archivos permitidos**:
  ```allowed
  src/vfx/sound_wave_3d.gd
  assets/shaders/sound_wave_3d.gdshader
  src/vfx/noise_ring_style.gd
  src/vfx/noise_ring_style.gd.uid
  assets/ui/noise_ring_style.tres
  src/vfx/last_seen_marker_3d.gd
  src/vfx/last_seen_marker_3d.gd.uid
  scenes/ui/hud_84.gd
  scenes/ui/hud_84.tscn
  src/maps/heist_map_3d.gd  # excepción: llamada a SoundWave3D.create_at (histórico)
  ```
- **Estado**: no se integra. Se conserva la sección para que `check_scope.py` siga reconociendo la rama.

### PKG-4 — Muestras CC0
- **Agente / rama**: `vfx-ui-engineer` / `feat/012-pkg4` (lo ejecuta Claude: copia binarios desde los zips descargados, algo que `agy` no tiene permitido)
- **Archivos permitidos**:
  ```allowed
  assets/audio/CREDITS.md
  assets/audio/sfx/**
  ```
- **Cambio**: las 25 muestras de "Contrato de PKG-4" con sus `.import` generados por Godot, y `CREDITS.md`.
- **Comandos de cierre**: los de PKG-1.

### PKG-5 — Mezcla, paleta, vúmetro y rescate del HUD
- **Agente / rama**: `vfx-ui-engineer` / `feat/012-pkg5` (sale de `master` con PKG-4 integrado)
- **Archivos permitidos**:
  ```allowed
  src/vfx/noise_mix.gd
  src/vfx/noise_mix.gd.uid
  assets/audio/noise_mix.tres
  src/ui/hud_palette.gd
  src/ui/hud_palette.gd.uid
  assets/ui/hud_palette.tres
  src/ui/noise_meter_84.gd
  src/ui/noise_meter_84.gd.uid
  src/ui/offscreen_chevron_84.gd
  src/ui/offscreen_chevron_84.gd.uid
  src/vfx/last_seen_marker_3d.gd
  src/vfx/last_seen_marker_3d.gd.uid
  scenes/ui/hud_84.gd
  scenes/ui/hud_84.tscn
  tests/unit/test_noise_meter_unit.gd  # excepción: tests unitarios del ejecutor
  tests/unit/test_noise_meter_unit.gd.uid  # excepción: tests unitarios del ejecutor
  ```
- **Rescate**: parte de los archivos de la rama descartada, con `git checkout feat/012-pkg3 -- scenes/ui/hud_84.gd scenes/ui/hud_84.tscn src/vfx/last_seen_marker_3d.gd src/vfx/last_seen_marker_3d.gd.uid`. Después:
  - cambia `NoiseRingStyle` y `noise_ring_style.tres` por `HudPalette` y `hud_palette.tres`;
  - saca el chevron a `OffscreenChevron84`;
  - añade el vúmetro según el contrato.

  No rescates nada más de esa rama.
- **Contratos y valores**: los de "Contrato de PKG-5" y las tablas "Valores" y "Paleta del HUD". En `noise_mix.tres`, cada array lista los `.ogg` de su carpeta de `assets/audio/sfx/` en orden de nombre.
- **Tests**: unitarios de `NoiseMeter84` (dinámica de `push`, `lit_segments`, `is_over`) y de `NoiseMix.streams_for` con los tres umbrales, en `tests/unit/test_noise_meter_unit.gd`.
- **Comandos de cierre**: los de PKG-1, más `./tools/ci/check_patterns.sh`. Sin MCP ni capturas.
- **Fuera de alcance**: presentadores, emisores, `heist_map_3d.gd` y el borrado de `SoundWave3D`.

### PKG-2 — Reglas, emisión y presentadores
- **Agente / rama**: `gameplay-engineer` / `feat/012-pkg2` (sale de `master` con PKG-5 integrado)
- **Archivos permitidos**:
  ```allowed
  src/systems/noise/noise_emit.gd
  src/systems/noise/noise_emit.gd.uid
  src/systems/noise/noise_feedback_profile.gd
  src/systems/noise/noise_feedback_profile.gd.uid
  src/systems/noise/noise_audio_rules.gd
  src/systems/noise/noise_audio_rules.gd.uid
  data/balance/noise_feedback.tres  # excepción: valores de stealth.md parte 2
  src/systems/lighting/thief_exposure.gd
  src/systems/lighting/thief_exposure.gd.uid
  src/entities/components/perception_rules.gd
  src/entities/guard/guard_senses.gd
  src/maps/noise_audio_presenter.gd
  src/maps/noise_audio_presenter.gd.uid
  src/maps/local_view_presenter.gd
  src/maps/local_view_presenter.gd.uid
  src/maps/heist_map_3d.gd
  src/entities/player_base_3d.gd
  src/entities/guard/guard_controller_3d.gd
  src/entities/loot_item_3d.gd
  src/systems/safe_box_3d.gd
  src/systems/escape_car_3d.gd
  src/systems/time_clock_3d.gd
  src/systems/lighting/lamp_3d.gd
  src/systems/lighting/light_switch_3d.gd
  src/vfx/sound_wave_3d.gd  # excepción: borrado (anillos retirados)
  src/vfx/sound_wave_3d.gd.uid  # excepción: borrado (anillos retirados)
  assets/shaders/sound_wave_3d.gdshader  # excepción: borrado (anillos retirados)
  tests/unit/test_perception.gd  # excepción: adaptar a noise_reaches y al audio
  ```
- **Contratos y valores**: los de "Contrato de PKG-2", la tabla de emisores y la tabla "Valores".
- **Adaptación de `tests/unit/test_perception.gd`** (y nada más de ese archivo):
  - `ring_visible_to(x, o, r)` pasa a `noise_reaches(x, o, r, &"thief", 1.5)`;
  - los dos asserts que esperaban `true` para el ladrón lejano y para `null` pasan a esperar `false`;
  - `_count_sound_waves` cuenta los nodos del grupo `&"noise_audio"` en lugar de `SoundWave3D`;
  - el test del criterio 11 de FEAT-008 emite con `NoiseEmit.emit(..., NoiseEmit.STEP, null)` en lugar de `noise_emitted_3d`.
- **Tests**: los demás tests existentes en verde, sin tocarlos. Si alguno falla por el cambio, entrega `bloqueado` con la salida.
- **Comandos de cierre**: los de PKG-1, más `./tools/ci/check_patterns.sh`.

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/012-pkgqa`
- **Archivos permitidos**:
  ```allowed
  tests/unit/test_noise_categories.gd
  tests/unit/test_noise_categories.gd.uid
  tests/unit/test_noise_audio.gd
  tests/unit/test_noise_audio.gd.uid
  tests/unit/test_noise_meter.gd
  tests/unit/test_noise_meter.gd.uid
  tests/unit/test_local_view.gd
  tests/unit/test_local_view.gd.uid
  ```
- **Tests obligatorios**:
  - los nombres de la columna "Evidencia" de los criterios 1 a 13;
  - los invariantes leen los `.tres`;
  - el criterio 1 recorre la tabla de emisores provocando cada ruido de verdad, sin llamar a `NoiseEmit` directamente;
  - los criterios 2 a 6 y 9 montan un `HeistMap3D` mínimo y fijan `rng.seed`;
  - en el criterio 9, el frustum se controla colocando la cámara del mapa;
  - el criterio 13 comprueba también que cada array de `noise_mix.tres` apunta a los `.ogg` de su carpeta en orden de nombre (por `resource_path`);
  - el criterio 8 comprueba también que `ExposurePanel` es visible con el ladrón local aunque no haya estado de exposición, y oculto con un guardia local.
- **Montaje**: las lecciones de `_TEMPLATE.md`, con `./tools/ci/import.sh` primero. En headless el audio usa el driver Dummy: se comprueban los nodos y sus propiedades, no el sonido.
- **Comandos de cierre**: los de PKG-2.

## Riesgos y decisiones abiertas
1. **Muestras de relleno**: caja fuerte, coche, reloj y walkie suenan como un interruptor hasta que haya muestras propias (FEAT de audio posterior).
2. **Umbrales de superficie** (0,7 y 1,3): deciden qué salas suenan a alfombra, parqué o mármol. Se ajustan en `noise_mix.tres` sin TUNE.
3. **Muchos reproductores a la vez**: con varios guardias corriendo se crean y destruyen muchos nodos. Si se nota en el perfilado, se pasará a un pool (FEAT técnica).
4. **Accesibilidad**: quien juega sin sonido pierde la información de ruido. Subtítulos opcionales, en el backlog.
