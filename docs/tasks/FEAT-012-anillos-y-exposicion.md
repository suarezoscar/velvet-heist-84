# FEAT-012 — Anillos de ruido "radar de 1984", indicador de exposición y última posición vista

- **Estado**: aprobada (2026-10-23)
- **Diseño**: `docs/gdd/systems/stealth.md` parte 2 (aprobada): P2.4 (anillos), O1 (exposición) y O2 (presentación). Invariantes 22 y 24.
  - Estilo visual: opción 2A del usuario (2026-10-23), "radar de 1984": trazo fino, opacidad baja y brillo de fósforo.
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`

## Objetivo
Al probar el juego, el usuario ve las ondas de ruido "excesivas". La causa está en `src/vfx/sound_wave_3d.gd` y `assets/shaders/sound_wave_3d.gdshader`:
- el grosor es el 4 % del radio, así que un anillo de 8 m mide 32 cm;
- se mezclan en aditivo al 90 % de opacidad, con azul y oro saturados;
- duran 0,8 s, todas con la misma forma.

Esta FEAT aplica las reglas aprobadas de P2.4 con un estilo discreto y legible. Añade además lo que el ladrón y el guardia necesitan leer en pantalla: el indicador de exposición (O1) y la silueta de última posición vista (O2).

## Alcance y fuera de alcance
- Dentro:
  - categoría y emisor de cada ruido;
  - anillos con forma por categoría y color por papel;
  - tiempos en `.tres`;
  - límite de anillos vivos;
  - marcador en el borde de la pantalla;
  - indicador de exposición del ladrón en el HUD;
  - silueta de última posición vista para el guardia local.
- Fuera:
  - fuentes sostenidas con pulsos (despertador, voz del walkie), que aún no existen; el reloj de fichar conserva su alarma actual;
  - sonido real (audio);
  - walkie;
  - red: todo es presentación local.

## Estilo (decisión 2A; valores de esta spec)
| Elemento | Valor |
|---|---|
| Trazo base | 2 px en pantalla, independiente del radio (`fwidth` sobre la distancia en metros) |
| Opacidad del trazo | 0,45 |
| Brillo de fósforo | Halo de 4 px a cada lado del trazo, que cae de 0,15 a 0 |
| Mezcla | `blend_mix` (no aditiva), `unshaded`, `depth_test_disabled` |
| Paso | Anillo continuo de 2 px |
| Golpe u objeto | Anillo doble: dos trazos de 2 px separados 4 px |
| Mecanismo | Anillo discontinuo de 2 px: 24 segmentos y la mitad de cada uno visible |
| Crecimiento | De 0 al radio final en `ring_grow_time`, con curva de salida (ease-out) |
| Desvanecido | La opacidad baja a 0 durante el último 40 % de la vida |
| Color "propio" | `#F2B84B` (ámbar de fósforo) |
| Color "guardia", visto por el ladrón | `#4FC3F7` (cian) |
| Color "ajeno", visto por un guardia | `#B8E6C1` (verde fósforo pálido) |

Los colores y el grosor viven en `assets/ui/noise_ring_style.tres` (presentación, no balance).

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Cada ruido lleva categoría (`&"step"`, `&"impact"` o `&"mechanism"`) y emisor, según la tabla de categorías | `test_noise_categories.gd::test_each_emitter_category` |
| 2 | Inv. 24: el radio final dibujado es el radio emitido (tolerancia 1 cm) | `test_noise_rings.gd::test_inv24_ring_radius_exact` |
| 3 | Inv. 22: `ring_lifetime_step ≥ 2 × max(step_interval_*)` de los dos perfiles de movimiento, y `ring_grow_time < ring_lifetime_step` | `test_noise_rings.gd::test_inv22_readable_trail` |
| 4 | La vida del anillo es `ring_lifetime_step` en pasos y `ring_lifetime_event` en golpes y mecanismos | `test_ring_lifetimes` |
| 5 | Papel del anillo: `own` si el emisor es el jugador local (o, si el local es el ladrón, cualquier ruido con equipo `&"thief"`); si el local es el ladrón y el equipo es `&"guard"`, `guard`; en otro caso, `other`. Un guardia nunca recibe `guard` | `test_ring_roles` |
| 6 | Visibilidad: la regla de FEAT-008 sigue igual (`ring_visible_to`) | Tests existentes de `test_perception.gd` |
| 7 | Con más de `max_rings` anillos vivos, se acortan los más antiguos y nunca se descarta uno nuevo | `test_ring_cap` |
| 8 | Si un anillo alcanza al jugador local y su origen queda fuera de la pantalla, el HUD muestra un marcador en el borde, en la dirección del origen, durante la vida del anillo | `test_offscreen_marker` |
| 9 | O1: con el ladrón como jugador local, el HUD muestra `shadow`, `lit` o `beam` (en el haz). La prioridad es `beam` > `lit` > `shadow`, con las mismas reglas que `GuardSenses` (cono y luz) | `test_thief_exposure` |
| 10 | O2: con un guardia local que deja de percibir al ladrón, aparece la silueta en `last_seen_position` y desaparece al llegar `last_seen_time_left` a 0 | `test_last_seen_marker` |
| 11 | Aspecto: trazo de 2 px a 1080p con la cámara de tamaño 14; un anillo de `min_radius` se distingue del personaje; las tres formas se distinguen en escala de grises | Tres capturas en el informe de PKG-3 (paso, golpe y mecanismo, y una en grises) y aprobación visual del usuario |

## Contratos

### Contrato de PKG-1: `core/signal_bus.gd`
```gdscript
## Ruido con categoría y emisor; noise_emitted_3d se sigue emitiendo para quien ya lo escucha
signal noise_event_3d(world_position: Vector3, radius: float, source_team: StringName,
		category: StringName, emitter: Node)
```

### Contrato de PKG-2: categorías y emisión
`src/systems/noise/noise_emit.gd`:
```gdscript
class_name NoiseEmit extends RefCounted
const STEP: StringName = &"step"
const IMPACT: StringName = &"impact"
const MECHANISM: StringName = &"mechanism"
## Emite noise_emitted_3d(pos, radius, team) y noise_event_3d(pos, radius, team, category, emitter)
static func emit(pos: Vector3, radius: float, team: StringName, category: StringName, emitter: Node) -> void
```

Todos los emisores actuales pasan a `NoiseEmit.emit`, con la categoría de esta tabla:

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

**`NoiseRingsProfile`** (`src/systems/noise/noise_rings_profile.gd`). Valores en `data/balance/noise_rings.tres`, tabla "Números (parte 2)" de `stealth.md`:
- `ring_grow_time` 0.4;
- `ring_lifetime_step` 1.4;
- `ring_lifetime_event` 2.0;
- `pulse_interval` 0.6;
- `max_rings` 48.

**`ThiefExposure`** (`src/systems/lighting/thief_exposure.gd`):
```gdscript
class_name ThiefExposure extends RefCounted
## &"beam" si algún guardia con flashlight_on lo tiene en el cono con rayo libre desde
## flashlight_height a algún punto de visibilidad; si no, &"lit" si algún punto está iluminado
## (LightingRules.is_point_lit); si no, &"shadow"
static func compute(thief: ThiefController3D, guards: Array[GuardController3D], lamps: Array[Lamp3D]) -> StringName
```

Para no duplicar reglas, `GuardSenses` expone:
- `func cone_sees(guard, thief) -> bool`;
- `func light_point_lit(thief, lamps) -> bool`, la parte de iluminación sin el arco ciego del guardia.

`detects` las reutiliza.

**`LocalViewPresenter`** (`src/maps/local_view_presenter.gd`, `class_name LocalViewPresenter extends Node`): saca de `HeistMap3D` la presentación local para que el mapa no pase de 300 líneas.
- Escucha `noise_event_3d`.
- Filtra los anillos con `ring_visible_to`.
- Calcula el papel (criterio 5) y crea `SoundWave3D` con la vida que toque.
- Aplica `max_rings`.
- Llama a `hud.show_offscreen_noise(...)` cuando el anillo alcanza al jugador local y su origen está fuera de la pantalla, comprobado con `camera.is_position_in_frustum`.
- Cada tick de física, si el local es el ladrón, llama a `hud.set_exposure(ThiefExposure.compute(...))`. Con cualquier otro jugador local, `hud.set_exposure(&"")` oculta el indicador.
- Gestiona un `LastSeenMarker3D` para el guardia local.

`HeistMap3D` crea un `LocalViewPresenter` en `_ready` y deja de conectar `noise_emitted_3d` para dibujar.

### Contrato de PKG-3: presentación (`vfx-ui-engineer`)
- **`SoundWave3D`** (reescrito):
  ```gdscript
  static func create_at(parent: Node, pos: Vector3, radius: float, category: StringName,
  		role: StringName, lifetime: float, grow_time: float, style: NoiseRingStyle) -> SoundWave3D
  func shorten(remaining: float) -> void  # acorta la vida restante (para max_rings)
  var final_radius: float  # solo lectura; = radius
  ```
  El shader lleva los uniforms `category_mode` (0 continuo, 1 doble, 2 discontinuo), `stroke_px`, `glow_px`, `color`, `alpha` y `current_radius_m`. La malla es un `QuadMesh` de lado `2 × radius + margen`. El grosor se calcula en píxeles con `fwidth`.
- **`NoiseRingStyle`** (`src/vfx/noise_ring_style.gd`, `extends Resource`): `stroke_px: float = 2.0`, `glow_px: float = 4.0`, `alpha: float = 0.45`, `glow_alpha: float = 0.15`, `double_gap_px: float = 4.0`, `dash_segments: int = 24`, `color_own`, `color_guard` y `color_other`, con los valores de la tabla "Estilo". Vive en `assets/ui/noise_ring_style.tres`.
- **`HUD84`**:
  - `func set_exposure(state: StringName) -> void`: indicador arriba a la izquierda, con texto e icono:
    - `SOMBRA` en gris al 50 %;
    - `ILUMINADO` en ámbar `#F2B84B`;
    - `EN EL HAZ` en `#FF6B5A`, con un parpadeo de 2 Hz;
    - `&""` oculta el indicador.
  - `func show_offscreen_noise(world_pos: Vector3, lifetime: float, role: StringName) -> void`: chevron de 16 px en el borde de la pantalla, en la dirección del origen proyectado, con el color del papel, desvanecido igual que el anillo.
- **`LastSeenMarker3D`** (`src/vfx/last_seen_marker_3d.gd`, `extends Node3D`):
  - silueta de cápsula de 0,8 × 1,8 m, `unshaded`, con contorno de 2 px en `color_other` y alfa 0,35, que se desvanece de forma lineal;
  - `func show_at(pos: Vector3, duration: float) -> void` y `func hide_marker() -> void`.

## Impacto en red
Ninguno: es presentación local. `noise_event_3d` es local y la red autoritativa decidirá en el paquete F qué ruidos recibe cada cliente.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | integrator | `feat/012-pkg1` | — | en curso | 0 | |
| PKG-3 | vfx-ui-engineer | `feat/012-pkg3` | — | en curso | 0 | |
| PKG-2 | gameplay-engineer | `feat/012-pkg2` | PKG-1, PKG-3 | pendiente | 0 | |
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

### PKG-3 — Anillos, HUD y silueta
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
  src/maps/heist_map_3d.gd  # excepción: adaptar la llamada a SoundWave3D.create_at a la firma nueva (papel `other`, vida ring_lifetime_event fija hasta PKG-2)
  ```
- **Contratos y valores**: los de "Contrato de PKG-3" y la tabla "Estilo". Las capturas del criterio 11 las hace el planificador tras la entrega (en headless no se puede renderizar); no uses MCP.
- **Capturas** (criterio 11):
  - escena de prueba temporal fuera del repositorio, o la captura de la ejecución de `test_isometric_gym`;
  - un anillo de cada categoría y papel, a 1920 × 1080 y con la cámara de tamaño 14, más una versión en escala de grises;
  - se adjuntan al informe como rutas del scratchpad.

  Si en este entorno no se pueden hacer capturas, entrega `bloqueado` explicando por qué.
- **Comandos de cierre**: los de PKG-1.
- **Fuera de alcance**: emisores de ruido, `LocalViewPresenter` y la lógica de exposición.

### PKG-2 — Categorías, presentador y exposición
- **Agente / rama**: `gameplay-engineer` / `feat/012-pkg2` (sale de `master` con PKG-1 y PKG-3 integrados)
- **Archivos permitidos**:
  ```allowed
  src/systems/noise/noise_emit.gd
  src/systems/noise/noise_emit.gd.uid
  src/systems/noise/noise_rings_profile.gd
  src/systems/noise/noise_rings_profile.gd.uid
  data/balance/noise_rings.tres  # excepción: valores de stealth.md parte 2
  src/systems/lighting/thief_exposure.gd
  src/systems/lighting/thief_exposure.gd.uid
  src/entities/guard/guard_senses.gd
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
  ```
- **Contratos y valores**: los de "Contrato de PKG-2" y la tabla de categorías.
- **Tests**: los existentes en verde, sin tocarlos. Si alguno escucha `noise_emitted_3d` y falla, entrega `bloqueado` con la salida.
- **Comandos de cierre**: los de PKG-1, más `./tools/ci/check_patterns.sh`.

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/012-pkgqa`
- **Archivos permitidos**:
  ```allowed
  tests/unit/test_noise_rings.gd
  tests/unit/test_noise_rings.gd.uid
  tests/unit/test_noise_categories.gd
  tests/unit/test_noise_categories.gd.uid
  tests/unit/test_local_view.gd
  tests/unit/test_local_view.gd.uid
  ```
- **Tests obligatorios**:
  - los nombres de la columna "Evidencia" de los criterios 1 a 5 y 7 a 10;
  - los invariantes leen los `.tres`;
  - el criterio 1 recorre la tabla de emisores provocando cada ruido de verdad, sin llamar a `NoiseEmit` directamente;
  - el criterio 7 crea `max_rings + 5` anillos y comprueba que los 5 más antiguos se acortan y que todos los nuevos existen.
- **Montaje**: las lecciones de `_TEMPLATE.md`, con `./tools/ci/import.sh` primero.
- **Comandos de cierre**: los de PKG-2.

## Riesgos y decisiones abiertas
1. **Colores y textos del HUD**: son una propuesta dentro del estilo 2A. Se validan con las capturas de PKG-3 antes de integrar (criterio 11): te las enseñaré.
2. **`fwidth` en ortográfica**: el grosor en píxeles depende del tamaño de la cámara; el criterio 11 lo fija para el tamaño 14.
3. **El chevron del borde podría saturar** con muchos ruidos fuera de pantalla. Si al jugarlo molesta, se limitará a los anillos que no sean pasos (TUNE).
