## @file steal_minigame.gd
## Minijuego de robo en la propia pieza (heist.md R9a-R9c, #119). Lo lleva la pieza en quien
## tiene la autoridad; el ladrón solo manda teclas. Lógica pura, salvo los ruidos.
## - SWAP, «Dar el cambiazo»: con E pulsada se llena el progreso en swap_time s; la aguja se va
##   hacia un lado (cada vez más deprisa) y ← → la empujan de vuelta. Fuera de la franja verde
##   falla: progreso a 0. Soltar E pausa, pero la aguja sigue yéndose.
## - BRIDGE, «Puentear el sensor»: el piloto se enciende y se apaga solo; E con el piloto
##   apagado es un acierto (uno por apagado) y con él encendido, un fallo que vuelve a 0.
## Fallar suena (fail_noise_radius) y nunca hace saltar la alarma. Alejarse más de task_leash
## m lo cancela.
class_name StealMinigame
extends RefCounted

enum Kind { NONE, SWAP, BRIDGE }
enum Result { RUNNING, DONE, CANCELLED }

const RULES: StealMinigameRules = preload("res://data/balance/steal_minigames.tres")
const HEIST: HeistRules = preload("res://data/balance/heist_rules.tres")

var kind: Kind = Kind.NONE
var actor: Node3D = null
## Fallos en este minijuego (el panel suena al fallar)
var fails: int = 0
## SWAP: aguja de −1 a 1, progreso de 0 a 1 y si E sigue pulsada
var needle: float = 0.0
var progress: float = 0.0
var holding: bool = false
## BRIDGE: piloto encendido y aciertos seguidos
var lit: bool = true
var hits: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _push: float = 0.0
var _dir: float = 1.0
var _flip_left: float = 0.0
var _light_left: float = 0.0
var _pressed_this_off: bool = false
var _work_left: float = 0.0
var _origin: Vector3 = Vector3.ZERO
var _cancelled: bool = false
var _armed: bool = false


static func start(game_kind: Kind, who: Node3D) -> StealMinigame:
	var game: StealMinigame = StealMinigame.new()
	game.kind = game_kind
	game.actor = who
	game.rng.randomize()
	game._origin = who.global_position
	game.holding = game_kind == Kind.SWAP  # la E que lo abre ya está pulsada
	game._dir = 1.0 if game.rng.randf() < 0.5 else -1.0
	game._flip_left = game._flip_time()
	game._light_left = game._on_time()
	game._work_left = RULES.work_noise_interval
	return game


## Pieza en cuyo minijuego está actor (en el cliente, la que llega con su estado privado:
## solo hay un ladrón)
static func piece_of(who: Node3D) -> TargetPiece3D:
	if who == null or not who.is_inside_tree():
		return null
	for node: Node in who.get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		if piece != null and piece.is_playing():
			if piece.game == null or piece.game.actor == who:
				return piece
	return null


## Cierra el minijuego que esté jugando who (golpe de porra, Q, desconexión)
static func cancel_for(who: Node3D) -> void:
	var piece: TargetPiece3D = piece_of(who)
	if piece != null and piece.game != null:
		piece.game = null


## Sin red, las teclas del ladrón local que no son movimiento: soltar E y Esc
static func poll_local(thief: PlayerBase3D) -> void:
	if piece_of(thief) == null:
		return
	if InputMap.has_action(&"interact") and Input.is_action_just_released(&"interact"):
		thief.perform_action(&"interact_release")
	if InputMap.has_action(&"ui_cancel") and Input.is_action_just_pressed(&"ui_cancel"):
		thief.perform_action(&"dial_cancel")


## E: en la balanza vuelve a sujetar; en el sensor, un intento
func press() -> void:
	if kind == Kind.SWAP:
		holding = true
	elif kind == Kind.BRIDGE:
		if lit:
			_fail()
		elif not _pressed_this_off:
			_pressed_this_off = true
			hits += 1
			_noise(RULES.work_noise_radius)


## Soltar E: la balanza se queda en pausa
func release() -> void:
	holding = false


## Teclas de movimiento (sin girar, de pantalla): ← → empujan la aguja; las que el minijuego no
## usa lo cancelan
func steer(move: Vector2) -> void:
	var cancels: bool = absf(move.y) >= 0.5 if kind == Kind.SWAP else move.length() >= 0.5
	if not cancels:
		_armed = true
	elif _armed:  # la tecla que ya se mantenía al abrirlo no cuenta: hace falta soltarla
		cancel()
		return
	_push = clampf(move.x, -1.0, 1.0) if kind == Kind.SWAP else 0.0


func cancel() -> void:
	_cancelled = true


func is_done() -> bool:
	if kind == Kind.SWAP:
		return progress >= 1.0
	return hits >= RULES.bridge_hits


## Avanza el minijuego (solo quien tiene la autoridad)
func tick(delta: float) -> Result:
	if _cancelled or GameManager.is_match_over() or not is_instance_valid(actor):
		return Result.CANCELLED
	if actor.global_position.distance_to(_origin) > HEIST.task_leash:
		return Result.CANCELLED
	if kind == Kind.SWAP:
		_tick_swap(delta)
	else:
		_tick_bridge(delta)
	return Result.DONE if is_done() else Result.RUNNING


## Velocidad de la aguja según el progreso (R9b: d(p))
func drift_speed() -> float:
	return lerpf(RULES.needle_drift_start, RULES.needle_drift_end, clampf(progress, 0.0, 1.0))


## Estado para el panel del ladrón (y su estado privado de red)
func to_view() -> Dictionary:
	return {
		"game": int(kind),
		"needle": snappedf(needle, 0.001),
		"progress": snappedf(progress, 0.001),
		"holding": holding,
		"lit": lit,
		"hits": hits,
		"fails": fails,
	}


func _tick_swap(delta: float) -> void:
	_flip_left -= delta
	if _flip_left <= 0.0:
		_dir = -_dir
		_flip_left = _flip_time()
	needle += (_dir * drift_speed() + _push * RULES.needle_correct_speed) * delta
	needle = clampf(needle, -1.0, 1.0)
	if absf(needle) > RULES.needle_green_half:
		_fail()
		needle = 0.0
		progress = 0.0
		return
	if not holding:
		return
	progress = minf(1.0, progress + delta / RULES.swap_time)
	_work_left -= delta
	if _work_left <= 0.0:
		_work_left = RULES.work_noise_interval
		_noise(RULES.work_noise_radius)


func _tick_bridge(delta: float) -> void:
	_light_left -= delta
	if _light_left > 0.0:
		return
	lit = not lit
	_pressed_this_off = false
	_light_left = _on_time() if lit else RULES.pilot_off_time


func _fail() -> void:
	fails += 1
	hits = 0
	_noise(RULES.fail_noise_radius)


func _noise(radius: float) -> void:
	if is_instance_valid(actor) and actor.is_inside_tree():
		NoiseEmit.emit(actor.global_position, radius, &"thief", NoiseEmit.MECHANISM, actor)


func _flip_time() -> float:
	return rng.randf_range(RULES.needle_flip_min, RULES.needle_flip_max)


func _on_time() -> float:
	return rng.randf_range(RULES.pilot_on_min, RULES.pilot_on_max)
