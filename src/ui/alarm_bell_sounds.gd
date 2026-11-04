## @file alarm_bell_sounds.gd
## El golpe de campana eléctrica de la cuenta atrás de las rejas (heist.md R7b, #120),
## sintetizado al vuelo: parciales inarmónicos con caída rápida y un soplo de ruido al inicio.
## Sin assets externos, así que no necesita ficha de origen ni licencia. Se calcula una vez.
class_name AlarmBellSounds
extends RefCounted

const RATE: int = 22050
const SECONDS: float = 0.35

static var _bell: AudioStreamWAV = null


## Un golpe de campana (siempre el mismo objeto)
static func bell() -> AudioStreamWAV:
	if _bell == null:
		_bell = _render()
	return _bell


static func _render() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 84
	var count: int = int(SECONDS * RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in range(count):
		var t: float = float(i) / RATE
		var value: float = clampf(_sample(t, rng.randf_range(-1.0, 1.0)), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32000.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


static func _sample(t: float, noise: float) -> float:
	var body: float = (
		sin(TAU * 880.0 * t) * 0.5
		+ sin(TAU * 1333.0 * t) * 0.3
		+ sin(TAU * 2093.0 * t) * 0.2
		+ sin(TAU * 2860.0 * t) * 0.1
	)
	var strike: float = noise * exp(-t * 400.0) * 0.4
	return body * exp(-t * 14.0) * 0.6 + strike
