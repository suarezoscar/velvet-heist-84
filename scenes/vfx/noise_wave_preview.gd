## @file noise_wave_preview.gd
## Escena aislada de las miniondas de ruido (#114, regla 04): lanza ondas de varios radios en bucle
## sobre un suelo oscuro, con la cámara isométrica del juego.
extends Node3D

## Radios finales (m) que recorre el bucle: del mínimo al máximo de noise_feedback.tres
const RADII: Array[float] = [0.35, 0.6, 0.9, 1.4]
const FEEDBACK: NoiseFeedbackProfile = preload("res://data/balance/noise_feedback.tres")

var _pool: NoiseWavePool = NoiseWavePool.new()
var _timer: float = 0.0
var _index: int = 0


func _ready() -> void:
	add_child(_pool)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = FEEDBACK.wave_time * 0.8
	var x: float = (float(_index % RADII.size()) - 1.5) * 3.2
	_pool.spawn(Vector3(x, 0.0, 0.0), RADII[_index % RADII.size()], FEEDBACK.wave_time)
	_index += 1
