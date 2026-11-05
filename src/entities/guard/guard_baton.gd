## @file guard_baton.gd
## Reglas del guardia que no necesitan su estado interno: validación autoritativa del golpe
## de porra y estamina/carrera. GuardController3D delega aquí.
class_name GuardBaton
extends RefCounted


## Valida de forma autoritativa en el servidor si un golpe cuerpo a cuerpo es legítimo
static func valid_hit(guard: GuardController3D, thief: ThiefController3D) -> bool:
	if thief == null or thief.in_vent:
		return false
	if guard.perception == null:
		guard.perception = load(GuardController3D.PERCEPTION_PROFILE_PATH)
	var perception: PerceptionProfile = guard.perception
	var dist: float = PerceptionRules.horizontal_distance(
		guard.global_position, thief.global_position
	)
	if dist > perception.melee_range:
		return false
	# Hacia donde mira (o al ratón si barre con la linterna), no a la espalda (#112)
	if not PerceptionRules.is_in_flashlight_cone(
		guard.global_position,
		guard.look_target_position - guard.global_position,
		thief.global_position,
		perception.melee_range + 0.01,
		perception.melee_half_angle_deg
	):
		return false
	if guard.is_inside_tree() and guard.get_world_3d() != null:
		var space_state: PhysicsDirectSpaceState3D = guard.get_world_3d().direct_space_state
		if space_state != null:
			var offset: Vector3 = Vector3(0.0, perception.torso_height, 0.0)
			var from_pos: Vector3 = guard.global_position + offset
			var to_pos: Vector3 = thief.global_position + offset
			if not GuardSenses.has_line_of_sight(space_state, from_pos, to_pos):
				return false
	return true


## Estamina y carrera: con calma o sin aliento no se corre; correr gasta y andar recupera
static func process_stamina(guard: GuardController3D, delta: float, input_dir: Vector2) -> void:
	var calm: bool = guard.is_inside_tree() and not AlertDirector.alarm_on(guard.get_tree())  # #116
	if guard.is_sprinting and (calm or guard.stamina <= 5.0 or input_dir.length_squared() <= 0.01):
		guard.is_sprinting = false
	var rate: float = (
		-guard.stamina_drain_rate if guard.is_sprinting else guard.stamina_recovery_rate
	)
	guard.stamina = clampf(guard.stamina + rate * delta, 0.0, guard.max_stamina)
