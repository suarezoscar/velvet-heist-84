## @file coin_flight_3d.gd
## La moneda del ladrón en el aire (FEAT-038): vuela en arco girando, cae con un destello y
## brilla en el suelo RULES.coin_glint_time segundos antes de desaparecer. Solo es lo que se
## ve: el ruido lo emite quien tiene la autoridad (HeistActions.throw_coin).
class_name CoinFlight3D
extends Node3D

const RULES: HeistRules = preload("res://data/balance/heist_rules.tres")
const COLOR: Color = Color("f2b84b")
const RADIUS: float = 0.12  # exagerada para que se lea con la cámara cenital
const SPIN_SPEED: float = 18.0

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _flight: float = 0.5
var _time: float = 0.0
var _landed: bool = false
var _coin: MeshInstance3D = null
var _light: OmniLight3D = null


## Crea la moneda en parent y la lanza de from a landing en flight_time segundos
static func launch(
	parent: Node, from: Vector3, landing: Vector3, flight_time: float
) -> CoinFlight3D:
	var flight: CoinFlight3D = CoinFlight3D.new()
	flight._from = from
	flight._to = landing
	flight._flight = maxf(flight_time, 0.05)
	parent.add_child(flight)
	return flight


func _ready() -> void:
	name = "CoinFlight"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = 0.015
	mesh.radial_segments = 16
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.metallic = 0.9
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = COLOR
	material.emission_energy_multiplier = 1.2
	mesh.material = material
	_coin = MeshInstance3D.new()
	_coin.mesh = mesh
	_coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coin)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 1.2
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	global_position = _from


func _process(delta: float) -> void:
	_time += delta
	if not _landed:
		var t: float = minf(_time / _flight, 1.0)
		global_position = CoinThrow.arc_point(_from, _to, t) + Vector3(0.0, RADIUS, 0.0)
		_coin.rotate_x(SPIN_SPEED * delta)
		if t >= 1.0:
			_land()
		return
	var glint: float = _time - _flight
	# Destello al caer y un brillo que se apaga poco a poco
	_light.light_energy = 3.0 * exp(-6.0 * glint) + 0.4 * (1.0 - glint / RULES.coin_glint_time)
	if glint >= RULES.coin_glint_time:
		queue_free()


func _land() -> void:
	_landed = true
	_coin.rotation = Vector3.ZERO
	global_position = _to + Vector3(0.0, 0.01, 0.0)
	_light.position = Vector3(0.0, 0.3, 0.0)
