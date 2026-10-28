## @file guard_sleep.gd
## Sueño del guardia y café (heist.md R5). Hijo «Sleep» de cada guardia humano; lo coloca
## HeistBuilder cuando el nivel tiene cafetera. El servidor (o la partida sin red) decide:
## si el guardia acampa (CampingMeter), el sueño sube; somnoliento bosteza (un ruido que se
## oye) y ve menos; agotado además da cabezadas sin ver nada. Solo se quita con café en la
## cafetera de la garita, que deja un rato despejado. El nivel de sueño, las cabezadas y el
## café van al cliente de su guardia como estado privado. FEAT-033: el café drogado por el
## ladrón le duerme RULES.drug_nap_time s; la alarma le despeja (adrenalina) y, al apagarse las
## luces de alarma, le da el bajón. Que da una cabezada lo ven todos («Zzz», SleepBubble3D).
class_name GuardSleep
extends Node

enum Stage { AWAKE, DROWSY, EXHAUSTED }

const RULES: GuardSleepRules = preload("res://data/balance/guard_sleep.tres")
const PERCEPTION: PerceptionProfile = preload("res://data/balance/perception_guard.tres")
## Paso con el que se replica el nivel de sueño (evita mandar cada cambio pequeño)
const LEVEL_STEP: float = 0.05

var guard: GuardController3D = null
## Sueño de 0 a 1
var level: float = 0.0
var nodding: bool = false
## Segundos que quedan sirviéndose café (0: no se está sirviendo)
var drinking_left: float = 0.0
## Segundos despejado tras el café
var fresh_left: float = 0.0
## El café estaba drogado: está dormido (dura lo que su cabezada)
var drugged: bool = false
var _meter: CampingMeter = CampingMeter.new()
var _yawn_timer: float = 0.0
var _nod_timer: float = 0.0
var _nod_left: float = 0.0
var _coffee_spot: Vector3 = Vector3.ZERO
var _profiles: Dictionary = {}
var _machine: CoffeeMachine3D = null
var _bubble: SleepBubble3D = null


## true si el guardia mira los monitores y no está dando una cabezada (en la cabezada no ve
## nada, tampoco las cámaras)
static func sees_cameras(target: GuardController3D) -> bool:
	if target == null or not target.is_watching_monitors():
		return false
	var sleep: GuardSleep = target.get_node_or_null("Sleep") as GuardSleep
	return sleep == null or not sleep.nodding


## true si el guardia está dando una cabezada (no ve nada)
static func sees_nothing(target: GuardController3D) -> bool:
	var sleep: GuardSleep = (
		target.get_node_or_null("Sleep") as GuardSleep if target != null else null
	)
	return sleep != null and sleep.nodding


static func attach(target: GuardController3D) -> GuardSleep:
	var sleep: GuardSleep = GuardSleep.new()
	sleep.name = "Sleep"
	sleep.guard = target
	target.add_child(sleep)
	return sleep


func _ready() -> void:
	add_to_group(&"net_state")
	if guard == null:
		guard = get_parent() as GuardController3D
	_bubble = SleepBubble3D.attach(guard)


## Los clientes no corren _physics_process (net_state): el «Zzz» se pinta aquí
func _process(_delta: float) -> void:
	if _bubble != null:
		_bubble.visible = nodding


func stage() -> Stage:
	if level >= RULES.exhausted_at:
		return Stage.EXHAUSTED
	if level >= RULES.drowsy_at:
		return Stage.DROWSY
	return Stage.AWAKE


## Solo duermen los guardias humanos, con la partida en marcha
func is_active() -> bool:
	return (
		guard != null
		and not guard.is_ai_controlled
		and GameManager.is_simulating()
		and GameManager.current_state == GameManager.MatchState.IN_PROGRESS
	)


func _physics_process(delta: float) -> void:
	if not is_active():
		return
	step(delta)


## Un tick de la lógica del sueño (lo usan los tests)
func step(delta: float) -> void:
	var max_samples: int = roundi(RULES.window / CampingMeter.SAMPLE_STEP)
	_meter.feed(guard.global_position, delta, max_samples)
	if drinking_left > 0.0:
		_drink(delta)
	fresh_left = maxf(0.0, fresh_left - delta)
	var camping: bool = _meter.is_camping(RULES.radius, RULES.linger_ratio, max_samples)
	var alarm: AlertDirector = AlertDirector.of(get_tree())
	var alarmed: bool = alarm != null and alarm.level == AlertDirector.Level.ALARM
	if camping and fresh_left <= 0.0 and not guard.is_perceiving_thief and not alarmed:
		level = minf(1.0, level + RULES.rise_rate * delta)
	_update_yawn(delta)
	_update_nod(delta)
	_apply_perception()


## La cafetera: empieza a servirse (false si ya se está sirviendo)
func start_coffee(machine: CoffeeMachine3D = null) -> bool:
	if drinking_left > 0.0:
		return false
	drinking_left = RULES.coffee_time
	_coffee_spot = guard.global_position
	_machine = machine
	return true


## Adrenalina: salta la alarma y se despeja (no da para un rato despejado)
func wake_up() -> void:
	if drugged:
		return  # drogado no lo despierta ni la alarma
	level = 0.0
	nodding = false
	_nod_left = 0.0


## Bajón tras las luces de alarma: el sueño sube de golpe hasta RULES.crash_level
func crash() -> void:
	if fresh_left <= 0.0:
		level = maxf(level, RULES.crash_level)


func _drink(delta: float) -> void:
	if guard.global_position.distance_to(_coffee_spot) > RULES.coffee_leash:
		drinking_left = 0.0  # se ha ido: café a medias, no cuenta
		return
	drinking_left -= delta
	if drinking_left <= 0.0:
		drinking_left = 0.0
		if _machine != null and _machine.take_cup():
			_fall_asleep()
			return
		level = 0.0
		nodding = false
		_nod_left = 0.0
		fresh_left = RULES.fresh_time
		_meter.clear()


## Café drogado: se queda dormido RULES.drug_nap_time s y despierta agotado
func _fall_asleep() -> void:
	level = 1.0
	fresh_left = 0.0
	drugged = true
	nodding = true
	_nod_left = RULES.drug_nap_time
	_nod_timer = RULES.nod_interval
	print("[GuardSleep] %s se ha bebido el café drogado" % guard.name)


func _update_yawn(delta: float) -> void:
	if stage() == Stage.AWAKE:
		_yawn_timer = RULES.yawn_interval * 0.5
		return
	_yawn_timer -= delta
	if _yawn_timer <= 0.0:
		_yawn_timer = RULES.yawn_interval
		NoiseEmit.emit(guard.global_position, RULES.yawn_radius, &"guard", &"voice", guard)


func _update_nod(delta: float) -> void:
	if _nod_left > 0.0:
		_nod_left -= delta
		nodding = _nod_left > 0.0
		drugged = drugged and nodding
		return
	if stage() != Stage.EXHAUSTED:
		_nod_timer = RULES.nod_interval
		nodding = false
		return
	_nod_timer -= delta
	if _nod_timer <= 0.0:
		_nod_timer = RULES.nod_interval
		_nod_left = RULES.nod_time
		nodding = true


## Cambia el perfil de percepción del guardia por uno con los alcances de vista escalados
func _apply_perception() -> void:
	var factor: float = 1.0
	if nodding:
		factor = 0.0
	elif stage() != Stage.AWAKE:
		factor = RULES.drowsy_sight
	guard.perception = _profile_for(factor)
	if guard.maglite_light != null:
		guard.maglite_light.spot_range = guard.perception.flashlight_range


func _profile_for(factor: float) -> PerceptionProfile:
	if is_equal_approx(factor, 1.0):
		return PERCEPTION
	if not _profiles.has(factor):
		var profile: PerceptionProfile = PERCEPTION.duplicate() as PerceptionProfile
		profile.lit_sight_range *= factor
		profile.flashlight_range *= factor
		profile.proximity_radius *= factor
		_profiles[factor] = profile
	return _profiles[factor]


## A todos: si da una cabezada (el «Zzz» solo se ve si se ve al guardia, por la niebla)
func get_net_state() -> Dictionary:
	return {"zzz": nodding}


func get_net_state_private() -> Dictionary:
	return {
		"level": snappedf(level, LEVEL_STEP),
		"nod": nodding,
		"drinking": drinking_left > 0.0,
		"fresh": fresh_left > 0.0,
		"drug": drugged,
	}


## Solo lo recibe su guardia: el rol sale del orden en map.guards, como en NetSession
func net_private_audience() -> StringName:
	var map: HeistMap3D = guard.get_parent() as HeistMap3D if guard != null else null
	var index: int = map.guards.find(guard) if map != null else -1
	if index < 0 or index + 1 >= NetConfig.ROLES.size():
		return &""
	return NetConfig.ROLES[index + 1]


func apply_net_state(state: Dictionary) -> void:
	if state.has("level"):
		level = float(state["level"])
	if state.has("nod"):
		nodding = bool(state["nod"])
	if state.has("zzz"):
		nodding = bool(state["zzz"])
	if state.has("drug"):
		drugged = bool(state["drug"])
	if state.has("drinking"):
		drinking_left = RULES.coffee_time if bool(state["drinking"]) else 0.0
	if state.has("fresh"):
		fresh_left = RULES.fresh_time if bool(state["fresh"]) else 0.0
