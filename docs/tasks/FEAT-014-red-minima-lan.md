# FEAT-014 — Red mínima autoritativa para el PoC (1 contra 2 en LAN)

- **Estado**: aprobada (2026-10-23)
- **Diseño**: `n/a — técnica`. Aplica la arquitectura aprobada en `docs/tasks/FEAT-002-net-readiness.md` y el bloque F de `docs/decisions/2026-10-22-fase-1-auditoria.md`, con dos decisiones del usuario (2026-10-23) para el PoC:
  - **sin predicción**: el servidor manda y el cliente solo envía input, porque en LAN (< 5 ms) no hace falta;
  - **solo servidor dedicado**: un proceso headless aparte y los 3 jugadores como clientes; desaparece el host que juega.
- **Roadmap**: hito H2 de `docs/decisions/2026-10-23-roadmap-poc.md`.
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`
- **Requisito previo**: FEAT-012 `hecha`, porque esta FEAT usa `NoiseAudioPresenter`, `LocalViewPresenter` y `NoiseEmit`.

## Objetivo
Que tres personas jueguen el museo en LAN (ladrón, guardia 1 y guardia 2) contra un servidor dedicado:
- el servidor simula todo;
- cada cliente envía solo su input;
- un guardia no recibe nunca la posición del ladrón mientras no lo percibe.

Hoy cada cliente mueve su propio personaje, y la auditoría encontró tres bugs que rompen el online:
1. la porra solo golpea una vez;
2. `guard_3` controla al ladrón;
3. el servidor dedicado no puede lanzar la partida.

Además, hay una fuga de información: la mirada del ladrón llega a los guardias.

## Alcance y fuera de alcance
- Dentro:
  - input del cliente al servidor y simulación en el servidor;
  - estado de los actores (propio a 60 Hz y remotos a 20 Hz con interpolación);
  - filtro del ladrón por guardia;
  - acciones (interactuar, linterna, porra, agacharse, dial de la caja fuerte);
  - estado del mundo: botín, lámparas, caja fuerte, coche, reloj de fichar y cámaras;
  - estado de la partida (`GameManager`);
  - ruido filtrado por alcance;
  - lanzamiento desde el servidor dedicado;
  - roles limitados al ladrón y dos guardias;
  - guardias sin humano controlados por la IA del servidor;
  - prueba de integración con servidor y dos clientes reales.
- Fuera:
  - predicción y reconciliación (post-PoC, para internet);
  - host que juega;
  - mansión (solo el museo);
  - huellas en clientes;
  - visión de las cámaras CCTV sobre el ladrón para los guardias;
  - desconexión a media partida (el actor queda quieto y sigue la partida);
  - revancha y fin de ronda (H3);
  - cifrado y anti-trampas más allá del filtro del ladrón y la validación de RPC.

## Valores (técnicos, no de balance)
Viven en `src/network/net_config.gd` (`class_name NetConfig extends RefCounted`, solo constantes):

| Constante | Valor | Origen |
|---|---|---|
| `REMOTE_SNAPSHOT_HZ` | 20.0 | FEAT-002, decisión 3 |
| `OWN_STATE_EVERY_TICK` | `true` (estado propio en cada tick de física, 60 Hz) | Sin predicción: el propio se ve con un tick de retraso en LAN |
| `INTERP_DELAY` | 0.1 s | `references/prediction-and-interpolation.md` |
| `INTERP_BUFFER` | 8 snapshots por actor | ídem |
| `WORLD_STATE_HZ` | 10.0 (se envían solo los cambios) | esta spec |
| `GAME_TIMER_HZ` | 1.0 | FEAT-002 |
| `MAX_LOOK_DISTANCE` | 30.0 m (distancia horizontal máxima de `look_target` al actor; más lejos, se recorta) | esta spec |
| `ROLES` | `[&"thief", &"guard_1", &"guard_2"]` | PoC 1 contra 2 |
| `ACTIONS` | `[&"interact", &"toggle_flashlight", &"strike", &"crouch_toggle", &"dial_left", &"dial_right", &"dial_cancel"]` | esta spec |

## Tabla de replicación
| Dato | Escribe | Canal | Frecuencia | Quién lo recibe |
|---|---|---|---|---|
| Input (movimiento, sprint, sigilo, mirada) | cliente dueño | RPC `_server_input`, `unreliable_ordered` | cada tick de física | servidor |
| Acción discreta | cliente dueño | RPC `_server_action`, `reliable` | al pulsar | servidor |
| Estado propio (pos, vel, rot_y, agachado, linterna, estamina y, en el guardia, percepción y última posición vista) | servidor | RPC `_client_own_state`, `unreliable_ordered` | cada tick | solo el dueño |
| Estado de actores remotos (pos, vel, rot_y, agachado, mirada, linterna) | servidor | RPC `_client_snapshot`, `unreliable_ordered` | 20 Hz | cada cliente, **sin el ladrón** si es un guardia que no lo percibe en ese tick |
| Estado del mundo (botín, lámparas, caja fuerte, coche, reloj, cámaras) | servidor | RPC `_client_world_state`, `reliable` | 10 Hz, solo cambios; completo al conectar | todos; la parte privada de la caja fuerte, solo el ladrón |
| Estado de la partida (`GameManager`) | servidor | RPC `_client_game_state`, `reliable` | al cambiar y el reloj a 1 Hz | todos |
| Ruido | servidor | RPC `_client_noise`, `unreliable` | al emitirse | solo los peers cuyo actor alcanza (`PerceptionRules.noise_reaches`) |
| Listo para recibir | cliente | RPC `_server_client_ready`, `reliable` | una vez, al cargar el mapa | servidor |

**Datos secretos**:
- **Posición, velocidad, mirada y existencia del ladrón**: no llegan a un peer de guardia mientras su guardia no tiene `is_perceiving_thief == true` en el servidor (criterio 4).
- **Ruidos que no alcanzan a un peer**: no llegan a ese peer (criterio 7).
- **Estado de la ganzúa** (sesión activa, número del dial y etapa): solo llega al ladrón (criterio 8).

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | `NetInputRules.sanitize` recorta `movement_vector` a longitud 1, `look_target` a `MAX_LOOK_DISTANCE` en horizontal desde el actor, y descarta componentes no finitas (NaN o inf → el valor actual del actor) | `tests/unit/test_net_rules.gd::test_sanitize_input` |
| 2 | Un RPC de input o acción de un peer sobre un actor que no es suyo no cambia nada; una acción fuera de `ACTIONS` se ignora | `test_net_rules.gd::test_rejects_foreign_sender` |
| 3 | `NetVisibility.roles_visible_to(peer_role, perceiving)` devuelve todos los actores menos el propio, y quita `&"thief"` cuando `peer_role` es un guardia y `perceiving[peer_role]` es false | `test_net_rules.gd::test_visibility_filter` |
| 4 | Integración: durante la prueba, el cliente guardia no recibe ningún estado del ladrón en un tick en que su `is_perceiving_thief` (en el servidor) es false. La posición del ladrón en ese cliente no cambia mientras no lo percibe | `tools/ci/qa_net_loopback.sh`, escenario `secret` |
| 5 | Integración: el ladrón pulsa `move_up` durante 1 s y, en el servidor y en su cliente, el ladrón se ha movido ≥ 1 m; el cliente solo ha enviado input, nunca posiciones | escenario `move` |
| 6 | Integración: con el guardia a 1 m del ladrón (montaje `capture`), `REQUIRED_HITS_TO_CAPTURE` acciones `strike` separadas por más que el enfriamiento terminan la partida en `THIEF_CAPTURED` en el servidor y en los dos clientes (corrige el bug 1) | escenario `capture` |
| 7 | Integración: con el ladrón a 20 m del guardia (montaje `far_noise`), un paso del ladrón suena en el cliente ladrón y no llega al cliente guardia | escenario `far_noise` |
| 8 | Integración: al coger un botín ligero, desaparece en los dos clientes y `GameManager.current_loot_value` sube en los tres procesos. El estado de la ganzúa solo llega al cliente ladrón | escenario `loot` |
| 9 | `NetManager` solo ofrece `thief`, `guard_1` y `guard_2`; pedir `guard_3` devuelve false. `guard_N` controla `guards[N-1]` en orden de escena (corrige el bug 2) | `tests/unit/test_net_roles.gd::test_roles_limited` |
| 10 | `godot --headless -- --server` arranca el servidor dedicado, y un cliente que llama a `NetManager.request_start()` con el rol de ladrón ocupado lanza el museo en los tres procesos (corrige el bug 3); sin ladrón no arranca | escenario `start` y `test_net_roles.gd::test_start_requires_thief` |
| 11 | Con red, en un cliente: `NoiseEmit.emit` no emite nada, `GameManager` no descuenta tiempo ni termina la partida por su cuenta, la IA de los guardias y la percepción no se ejecutan, y los objetos del grupo `&"net_state"` tienen `physics_process` desactivado | `test_net_roles.gd::test_client_is_view_only` |
| 12 | Cada objeto con estado de red devuelve un estado que, aplicado a otra instancia, deja ambas iguales: `LootItem3D`, `Lamp3D`, `SafeBox3D`, `EscapeCar3D`, `TimeClock3D`, `SecurityCamera3D` y `GameManager` | `tests/unit/test_net_state.gd::test_roundtrip_*` (uno por clase) |
| 13 | Sin red, el juego se comporta igual que antes: todos los tests existentes en verde | `./tools/ci/run_tests.sh` |
| 14 | Prueba manual: tres equipos en LAN juegan una partida completa sin desincronizaciones visibles | Partida de prueba del usuario (H2 del roadmap) |

## Contratos

### Contrato de PKG-1 (`integrator`): `core/game_manager.gd`
```gdscript
## {"state": int, "loot": int, "masterpiece": bool, "timer": float}
func get_net_state() -> Dictionary
func apply_net_state(state: Dictionary) -> void
## true si esta instancia decide la partida: sin red, o con red y multiplayer.is_server()
func is_simulating() -> bool
```
- `_physics_process` y los manejadores de `loot_stolen` y `thief_captured` no hacen nada si `is_simulating()` es false.
- `NetManager` y `SignalBus` se consultan por su nombre de autoload, nunca con rutas `/root/...`: `check_patterns.sh` lo prohíbe en todo archivo cambiado.
- Sin red, `is_simulating()` es true.

### Contrato de PKG-2 (`gameplay-engineer`): estado de mundo y acciones, sin red
**Estado de red de los objetos**. Cada clase de la lista:
- se añade al grupo `&"net_state"` en `_ready`;
- expone `get_net_state() -> Dictionary` y `apply_net_state(state: Dictionary) -> void`.

Los nodos se referencian con rutas relativas a `get_tree().current_scene`, como `String`.

| Clase | Claves del estado | Al aplicar en el cliente |
|---|---|---|
| `LootItem3D` | `collected: bool`, `holder: String` (ruta del ladrón o `""`), `deposited: bool` | `collected` sin `holder`, o `deposited`, oculta el nodo y desactiva su detección (`monitoring`/`monitorable` en false). Con `holder`, lo reparenta al `carry_anchor` del portador, como `_attach_to_thief_hands`, pero sin emitir señales ni ruido |
| `Lamp3D` | `switched_on: bool`, `unscrewed: bool` | asigna las dos y llama a `_update_bulb()` |
| `SafeBox3D` | público: `opened: bool`; privado (solo ladrón): `cracking: bool`, `dial: int`, `stage: int` | asigna y emite `dial_rotated` si cambia `dial` |
| `EscapeCar3D` | `escaped: bool` | asigna |
| `TimeClock3D` | `time_left: float`, `expired: bool` | asigna |
| `SecurityCamera3D` | `rot_y: float`, `alert: bool` | `rotation.y = rot_y`; `_set_cone_alert(alert)` |

`SafeBox3D` expone además `func get_net_state_private() -> Dictionary` (las claves privadas) y la acepta en `apply_net_state` cuando vienen.

**API pública de la caja fuerte**:
- `func step_dial(direction: int) -> void`: −1 o +1, solo en `CRACKING`. Es la lógica actual de `_step_dial`.
- `func cancel_cracking() -> void`.
- `_unhandled_input` se queda para jugar sin red y llama a estas dos funciones.

**Acciones de los actores**: `PlayerBase3D` tiene `func perform_action(action: StringName) -> bool`, que devuelve true si la ejecuta. Las implementaciones reutilizan el código que hoy dispara cada tecla:
- `PlayerBase3D`: `&"crouch_toggle"` → `set_crouching(not is_crouching)`.
- `ThiefController3D`: `&"interact"` → `interactor.execute_interaction(self)`. `&"dial_left"`, `&"dial_right"` y `&"dial_cancel"` actúan sobre la `SafeBox3D` cuyo `active_thief == self`, si la hay.
- `GuardController3D`:
  - `&"interact"`;
  - `&"toggle_flashlight"` → `set_flashlight(not flashlight_on)`;
  - `&"strike"` → `swing_baton(get_tree().get_first_node_in_group(&"thief") as ThiefController3D)`.

Las rutas de teclado actuales (`_process_local_actions`, `HeistMap3D._process_local_strike`) pasan a llamar a `perform_action` sin cambiar su comportamiento.

**Estado de red de los actores**:
- `PlayerBase3D`:
  - `func get_net_actor_state() -> Dictionary` con `pos: Vector3`, `vel: Vector3`, `rot_y: float`, `crouching: bool` y `look: Vector3`;
  - `func apply_net_actor_state(state: Dictionary) -> void`, que asigna `global_position`, `velocity`, `rotation.y` y `look_target_position` (si viene `look`) y llama a `set_crouching(crouching)`;
  - `is_net_interpolating` queda en false.
- `GuardController3D` añade `flashlight: bool`, `stamina: float`, `perceiving: bool`, `last_seen_pos: Vector3` y `last_seen_left: float`. Al aplicar `flashlight`, usa `func apply_flashlight_state(on: bool)`, que cambia la luz sin emitir ruido.
- `ThiefController3D` no añade claves: el ladrón no tiene estamina. Su `set_visible_to_local_viewer` oculta también `carry_anchor`, para que el botín cargado no delate al ladrón.

**`NoiseEmit.emit`** no hace nada si `NetManager.is_online()` y no `multiplayer.is_server()`. Lo comprueba con `Engine.get_main_loop()`.

**`NoiseAudioPresenter`**:
- se extrae `func handle_noise(pos: Vector3, radius: float, team: StringName, category: StringName, emitter: Node, surface_mult: float) -> void` con los pasos 1–6 actuales; `m` pasa a ser el `surface_mult` recibido;
- el manejador de `noise_event_3d` calcula `surface_mult` como hoy y llama a `handle_noise`.

### Contrato de PKG-3 (`gameplay-engineer`): sesión de red
**`NetConfig`** (`src/network/net_config.gd`): las constantes de la tabla "Valores".

**`NetInputRules`** (`src/network/net_input_rules.gd`, `class_name NetInputRules extends RefCounted`):
```gdscript
## movement_vector: Vector2 (limit_length(1)); is_sprinting, is_sneaking: bool; look_target: Vector3
## recortado a MAX_LOOK_DISTANCE en horizontal desde actor.global_position. No finito → valor actual del actor.
static func sanitize(actor: PlayerBase3D, move: Vector2, sprint: bool, sneak: bool, look: Vector3) -> Dictionary
static func is_valid_action(action: StringName) -> bool
```

**`NetVisibility`** (`src/network/net_visibility.gd`, `class_name NetVisibility extends RefCounted`):
```gdscript
## Roles de actores (de NetConfig.ROLES) cuyo estado remoto recibe peer_role; nunca incluye el propio.
## Si peer_role empieza por "guard" y perceiving.get(peer_role, false) es false, no incluye &"thief".
static func roles_visible_to(peer_role: StringName, perceiving: Dictionary) -> Array[StringName]
```

**`NetSession`** (`src/network/net_session.gd`, `class_name NetSession extends Node`): la crea `HeistMap3D` en `_ready` con red, con el nombre fijo `"NetSession"` y como hija del mapa, para que la ruta coincida en todos los procesos.

```gdscript
func setup(map: HeistMap3D, audio: NoiseAudioPresenter) -> void
func actor_for_role(role: StringName) -> PlayerBase3D   # thief → map.thief; guard_N → map.guards[N-1]
```

Si pasa de 300 líneas, se divide en `net_session_server.gd` y `net_session_client.gd` (dos `RefCounted` a los que delega), sin cambiar los RPC.

RPC (todos en `NetSession`, con estas firmas exactas):

```gdscript
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _server_input(tick: int, move: Vector2, sprint: bool, sneak: bool, look: Vector3) -> void
@rpc("any_peer", "call_remote", "reliable")
func _server_action(action: StringName) -> void
@rpc("any_peer", "call_remote", "reliable")
func _server_client_ready() -> void
@rpc("authority", "call_remote", "unreliable_ordered")
func _client_own_state(state: Dictionary) -> void
@rpc("authority", "call_remote", "unreliable_ordered")
func _client_snapshot(server_time: float, states: Dictionary) -> void   # role → estado
@rpc("authority", "call_remote", "reliable")
func _client_world_state(changes: Dictionary) -> void   # ruta → estado
@rpc("authority", "call_remote", "reliable")
func _client_game_state(state: Dictionary) -> void
@rpc("authority", "call_remote", "unreliable")
func _client_noise(pos: Vector3, radius: float, team: StringName, category: StringName,
		emitter_role: StringName, surface_mult: float) -> void
```

**En el servidor**:
1. **Roles y control**:
   - todos los actores tienen autoridad 1 y `is_locally_controlled = false`;
   - un guardia cuyo rol no ocupa nadie sigue con `is_ai_controlled = true`;
   - uno ocupado, `false`.
2. **`_server_input`**:
   - el emisor tiene que ser el peer del rol del actor (`NetManager.get_role_for_peer`); si no, se ignora;
   - se descarta un `tick` ≤ el último recibido de ese peer;
   - si no, `actor.apply_input(NetInputRules.sanitize(...))`.
3. **`_server_action`**: comprueba el emisor y `is_valid_action`; luego `actor.perform_action(action)`.
4. **Envíos en cada `_physics_process`** (después de la simulación), a cada peer que haya enviado `_server_client_ready`:
   - `_client_own_state` con `actor.get_net_actor_state()` de su actor;
   - cada 1/`REMOTE_SNAPSHOT_HZ` s, `_client_snapshot(Time.get_ticks_msec() / 1000.0, states)`, con los roles de `NetVisibility.roles_visible_to(rol_del_peer, perceiving)`, siendo `perceiving[guard_N] = guards[N-1].is_perceiving_thief`.
5. **Estado del mundo**:
   - cada 1/`WORLD_STATE_HZ` s, recorre el grupo `&"net_state"` y envía a todos los peers listos los estados que cambiaron desde el último envío, comparando los diccionarios;
   - el estado privado de `SafeBox3D` va en un `_client_world_state` aparte, solo al peer del ladrón, con la clave `"<ruta>#private"`;
   - al recibir `_server_client_ready`, envía a ese peer el estado completo del mundo y de la partida.
6. **Estado de la partida**: `_client_game_state(GameManager.get_net_state())` cuando cambian `state`, `loot` o `masterpiece`, y cada 1/`GAME_TIMER_HZ` s.
7. **Ruido**:
   - escucha `SignalBus.noise_event_3d`;
   - por cada peer listo cuyo actor cumple `PerceptionRules.noise_reaches(actor, pos, radius, team, thief_hearing_mult)`, envía `_client_noise`, con `emitter_role` el rol del emisor si es un actor (o `&""`) y `surface_mult` leído del `surface_detector` del emisor (1.0 si no tiene);
   - `thief_hearing_mult` sale de `data/balance/noise_feedback.tres`.

**En el cliente**:
1. **Configuración**:
   - todos los actores con `is_ai_controlled = false`;
   - los nodos `GuardAI3D` con `process_mode = PROCESS_MODE_DISABLED`;
   - los del grupo `&"net_state"` con `set_physics_process(false)`;
   - `HeistMap3D` no ejecuta percepción ni porra local con red en el cliente; usa `is_simulating()` de `GameManager` o comprueba `multiplayer.is_server()`.
2. Al terminar `setup`, envía `_server_client_ready.rpc_id(1)`.
3. **En cada `_physics_process`**, si `map.local_player` no es null:
   - envía `_server_input.rpc_id(1, tick, ...)` con `local_player.gather_input(map.camera)`;
   - envía `_server_action.rpc_id(1, accion)` por cada acción pulsada en ese frame:

     | Tecla (`just_pressed`) | Acción |
     |---|---|
     | `interact` | `&"interact"` |
     | `toggle_flashlight` | `&"toggle_flashlight"` |
     | `strike` | `&"strike"` |
     | `crouch` | `&"crouch_toggle"` |
     | `move_left` o `ui_left` | `&"dial_left"`, solo si alguna `SafeBox3D` tiene `cracking` en el último estado recibido |
     | `move_right` o `ui_right` | `&"dial_right"`, con la misma condición |
     | `ui_cancel` | `&"dial_cancel"`, con la misma condición |
4. **`_client_own_state`**: `local_player.apply_net_actor_state(state)`, sin `look`, porque la mirada propia es la local.
5. **`_client_snapshot`**:
   - guarda los estados por rol en un búfer de `INTERP_BUFFER` con `server_time`;
   - en `_process`, cada actor remoto se coloca interpolando linealmente `pos`, `rot_y` y `look` en `ahora_servidor − INTERP_DELAY`; `ahora_servidor` se estima con el último `server_time` recibido más el tiempo local transcurrido desde que llegó;
   - `crouching` y `flashlight` se aplican del snapshot más reciente;
   - un rol que deja de llegar se queda en su último estado;
   - si es el ladrón y el local es un guardia, `set_visible_to_local_viewer(false)` mientras no llegue en los snapshots.
6. **`_client_world_state`**: `apply_net_state` sobre `current_scene.get_node(ruta)`. Las claves `#private` se aplican con el estado privado.
7. **`_client_game_state`**: `GameManager.apply_net_state(state)`.
8. **`_client_noise`**: `audio.handle_noise(pos, radius, team, category, actor_for_role(emitter_role) o null, surface_mult)`.

**Botín que desaparece o aparece en el servidor**:
- `_collect_light_loot` y `deposit_into_trunk` hacen `queue_free()` en el servidor. `NetSession` (servidor) guarda la ruta de cada nodo del grupo `&"net_state"` y, cuando uno sale del árbol (`tree_exiting`), envía en el siguiente `_client_world_state` la clave de su ruta con el valor `{"removed": true}`. El cliente hace `queue_free()` de ese nodo.
- El botín que crea `SafeBox3D._spawn_loot_contents` solo existe en el servidor. Al abrirse la caja fuerte, el estado público de `SafeBox3D` incluye `opened: true`, y el cliente ejecuta el mismo `_spawn_loot_contents` en `apply_net_state` cuando `opened` pasa de false a true. Esto crea nodos con los mismos nombres y rutas, siempre que `_spawn_loot_contents` les dé un nombre fijo. Si hoy no se lo da, PKG-3 le asigna `name = "SafeLoot_%d" % i`.

**`NetManager`** (`core/net_manager.gd`):
- `AVAILABLE_ROLES = NetConfig.ROLES`; `ROLE_GUARD_3` se mantiene como constante, pero `_assign_role_internal` rechaza cualquier rol fuera de `AVAILABLE_ROLES`;
- `start_host` devuelve `ERR_UNAVAILABLE` sin crear nada (host fuera del PoC);
- `func request_start() -> void`:
  - en un cliente, `_request_start_server.rpc_id(1)`, que es `@rpc("any_peer", "call_remote", "reliable")`;
  - el servidor llama a `launch_match()` solo si el rol `thief` está ocupado;
- `launch_match` sigue cambiando de escena en todos los procesos con `_start_match_rpc`. El servidor dedicado carga también el museo.

**`HeistMap3D._setup_online_control`** (genérico; sustituye al de `museum_velvet_84.gd`):
- crea la `NetSession`;
- en el servidor dedicado, `set_local_player(null)`;
- en un cliente, `set_local_player(actor_for_role(NetManager.get_local_role()))`.

`museum_velvet_84.gd` pierde todo el código de red (constantes, temporizadores, `_setup_online_control`, `_physics_process`, `_perform_strike`, `_role_of`, `_process_network_sync`, `_should_hide_thief_from`, `_broadcast_*`, los cuatro RPC y `_get_actor_by_role`). Conserva `_on_map_ready`, `_extra_hidden_mesh_names` y la CCTV.

**`NetTestHooks`** (`src/network/net_test_hooks.gd`, `class_name NetTestHooks extends RefCounted`): solo actúa si el servidor arrancó con `--net-test=<montaje>` en los argumentos de usuario y `OS.is_debug_build()`. La llama `NetSession.setup` en el servidor. Montajes:

| Montaje | Qué hace |
|---|---|
| `capture` | `guards[0]` a 1.0 m del ladrón, mirándolo |
| `far_noise` | `guards[0]` a 20 m del ladrón en línea recta libre de muros, o en la posición más lejana del suelo del museo si no la hay |
| `loot` | el ladrón a 1.0 m de un `LootItem3D` ligero, mirándolo |

En cada envío, el servidor escribe en la salida estándar una línea `NETLOG {json}` por evento: `sent_snapshot` (peer y roles), `own_state` (peer y pos), `world` (peer y rutas), `noise` (peer) y `game` (estado). Así lo puede comprobar el script de QA.

### Contrato de PKG-4 (`vfx-ui-engineer`): lobby
`scenes/ui/main_menu.gd` y `.tscn`:
- quita el botón de rol `guard_3`;
- el botón "Host" se oculta;
- el texto de ayuda de la conexión dice "Arranca el servidor con `tools/net/run_server.sh` en un PC de la red y únete con su IP";
- "Iniciar partida" llama a `NetManager.request_start()` y se habilita solo si el rol `thief` está ocupado en `get_connected_players()`.

## Impacto en red
Toda la FEAT. Autoridad: servidor (peer 1) sobre todo. Frecuencias y destinatarios en la tabla de replicación. Desviaciones de FEAT-002, aprobadas por el usuario el 2026-10-23:
- sin predicción en el PoC;
- solo servidor dedicado.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | integrator | `feat/014-pkg1` | FEAT-012 hecha | integrado | 0 | Una vuelta descartada por error de la spec (ruta `/root/`) |
| PKG-2 | gameplay-engineer | `feat/014-pkg2` | FEAT-012 hecha | integrado | 1 | Paralelo a PKG-1 y PKG-4 |
| PKG-4 | vfx-ui-engineer | `feat/014-pkg4` | PKG-3 | pendiente | 0 | Usa `request_start` |
| PKG-3 | gameplay-engineer | `feat/014-pkg3` | PKG-1, PKG-2 | en curso | 0 | |
| PKG-QA | qa-engineer | `feat/014-pkgqa` | PKG-3, PKG-4 | pendiente | 0 | |

## Paquetes de ejecución

### PKG-1 — Estado de partida en red
- **Agente / rama**: `integrator` / `feat/014-pkg1`
- **Archivos permitidos**:
  ```allowed
  core/game_manager.gd
  ```
- **Contratos**: "Contrato de PKG-1".
- **Comandos de cierre**: `./tools/ci/import.sh` · `./tools/ci/check_scripts.sh` · `./tools/ci/lint.sh` · `./tools/ci/check_patterns.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh`.

### PKG-2 — Estado de mundo y acciones
- **Agente / rama**: `gameplay-engineer` / `feat/014-pkg2`
- **Archivos permitidos**:
  ```allowed
  src/entities/player_base_3d.gd
  src/entities/thief/thief_controller_3d.gd
  src/entities/guard/guard_controller_3d.gd
  src/entities/loot_item_3d.gd
  src/systems/lighting/lamp_3d.gd
  src/systems/safe_box_3d.gd
  src/systems/escape_car_3d.gd
  src/systems/time_clock_3d.gd
  src/systems/security_camera_3d.gd
  src/systems/noise/noise_emit.gd
  src/maps/noise_audio_presenter.gd
  src/maps/heist_map_3d.gd
  tests/unit/test_net_state_unit.gd
  src/entities/components/actor_net_state.gd
  src/entities/components/actor_net_state.gd.uid
  tests/unit/test_net_state_unit.gd.uid
  ```
- **Contratos**: "Contrato de PKG-2".
- **`ActorNetState`** (`src/entities/components/actor_net_state.gd`, `class_name ActorNetState extends RefCounted`): contiene la lógica de `get_net_actor_state` y `apply_net_actor_state` con `static func read(actor: PlayerBase3D) -> Dictionary` y `static func write(actor: PlayerBase3D, state: Dictionary) -> void`. Los métodos de los actores son envoltorios de una línea, para dejar margen bajo las 300 líneas a PKG-3.
- **Rutas `/root/`**: `check_patterns.sh` revisa el archivo entero. Si un archivo que tocas ya tiene `get_node_or_null("/root/<Autoload>")` (por ejemplo `security_camera_3d.gd:106` o `main_menu.gd:121`), sustitúyelo por el nombre del autoload (`SignalBus`, `NetManager`).
- **Tests**: unitarios de `perform_action` (las 7 acciones) y de `step_dial` y `cancel_cracking`, en `test_net_state_unit.gd`.
- **Comandos de cierre**: los de PKG-1.
- **Fuera de alcance**: nada de RPC ni de `src/network/`.

### PKG-3 — Sesión de red
- **Agente / rama**: `gameplay-engineer` / `feat/014-pkg3` (sale de `master` con PKG-1 y PKG-2 integrados)
- **Archivos permitidos**:
  ```allowed
  src/network/net_config.gd
  src/network/net_config.gd.uid
  src/network/net_input_rules.gd
  src/network/net_input_rules.gd.uid
  src/network/net_visibility.gd
  src/network/net_visibility.gd.uid
  src/network/net_session.gd
  src/network/net_session.gd.uid
  src/network/net_session_server.gd
  src/network/net_session_server.gd.uid
  src/network/net_session_client.gd
  src/network/net_session_client.gd.uid
  src/network/net_test_hooks.gd
  src/network/net_test_hooks.gd.uid
  core/net_manager.gd
  src/maps/heist_map_3d.gd
  src/systems/safe_box_3d.gd  # excepción: nombre fijo del botín creado y creación en el cliente al abrirse
  scenes/maps/museum_velvet_84.gd  # excepción: quitar la red antigua del mapa (la FEAT lo pide)
  tools/net/run_server.sh
  tests/unit/test_multiplayer_lobby.gd  # excepción: adaptar a roles limitados y a la ausencia de host
  tests/integration/test_global_gameplay_loop.gd  # excepción: test_06 comprobaba el modelo antiguo de autoridad por cliente
  ```
- **`tools/net/run_server.sh`**: `#!/usr/bin/env bash`. Lanza `godot --headless --path <raíz del repo> -- --server --port "${1:-7777}"`, con el binario de `tools/ci/godot_version.env`, como hace `tools/ci/run_tests.sh`.
- **Contratos**: "Contrato de PKG-3" y la tabla de replicación.
- **Adaptación de los tests de red antiguos** (`test_multiplayer_lobby.gd` y `test_global_gameplay_loop.gd::test_06_multiplayer_integration_on_map`). Comprobaban el modelo anterior, en el que el host jugaba y cada cliente tenía autoridad sobre su personaje; esta FEAT lo sustituye a propósito. Cambia solo esto:
  - todo `start_host(...)` pasa a `start_dedicated_server(<el mismo puerto>)`, y se registra el ladrón con su propio peer (por ejemplo `register_player(4, "Ladron", NetManagerNode.ROLE_THIEF)`). Un test que comprueba el propio `start_host` pasa a esperar `ERR_UNAVAILABLE`;
  - los asserts de `guard_3` pasan a esperar el rechazo;
  - autoridad en el mapa: los tres actores tienen `get_multiplayer_authority() == 1`, el servidor tiene `is_multiplayer_authority()` true en todos, los guardias con rol ocupado tienen `is_ai_controlled == false` y `map.local_player` es null en el servidor dedicado;
  - los asserts de "solo procesa input sobre su entidad" y de interpolación con `set_net_transform` (el apartado 2 y el 3 de `test_06` y sus equivalentes en `test_multiplayer_lobby.gd`) se borran: ese comportamiento ya no existe y lo cubren los criterios 2, 4 y 5 en PKG-QA;
  - el resto de los tests de esos dos archivos no se toca.
- **Prueba manual obligatoria antes de entregar**: servidor y dos clientes headless en el mismo equipo durante 20 s, sin errores en el log (`tools/ci/scan_godot_log.sh`). Pega en el informe las líneas `NETLOG` de un `sent_snapshot` y un `own_state`.
- **Comandos de cierre**: los de PKG-1.

### PKG-4 — Lobby
- **Agente / rama**: `vfx-ui-engineer` / `feat/014-pkg4` (sale de `master` con PKG-3 integrado)
- **Archivos permitidos**:
  ```allowed
  scenes/ui/main_menu.gd
  scenes/ui/main_menu.tscn
  ```
- **Contratos**: "Contrato de PKG-4".
- **Rutas `/root/`**: `check_patterns.sh` revisa el archivo entero. Si un archivo que tocas ya tiene `get_node_or_null("/root/<Autoload>")` (por ejemplo `security_camera_3d.gd:106` o `main_menu.gd:121`), sustitúyelo por el nombre del autoload (`SignalBus`, `NetManager`).
- **Comandos de cierre**: los de PKG-1. Sin MCP ni capturas.

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/014-pkgqa`
- **Archivos permitidos**:
  ```allowed
  tests/unit/test_net_rules.gd
  tests/unit/test_net_rules.gd.uid
  tests/unit/test_net_roles.gd
  tests/unit/test_net_roles.gd.uid
  tests/unit/test_net_state.gd
  tests/unit/test_net_state.gd.uid
  tests/integration/net/**
  tools/ci/qa_net_loopback.sh
  .github/workflows/ci.yml  # excepción: añadir el paso de qa_net_loopback.sh tras run_tests.sh
  ```
- **Tests obligatorios**: los de la columna "Evidencia" de los criterios 1 a 12.
- **`qa_net_loopback.sh <escenario>`** (`start`, `move`, `secret`, `capture`, `far_noise` o `loot`; sin argumento, todos en secuencia):
  - lanza un servidor dedicado headless (con `--net-test=<montaje>` cuando el escenario lo tiene) y dos clientes headless que ejecutan la escena arnés `tests/integration/net/net_client_harness.tscn` con `-- --role=thief` o `-- --role=guard_1`;
  - el arnés se conecta a `127.0.0.1`, pide su rol y, en el cliente ladrón, llama a `request_start()` cuando los dos roles están ocupados;
  - cuando carga el mapa, ejecuta el guion del escenario (pulsar teclas con `Input.action_press` y `action_release`) y escribe líneas `HARNESS {json}` con lo que observa;
  - el script recoge las tres salidas y comprueba los criterios 4 a 8 y 10 con `python3`;
  - cada escenario dura como mucho 30 s;
  - devuelve 0 si todo pasa y 1 si algo falla, imprimiendo qué criterio falló.
- **Comandos de cierre**: los de PKG-1, más `./tools/ci/qa_net_loopback.sh`.

## Riesgos y decisiones abiertas
1. **Puertos y cortafuegos**: el servidor usa UDP 7777 y en algunas redes domésticas hay que abrirlo en el PC del servidor. Va en la ayuda del lobby.
2. **El botín que desaparece** se ve en el cliente del guardia aunque no vea al ladrón: es información física del mundo y se acepta en el PoC. Si en el playtest delata demasiado, se filtrará como la ganzúa.
3. **Las cámaras CCTV** no muestran al ladrón a los guardias en red, porque el cliente del guardia no tiene su posición. Queda para después del PoC.
4. **Sin predicción**, por internet (más de 30 ms) el propio personaje responderá con retraso. Está aceptado para el PoC en LAN.
5. **Tamaño**: es la FEAT más grande hasta ahora. Si PKG-3 se atasca en agy, se partirá en servidor y cliente en dos paquetes.
