## Datos de un nivel leídos de data/levels/*.json (FEAT-015).
## Coordenadas del diseño: x hacia el este, z hacia el sur, en metros; Godot = (x + ox, y, z + oz).
class_name LevelData
extends RefCounted

## Superficie sin .tres propio (exterior)
const DEFAULT_NOISE_MULTIPLIER: float = 1.0

var raw: Dictionary = {}
var offset: Vector2 = Vector2.ZERO
var wall_height: float = 3.2
var wall_thickness: float = 0.3
var wall_low_height: float = 1.2


## Lee y valida lo mínimo de un JSON de nivel; null si no se puede leer
static func load_json(path: String) -> LevelData:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[LevelData] No se puede leer %s" % path)
		return null
	var data: LevelData = LevelData.new()
	data.raw = parsed
	var off: Array = data.raw.get("offset", [0, 0])
	data.offset = Vector2(float(off[0]), float(off[1]))
	var wall: Dictionary = data.raw.get("wall", {})
	data.wall_height = float(wall.get("height", 3.2))
	data.wall_thickness = float(wall.get("thickness", 0.3))
	data.wall_low_height = float(wall.get("low_height", 1.2))
	return data


## Lista de una sección del JSON (vacía si no existe)
func section(key: String) -> Array:
	var value: Variant = raw.get(key, [])
	return value if value is Array else []


## Diccionario de una sección del JSON (vacío si no existe)
func entry(key: String) -> Dictionary:
	var value: Variant = raw.get(key, {})
	return value if value is Dictionary else {}


## Punto [x, z] del diseño a posición de Godot a la altura y
func to_world(point: Array, y: float = 0.0) -> Vector3:
	return Vector3(float(point[0]) + offset.x, y, float(point[1]) + offset.y)


## Rectángulo [x, z, ancho, fondo] de una sala
func room_rect(room: Dictionary) -> Rect2:
	var r: Array = room["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## Sala por id (diccionario vacío si no existe)
func room_by_id(room_id: String) -> Dictionary:
	for room: Dictionary in section("rooms"):
		if String(room.get("id", "")) == room_id:
			return room
	return {}


## Límites del edificio: unión de las salas que no son exteriores
func building_bounds() -> Rect2:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for room: Dictionary in section("rooms"):
		if bool(room.get("exterior", false)):
			continue
		var rect: Rect2 = room_rect(room)
		bounds = rect if first else bounds.merge(rect)
		first = false
	return bounds


## Multiplicador de ruido de una superficie, leído de data/balance/surface_<id>.tres
static func noise_multiplier_for(surface: String) -> float:
	var path: String = "res://data/balance/surface_%s.tres" % surface
	if not ResourceLoader.exists(path):
		return DEFAULT_NOISE_MULTIPLIER
	var res: SurfaceAcousticData = load(path) as SurfaceAcousticData
	return res.noise_multiplier if res != null else DEFAULT_NOISE_MULTIPLIER
