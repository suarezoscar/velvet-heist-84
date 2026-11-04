## @file exit_zone_3d.gd
## Salida exterior (heist.md R3): con el encargo completo, el ladrón gana al cruzarla; con la
## cuenta atrás de las rejas en marcha y al menos una pieza, es una huida a medias (#120,
## HeistLockdown.escape_state). Un cartel de «SALIDA» la señala a todos. El callejón es otra
## zona (outdoor, sin cartel): con la alarma, estar fuera ya es huir.
## La decide el servidor (o la partida sin red).
class_name ExitZone3D
extends Area3D

const SIGN_COLOR: Color = Color("4be38a")

## El callejón (sala exterior), no una puerta: no tiene cartel ni reja
var outdoor: bool = false


static func create(id: String, size: Vector3, is_outdoor: bool = false) -> ExitZone3D:
	var zone: ExitZone3D = ExitZone3D.new()
	zone.outdoor = is_outdoor
	zone.add_to_group(&"heist_exits")
	zone.name = "Exit_%s" % id
	zone.collision_layer = 0
	zone.collision_mask = 2  # Personajes
	zone.monitoring = true
	# Antes que GameManager y las rejas: quien cruza en el último tick escapa (heist.md R4, R7b)
	zone.process_physics_priority = -2
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	zone.add_child(col)
	if is_outdoor:
		return zone
	var sign_label: Label3D = Label3D.new()
	sign_label.name = "Sign"
	sign_label.text = "SALIDA"
	sign_label.modulate = SIGN_COLOR
	sign_label.font_size = 48
	sign_label.pixel_size = 0.006
	sign_label.outline_size = 8
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.position = Vector3(0.0, 2.9, 0.0)
	zone.add_child(sign_label)
	return zone


func _physics_process(_delta: float) -> void:
	if (
		not GameManager.is_simulating()
		or GameManager.current_state != GameManager.MatchState.IN_PROGRESS
	):
		return
	var ending: int = HeistLockdown.escape_state(GameManager.heist, HeistLockdown.of(get_tree()))
	if ending < 0:
		return
	for body: Node3D in get_overlapping_bodies():
		if body is ThiefController3D:
			print("[ExitZone3D] El ladrón sale por %s" % name)
			GameManager.end_match(ending as GameManager.MatchState)
			return
