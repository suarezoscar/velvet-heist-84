## @file exit_zone_3d.gd
## Salida exterior (heist.md R3): con el encargo completo, el ladrón gana al cruzarla.
## La decide el servidor (o la partida sin red). Un cartel de «SALIDA» la señala a todos.
class_name ExitZone3D
extends Area3D

const SIGN_COLOR: Color = Color("4be38a")


static func create(id: String, size: Vector3) -> ExitZone3D:
	var zone: ExitZone3D = ExitZone3D.new()
	zone.name = "Exit_%s" % id
	zone.collision_layer = 0
	zone.collision_mask = 2  # Personajes
	zone.monitoring = true
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	zone.add_child(col)
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
	if GameManager.heist == null or not GameManager.heist.is_complete():
		return
	for body: Node3D in get_overlapping_bodies():
		if body is ThiefController3D:
			print("[ExitZone3D] El ladrón sale por %s con el encargo completo" % name)
			GameManager.end_match(GameManager.MatchState.THIEF_ESCAPED)
			return
