## Montajes y trazas del servidor para las pruebas de integración de red (FEAT-014).
## Los montajes solo se crean con `--net-test=<montaje>` y build de depuración. Las líneas
## `NETLOG {json}` solo se escriben con `--net-log` o `--net-test=<montaje>` en un build
## de depuración, para no llenar la consola al jugar.
class_name NetTestHooks
extends RefCounted

## Prefijo que el script de QA busca en la salida estándar del servidor
const LOG_PREFIX: String = "NETLOG "

const MOUNT_CAPTURE: String = "capture"
const MOUNT_FAR_NOISE: String = "far_noise"
const MOUNT_LOOT: String = "loot"

## Rayos horizontales que prueba el montaje far_noise antes de rendirse
const FAR_NOISE_DIRECTIONS: int = 32

## Altura del rayo de comprobación de paredes en el montaje far_noise
const FAR_NOISE_PROBE_HEIGHT: float = 0.9

## Los argumentos de usuario no cambian en ejecución: se evalúan una vez
static var _logging_checked: bool = false
static var _logging_enabled: bool = false

var _map: HeistMap3D = null


## Crea los montajes si el servidor los pidió; null si no hay nada que montar
static func create(map: HeistMap3D) -> NetTestHooks:
	if not OS.is_debug_build():
		return null
	var mount: String = _mount_from_args()
	if mount.is_empty():
		return null
	var hooks: NetTestHooks = NetTestHooks.new()
	hooks._map = map
	var tree: SceneTree = map.get_tree()
	if tree != null:
		# Un frame de física después, para que el espacio físico ya tenga los cuerpos
		tree.physics_frame.connect(hooks._apply_mount.bind(mount), CONNECT_ONE_SHOT)
	else:
		hooks._apply_mount(mount)
	return hooks


## Escribe una línea NETLOG con el evento serializado (solo con --net-log o --net-test
## en los argumentos de usuario y en un build de depuración)
static func log_event(event: Dictionary) -> void:
	if not is_logging_enabled():
		return
	print(LOG_PREFIX + JSON.stringify(event))


## Verdadero solo si el servidor pidió trazas por CLI y es un build de depuración
static func is_logging_enabled() -> bool:
	if not _logging_checked:
		_logging_checked = true
		_logging_enabled = OS.is_debug_build() and _has_logging_arg()
	return _logging_enabled


static func _has_logging_arg() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--net-log" or arg.begins_with("--net-test="):
			return true
	return false


static func _mount_from_args() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--net-test="):
			return arg.trim_prefix("--net-test=")
	return ""


func _apply_mount(mount: String) -> void:
	match mount:
		MOUNT_CAPTURE:
			_mount_capture()
		MOUNT_FAR_NOISE:
			_mount_far_noise()
		MOUNT_LOOT:
			_mount_loot()
		_:
			print("[NetTestHooks] Montaje desconocido: %s" % mount)


## Guardia 1 a 1.0 m del ladrón, mirándolo
func _mount_capture() -> void:
	var thief: ThiefController3D = _thief()
	var guard: GuardController3D = _first_guard()
	if thief == null or guard == null:
		return
	var offset: Vector3 = Vector3(1.0, 0.0, 0.0)
	guard.global_position = thief.global_position + offset
	guard.look_target_position = thief.global_position
	var to_thief: Vector3 = (thief.global_position - guard.global_position).slide(Vector3.UP)
	if to_thief.length_squared() > 0.001:
		guard.rotation.y = atan2(-to_thief.x, -to_thief.z)
	print("[NetTestHooks] Montaje capture: guardia a 1.0 m del ladrón")


## Guardia 1 a 20 m del ladrón en la dirección más despejada disponible
func _mount_far_noise() -> void:
	var thief: ThiefController3D = _thief()
	var guard: GuardController3D = _first_guard()
	if thief == null or guard == null:
		return
	var best_dir: Vector3 = Vector3.FORWARD
	var best_distance: float = 0.0
	for i: int in range(FAR_NOISE_DIRECTIONS):
		var angle: float = TAU * float(i) / float(FAR_NOISE_DIRECTIONS)
		var dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var distance: float = _clear_distance(thief.global_position, dir, 20.0)
		if distance > best_distance:
			best_distance = distance
			best_dir = dir
	guard.global_position = thief.global_position + best_dir * best_distance
	guard.look_target_position = thief.global_position
	print("[NetTestHooks] Montaje far_noise: guardia a %.1f m del ladrón" % best_distance)


## Ladrón a 1.0 m de un botín ligero, mirándolo
func _mount_loot() -> void:
	var thief: ThiefController3D = _thief()
	var loot: LootItem3D = _first_light_loot()
	if thief == null or loot == null:
		return
	var forward: Vector3 = -thief.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var floor_level: Vector3 = thief.global_position
	loot.global_position = floor_level + forward * 1.0 + Vector3(0.0, -0.15, 0.0)
	thief.look_target_position = loot.global_position
	print("[NetTestHooks] Montaje loot: ladrón a 1.0 m del botín '%s'" % loot.loot_name)


func _thief() -> ThiefController3D:
	return _map.thief if _map != null else null


func _first_guard() -> GuardController3D:
	if _map == null or _map.guards.is_empty():
		return null
	return _map.guards[0]


func _first_light_loot() -> LootItem3D:
	if _map == null or not _map.is_inside_tree():
		return null
	for node: Node in _map.get_tree().get_nodes_in_group(&"net_state"):
		if node is LootItem3D:
			var loot: LootItem3D = node as LootItem3D
			if not loot.is_heavy and not loot.is_collected:
				return loot
	return null


## Distancia horizontal sin muros desde origin hasta max_distance en dirección dir
func _clear_distance(origin: Vector3, dir: Vector3, max_distance: float) -> float:
	if _map == null or _map.get_world_3d() == null:
		return max_distance
	var from_pos: Vector3 = origin + Vector3(0.0, FAR_NOISE_PROBE_HEIGHT, 0.0)
	var to_pos: Vector3 = from_pos + dir * max_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1)
	var hit: Dictionary = _map.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return max_distance
	var hit_pos: Vector3 = hit.get("position", to_pos) as Vector3
	return clampf(PerceptionRules.horizontal_distance(from_pos, hit_pos), 1.0, max_distance)
