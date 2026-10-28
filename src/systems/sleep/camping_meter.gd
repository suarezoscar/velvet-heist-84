## @file camping_meter.gd
## ¿Acampa el guardia? (heist.md R5). Guarda su posición cada SAMPLE_STEP segundos durante la
## ventana y mira qué parte cae dentro de un círculo de radio dado alrededor de la posición
## media. Dar pasitos dentro del círculo no lo engaña. Lógica pura.
class_name CampingMeter
extends RefCounted

const SAMPLE_STEP: float = 0.5

var _samples: Array[Vector2] = []
var _timer: float = 0.0


## Añade la posición si toca muestrear; max_samples = ventana / SAMPLE_STEP
func feed(position: Vector3, delta: float, max_samples: int) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SAMPLE_STEP
	_samples.append(Vector2(position.x, position.z))
	while _samples.size() > max_samples:
		_samples.pop_front()


## true con la ventana llena y al menos ratio de las muestras dentro del círculo
func is_camping(radius: float, ratio: float, max_samples: int) -> bool:
	if _samples.size() < max_samples:
		return false
	var mean: Vector2 = Vector2.ZERO
	for sample: Vector2 in _samples:
		mean += sample
	mean /= float(_samples.size())
	var inside: int = 0
	for sample: Vector2 in _samples:
		if sample.distance_to(mean) <= radius:
			inside += 1
	return float(inside) / float(_samples.size()) >= ratio


func clear() -> void:
	_samples.clear()
	_timer = 0.0
