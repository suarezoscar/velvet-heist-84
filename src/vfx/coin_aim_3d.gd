## @file coin_aim_3d.gd
## Mira de la moneda del ladrón local (FEAT-038): mientras mantiene el botón de lanzar
## (CoinTrigger.aiming) dibuja el arco hasta donde caería (CoinThrow.landing), un aro en el
## punto de caída y, muy tenue y discontinuo, hasta dónde se oirá (RULES.coin_radius). Solo la
## ve quien apunta.
class_name CoinAim3D
extends MeshInstance3D

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const ARC_COLOR: Color = Color("f2b84b")
const RING_COLOR: Color = Color("ff3d9a")
const HEARING_COLOR: Color = Color(1.0, 0.24, 0.6, 0.22)
const ARC_SEGMENTS: int = 24
const RING_RADIUS: float = 0.35
const RING_SEGMENTS: int = 32
const HEARING_DASHES: int = 48
## Separación del suelo de los aros (m), para que no parpadeen contra él
const LIFT: float = 0.04

var _lines: ImmediateMesh = ImmediateMesh.new()
var _material: StandardMaterial3D = StandardMaterial3D.new()


func _ready() -> void:
	name = "CoinAim"
	mesh = _lines
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.render_priority = 10
	visible = false


func _process(_delta: float) -> void:
	var thief: ThiefController3D = _aiming_thief()
	visible = thief != null
	_lines.clear_surfaces()
	if thief == null:
		return
	var from: Vector3 = CoinThrow.origin(thief)
	var landing: Vector3 = CoinThrow.landing(thief, thief.look_target_position)
	_lines.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for index: int in range(ARC_SEGMENTS):
		var t0: float = float(index) / ARC_SEGMENTS
		var t1: float = float(index + 1) / ARC_SEGMENTS
		_segment(
			CoinThrow.arc_point(from, landing, t0),
			CoinThrow.arc_point(from, landing, t1),
			ARC_COLOR
		)
	_circle(landing, RING_RADIUS, RING_SEGMENTS, RING_COLOR, false)
	_circle(landing, RULES.coin_radius, HEARING_DASHES * 2, HEARING_COLOR, true)
	_lines.surface_end()


## El ladrón local mientras apunta con monedas en el bolsillo (null si no)
func _aiming_thief() -> ThiefController3D:
	if not CoinTrigger.aiming or GameManager.heist == null or GameManager.heist.coins_left <= 0:
		return null
	if GameManager.current_state != GameManager.MatchState.IN_PROGRESS:
		return null
	var thief: ThiefController3D = get_tree().get_first_node_in_group(&"thief") as ThiefController3D
	if thief == null or not thief.is_locally_controlled or thief.in_vent:
		return null
	return thief


func _circle(center: Vector3, radius: float, segments: int, color: Color, dashed: bool) -> void:
	for index: int in range(segments):
		if dashed and index % 2 == 1:
			continue
		var a0: float = TAU * index / segments
		var a1: float = TAU * (index + 1) / segments
		var p0: Vector3 = center + Vector3(cos(a0) * radius, LIFT, sin(a0) * radius)
		var p1: Vector3 = center + Vector3(cos(a1) * radius, LIFT, sin(a1) * radius)
		_segment(p0, p1, color)


func _segment(a: Vector3, b: Vector3, color: Color) -> void:
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(a)
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(b)
