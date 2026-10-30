## @file test_noise_meter.gd
## Tests de aceptación para el vúmetro de ruido y sus ritmos (FEAT-012 Criterios 7 y 8).
## Comprueba invariantes de balance del vúmetro y su comportamiento reactivo en el HUD.
extends GutTest

const NOISE_FEEDBACK_PATH: String = "res://data/balance/noise_feedback.tres"
const MOVEMENT_THIEF_PATH: String = "res://data/balance/movement_thief.tres"
const STEP_NOISE_PATH: String = "res://data/balance/step_noise.tres"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud_84.tscn"


func after_each() -> void:
	GameManager.current_state = GameManager.MatchState.LOBBY


## Criterio 7: Invariante 22: ritmo de caída del vúmetro y escala completa
func test_inv22_meter_rhythm() -> void:
	var feedback: NoiseFeedbackProfile = load(NOISE_FEEDBACK_PATH) as NoiseFeedbackProfile
	assert_not_null(feedback, "noise_feedback.tres debe cargarse")

	var mov: MovementProfile = load(MOVEMENT_THIEF_PATH) as MovementProfile
	assert_not_null(mov, "movement_thief.tres debe cargarse")

	var step_noise: StepNoiseProfile = load(STEP_NOISE_PATH) as StepNoiseProfile
	assert_not_null(step_noise, "step_noise.tres debe cargarse")

	var total_decay: float = feedback.meter_hold_time + feedback.meter_fall_time
	assert_lte(
		total_decay,
		CharacterAnimator3D.step_interval(
			MovementProfile.Mode.SNEAK, mov.speed_for(MovementProfile.Mode.SNEAK)
		),
		"Invariante 22: hold + fall debe ser <= el intervalo entre pasos en sigilo"
	)
	assert_lte(
		total_decay,
		CharacterAnimator3D.step_interval(
			MovementProfile.Mode.CROUCH, mov.speed_for(MovementProfile.Mode.CROUCH)
		),
		"Invariante 22: hold + fall debe ser <= el intervalo entre pasos agachado"
	)
	assert_gte(
		feedback.meter_full_scale,
		step_noise.min_radius * 10.0,
		"Invariante 22: meter_full_scale debe ser >= min_radius * 10"
	)


## Criterio 8: Dinámica del vúmetro y visibilidad según rol local
func test_meter_dynamics() -> void:
	var feedback: NoiseFeedbackProfile = load(NOISE_FEEDBACK_PATH) as NoiseFeedbackProfile
	var map: HeistMap3D = autofree(HeistMap3D.new())

	var hud_scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var hud: HUD84 = hud_scene.instantiate() as HUD84
	hud.name = "HUD84"
	map.add_child(hud)

	var camera: Camera3D = Camera3D.new()
	camera.name = "IsometricCamera3D"
	map.add_child(camera)

	var thief: ThiefController3D = autofree(ThiefController3D.new())
	thief.name = "Thief"
	thief.position = Vector3.ZERO
	map.add_child(thief)

	var guard: GuardController3D = autofree(GuardController3D.new())
	guard.name = "Guard"
	guard.position = Vector3(10.0, 0.0, 10.0)
	map.add_child(guard)

	add_child_autofree(map)
	map.set_physics_process(false)
	thief.set_physics_process(false)
	guard.set_physics_process(false)

	var meter: NoiseMeter84 = hud.get_noise_meter()
	assert_not_null(meter, "El vúmetro debe existir en el HUD")

	# 1. Con ladrón local: vúmetro y ExposurePanel visibles sin estado de exposición
	map.set_local_player(thief)
	map.noise_audio_presenter._physics_process(0.0)
	assert_true(meter.visible, "El vúmetro debe ser visible con el ladrón local")
	assert_true(
		hud.exposure_panel.visible,
		"ExposurePanel debe ser visible para el ladrón aunque no haya exposición"
	)

	# 2. Ruido propio de radio 3.5 deja nivel en 3.5 y 4 segmentos encendidos
	SignalBus.noise_event_3d.emit(thief.global_position, 3.5, &"thief", &"step", thief)
	assert_almost_eq(meter.get_level(), 3.5, 0.01, "Nivel tras ruido propio de 3.5 debe ser 3.5")
	assert_eq(meter.lit_segments(), 4, "Radio 3.5 sobre escala 10 enciende 4 segmentos")
	assert_false(meter.is_over(), "Radio 3.5 no satura")

	# Sigue igual a los meter_hold_time
	meter._process(feedback.meter_hold_time)
	assert_almost_eq(meter.get_level(), 3.5, 0.01, "Mantiene nivel durante meter_hold_time")

	# A mitad de la caída vale 3.5 * 0.5 +- 0.05
	var half_fall: float = feedback.meter_fall_time * 0.5
	meter._process(half_fall)
	assert_almost_eq(meter.get_level(), 3.5 * 0.5, 0.05, "A mitad de caída vale 3.5 * 0.5 +- 0.05")

	# Vale 0 tras hold + fall (la otra mitad de fall)
	meter._process(half_fall)
	assert_almost_eq(meter.get_level(), 0.0, 0.01, "Tras hold + fall vale 0")
	assert_eq(meter.lit_segments(), 0, "Al llegar a 0 no hay segmentos encendidos")

	# 3. Radio de 10.5 enciende el LED de saturación
	SignalBus.noise_event_3d.emit(thief.global_position, 10.5, &"thief", &"step", thief)
	assert_almost_eq(meter.get_level(), 10.5, 0.01, "Nivel registra 10.5")
	assert_true(meter.is_over(), "Radio 10.5 activa LED de saturación")

	# 4. Los ruidos de guardia no mueven el vúmetro
	meter._process(1.0)
	assert_almost_eq(meter.get_level(), 0.0, 0.01, "Vúmetro en reposo a 0")
	SignalBus.noise_event_3d.emit(guard.global_position, 6.0, &"guard", &"impact", guard)
	assert_almost_eq(meter.get_level(), 0.0, 0.001, "Ruido de guardia no mueve el vúmetro")

	# 5. Con un guardia local, el vúmetro está oculto y ExposurePanel se oculta
	map.set_local_player(guard)
	map.noise_audio_presenter._physics_process(0.0)
	assert_false(meter.visible, "El vúmetro debe estar oculto con guardia local")
	assert_false(
		hud.exposure_panel.visible,
		"ExposurePanel debe estar oculto con guardia local sin exposición"
	)
