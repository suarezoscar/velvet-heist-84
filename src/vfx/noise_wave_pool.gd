## @file noise_wave_pool.gd
## Reserva fija de miniondas de ruido (#114, regla 04: pooling). Usa la primera libre y, si están
## todas en marcha, reutiliza la más antigua. La crea NoiseAudioPresenter en el jugador local.
class_name NoiseWavePool
extends Node3D

## Ondas a la vez como mucho
const SIZE: int = 12

var waves: Array[NoiseWave3D] = []
var _next: int = 0


func _ready() -> void:
	name = "NoiseWavePool"
	for i: int in SIZE:
		var wave: NoiseWave3D = NoiseWave3D.new()
		wave.name = "NoiseWave%d" % i
		add_child(wave)
		waves.append(wave)


## Lanza una onda; devuelve la que ha usado
func spawn(pos: Vector3, radius: float, duration: float) -> NoiseWave3D:
	var wave: NoiseWave3D = null
	for candidate: NoiseWave3D in waves:
		if not candidate.is_playing():
			wave = candidate
			break
	if wave == null:
		wave = waves[_next]
		_next = (_next + 1) % waves.size()
	wave.play(pos, radius, duration)
	return wave
