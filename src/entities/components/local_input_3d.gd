## Lectura del teclado y ratón del jugador local (solo la usa PlayerBase3D.gather_input).
class_name LocalInput3D
extends RefCounted


## Diccionario con movement_vector (Vector2), is_sprinting, is_sneaking, crouch
## (just_pressed) y look_target (Vector3). Usa move_* o ui_* como hoy.
static func read(player: PlayerBase3D, cam: Camera3D) -> Dictionary:
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

	var target_pos: Vector3 = project_cursor(player, cam)

	return {
		"movement_vector": move_vec,
		"is_sprinting": sprint,
		"is_sneaking": sneak,
		"look_target": target_pos,
		"crouch": crouch_pressed,
	}


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
