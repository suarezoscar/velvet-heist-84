## @file player_steps.gd
## Pasos de un personaje: radio acústico según modo, superficie y bando, y emisión del ruido
## y de la huella (FEAT-008). PlayerBase3D delega aquí.
class_name PlayerSteps
extends RefCounted


## Calcula el radio acústico del paso según modo, superficie y bando
static func step_radius(player: PlayerBase3D) -> float:
	var s_noise: StepNoiseProfile = (
		(
			player.step_noise
			if player.step_noise != null
			else load(PlayerBase3D.DEFAULT_STEP_NOISE_PATH)
		)
		as StepNoiseProfile
	)
	var profile: StepNoiseProfile = s_noise if s_noise != null else StepNoiseProfile.new()
	var surface_mult: float = (
		player.surface_detector.get_surface_noise_multiplier()
		if player.surface_detector != null
		else 1.0
	)
	var movement: MovementProfile = player.movement_profile
	var team_mult: float = movement.team_noise_mult if movement != null else 1.0
	return profile.radius_for(player.get_move_mode(), surface_mult, team_mult)


## Emite el ruido del paso y la huella en la posición del personaje
static func emit_step(player: PlayerBase3D) -> void:
	var radius: float = step_radius(player)
	NoiseEmit.emit(player.global_position, radius, player.team_id, NoiseEmit.STEP, player)
	SignalBus.footprint_stepped_3d.emit(player.global_position, player.rotation.y)


## Cadencia de los pasos: suma el tiempo y, al cumplirse el intervalo del modo y la velocidad,
## emite el paso. Devuelve el temporizador actualizado
static func advance(player: PlayerBase3D, timer: float, delta: float) -> float:
	var interval: float = CharacterAnimator3D.step_interval(
		player.get_move_mode(), player.velocity.slide(Vector3.UP).length()
	)
	timer += delta
	if timer < interval:
		return timer
	player._emit_step_sound()
	return 0.0
