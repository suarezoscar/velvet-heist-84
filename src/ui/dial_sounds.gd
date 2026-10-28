## @file dial_sounds.gd
## Sonidos del dial de la caja fuerte, sintetizados al vuelo (sin assets ni licencias): cada
## marca hace un tic seco; cerca del número, un clic metálico que crece al acercarse; en el
## número exacto, el golpe sordo del pestillo al caer; al probar, un acorde si acierta y un
## traqueteo si los pestillos vuelven a su sitio. Cada sonido se calcula una vez y se reutiliza.
class_name DialSounds
extends RefCounted

const RATE: int = 22050

static var _cache: Dictionary = {}


## Una marca lejos del número
static func tick() -> AudioStreamWAV:
	return _cached(&"tick", 0.014, _tick)


## Cerca del número: distance 1 o 2 (más fuerte y más grave cuanto más cerca)
static func near(distance: int) -> AudioStreamWAV:
	return _cached(&"near1", 0.05, _near1) if distance <= 1 else _cached(&"near2", 0.04, _near2)


## El número exacto: el pestillo cae
static func exact() -> AudioStreamWAV:
	return _cached(&"exact", 0.16, _exact)


## Número acertado al probarlo
static func correct() -> AudioStreamWAV:
	return _cached(&"correct", 0.32, _correct)


## Número fallado: los pestillos se resetean
static func wrong() -> AudioStreamWAV:
	return _cached(&"wrong", 0.28, _wrong)


## Qué sonido toca al llegar a una marca a distance pasos del número (100: sin número)
static func for_distance(distance: int) -> AudioStreamWAV:
	if distance == 0:
		return exact()
	if distance <= SafeBox3D.NEAR_STEPS:
		return near(distance)
	return tick()


static func _cached(key: StringName, seconds: float, shape: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = _render(seconds, shape)
	return _cache[key]


static func _render(seconds: float, shape: Callable) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 84
	var count: int = int(seconds * RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in range(count):
		var t: float = float(i) / RATE
		var value: float = clampf(shape.call(t, rng.randf_range(-1.0, 1.0)), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32000.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


static func _tone(t: float, freq: float) -> float:
	return sin(TAU * freq * t)


static func _tick(t: float, noise: float) -> float:
	return (noise * 0.5 + _tone(t, 4200.0) * 0.5) * exp(-t * 500.0) * 0.22


static func _near2(t: float, noise: float) -> float:
	var ring: float = _tone(t, 2400.0) * 0.6 + _tone(t, 3600.0) * 0.3
	return (ring + noise * 0.3) * exp(-t * 160.0) * 0.45


static func _near1(t: float, noise: float) -> float:
	var ring: float = _tone(t, 1700.0) * 0.6 + _tone(t, 2550.0) * 0.35
	return (ring + noise * 0.3) * exp(-t * 110.0) * 0.7


static func _exact(t: float, noise: float) -> float:
	var thump: float = _tone(t, 140.0) * 0.8 + _tone(t, 280.0) * 0.35
	var snap: float = (noise * 0.6 + _tone(t, 1300.0) * 0.4) * exp(-t * 220.0)
	return thump * exp(-t * 28.0) * 0.6 + snap * 0.35


static func _correct(t: float, _noise: float) -> float:
	var first: float = _tone(t, 880.0) * exp(-t * 14.0)
	var later: float = maxf(0.0, t - 0.1)
	var second: float = _tone(t, 1320.0) * exp(-later * 12.0) if t >= 0.1 else 0.0
	return (first * 0.35 + second * 0.4) * 0.8


static func _wrong(t: float, noise: float) -> float:
	var rattle: float = 0.0
	for start: float in [0.0, 0.05, 0.1]:
		if t >= start:
			rattle += noise * exp(-(t - start) * 160.0)
	var buzz: float = _tone(t, 95.0) * exp(-t * 9.0)
	return rattle * 0.45 + buzz * 0.45
