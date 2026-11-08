## @file museum_finishes.gd
## Acabados del kit del museo (#177, fase 2): familia de cada sala (pública, servicio, cámara,
## exterior), color del paño de las públicas, colores de las molduras y de cada suelo.
## Solo aspecto: no cambia nada del juego. Lo usa MuseumFinishBuilder.
class_name MuseumFinishes
extends Resource

const FAMILY_CODES: Dictionary = {&"public": 0, &"service": 1, &"vault": 2, &"exterior": 3}

## Familia por id de sala: &"public", &"service", &"vault" o &"exterior" (sin entrada: public)
@export var families: Dictionary = {}
## Paño de cada sala (en la cámara, tinte de los paneles); sin entrada: default_paint
@export var paints: Dictionary = {}
## Moqueta de cada sala: [fondo, dibujo, acento]; sin entrada: la de floors["carpet"]
@export var carpets: Dictionary = {}
## Suelo por superficie del JSON: [color_a, color_b, color_c, rugosidad]
@export var floors: Dictionary = {}

@export var default_paint: Color = Color("2e3666")
@export var dado: Color = Color("3a2418")
@export var baseboard: Color = Color("1e120c")
@export var rail: Color = Color("b8913d")
@export var cornice: Color = Color("d2c7ad")
@export var service_wall: Color = Color("5a6470")
@export var stripe: Color = Color("ffb627")
@export var vault_wall: Color = Color("6a7280")
@export var exterior_wall: Color = Color("38323f")
@export var cap: Color = Color("0b0e1a")
@export var partition_cap: Color = Color("402616")

@export_group("Calma (#189)")
## Fuerza de los dibujos de las paredes (rayas, paneles, juntas, remaches): 0, color liso
@export_range(0.0, 1.0) var wall_pattern_strength: float = 1.0
## Fuerza del dibujo de los suelos (ajedrezado, espiga, rombos): 0, la media de sus dos tonos
@export_range(0.0, 1.0) var floor_pattern_strength: float = 1.0
## Salas con claraboya: un rectángulo de luz de luna fría en el suelo (solo ambiente: no es
## una Lamp3D y no cuenta para el sigilo)
@export var skylights: Array[String] = []
@export var skylight_color: Color = Color(0.5, 0.62, 1.0)
@export var skylight_energy: float = 4.0


## Código de familia de una sala (0 pública … 3 exterior)
func family_code(room_id: String) -> int:
	return int(FAMILY_CODES.get(StringName(families.get(room_id, &"public")), 0))


func paint_of(room_id: String) -> Color:
	return paints.get(room_id, default_paint)
