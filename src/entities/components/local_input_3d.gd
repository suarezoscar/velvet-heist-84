## Lectura del teclado y ratón del jugador local (solo la usa PlayerBase3D.gather_input).
## El personaje mira hacia donde anda; el ratón solo cuenta al apuntar o barrer (#112).
class_name LocalInput3D
extends RefCounted

## Distancia (m) del punto mirado cuando se mira hacia donde se anda
const FACING_DISTANCE: float = 3.0

## Con un menú abierto encima de la partida (pausa), el jugador local no se mueve ni actúa
static var blocked: bool = false

## Último lado hacia el que anduvo el jugador local, y de quién es (#112)
static var _facing: Vector3 = Vector3.ZERO
static var _facing_owner: int = 0


## Diccionario con movement_vector (Vector2), is_sprinting, is_sneaking, crouch
## (just_pressed) y look_target (Vector3). Usa move_* o ui_* como hoy.
static func read(player: PlayerBase3D, cam: Camera3D) -> Dictionary:
	if blocked:
		return {
			"movement_vector": Vector2.ZERO,
			"is_sprinting": false,
			"is_sneaking": false,
			"look_target": player.look_target_position if player != null else Vector3.ZERO,
			"crouch": false,
		}
	var left: StringName = &"move_left" if InputMap.has_action("move_left") else &"ui_left"
	var right: StringName = &"move_right" if InputMap.has_action("move_right") else &"ui_right"
	var up: StringName = &"move_up" if InputMap.has_action("move_up") else &"ui_up"
	var down: StringName = &"move_down" if InputMap.has_action("move_down") else &"ui_down"
	var move_vec: Vector2 = Input.get_vector(left, right, up, down)

	var sprint: bool = Input.is_action_pressed("sprint") if InputMap.has_action("sprint") else false
	var sneak: bool = Input.is_action_pressed("sneak") if InputMap.has_action("sneak") else false
	var crouch_pressed: bool = (
		Input.is_action_just_pressed("crouch") if InputMap.has_action("crouch") else false
	)

	var target_pos: Vector3 = look_target(player, move_vec, aims_with_mouse(player), cam)

	return {
		"movement_vector": move_vec,
		"is_sprinting": sprint,
		"is_sneaking": sneak,
		"look_target": target_pos,
		"crouch": crouch_pressed,
	}


## Apunta con el ratón: el ladrón apuntando la moneda o el guardia barriendo con la linterna
static func aims_with_mouse(player: PlayerBase3D) -> bool:
	if player is ThiefController3D:  # también el fotograma en que la suelta y sale la moneda
		return CoinTrigger.aiming or Input.is_action_just_released(CoinTrigger.ACTION)
	return player is GuardController3D and GuardFlashlight.held


## Hacia dónde mira (#112): al ratón si apunta; si no, hacia donde anda, y parado sigue
## mirando al último lado al que anduvo
static func look_target(
	player: PlayerBase3D, move_vec: Vector2, aiming: bool, cam: Camera3D
) -> Vector3:
	if player == null:
		return Vector3.ZERO
	if aiming:
		return project_cursor(player, cam)
	if _facing_owner != player.get_instance_id() or _facing == Vector3.ZERO:
		_facing_owner = player.get_instance_id()
		_facing = (-player.global_basis.z).slide(Vector3.UP).normalized()
	if move_vec.length_squared() > 0.01:
		var walk: Vector3 = Vector3(move_vec.x, 0.0, move_vec.y)
		_facing = walk.rotated(Vector3.UP, deg_to_rad(45.0)).normalized()
	return player.global_position + _facing * FACING_DISTANCE


## Lo mismo que hoy hace PlayerBase3D.project_cursor_on_ground
static func project_cursor(player: PlayerBase3D, cam: Camera3D) -> Vector3:
	if player == null:
		return Vector3.ZERO
	if cam == null or not player.is_inside_tree():
		return player.look_target_position
	var viewport: Viewport = player.get_viewport()
	if viewport == null:
		return player.look_target_position
	var mouse_screen_pos: Vector2 = viewport.get_mouse_position()
	var ground_plane: Plane = Plane(Vector3.UP, player.global_position.y)
	var hit: Variant = ground_plane.intersects_ray(
		cam.project_ray_origin(mouse_screen_pos), cam.project_ray_normal(mouse_screen_pos)
	)
	return hit as Vector3 if hit != null else player.look_target_position
