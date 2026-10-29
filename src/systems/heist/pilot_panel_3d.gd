## @file pilot_panel_3d.gd
## Panel de pilotos de la garita (heist.md R9): una línea por ala, verde con corriente y roja
## «SIN CORRIENTE» con la alarma cortada. Lo ven todos, pero está en la garita: un guardia que
## se acerca (RULES.pilot_sight) se entera del corte (AlertDirector).
class_name PilotPanel3D
extends Node3D

const OK_COLOR: Color = Color("4be38a")
const CUT_COLOR: Color = Color("ff4a3d")

var label: Label3D = null


func _ready() -> void:
	name = "PilotPanel"
	add_to_group(&"pilot_panel")
	label = Label3D.new()
	label.font_size = 28
	label.pixel_size = 0.006
	label.outline_size = 8
	label.position = Vector3(0.0, 1.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _process(_delta: float) -> void:
	var lines: Array[String] = []
	var any_cut: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"power_boxes"):
		var box: PowerBox3D = node as PowerBox3D
		lines.append("● %s: %s" % [box.wing_name, "SIN CORRIENTE" if box.is_cut else "EN SERVICIO"])
		any_cut = any_cut or box.is_cut
	label.text = "\n".join(PackedStringArray(lines))
	label.modulate = CUT_COLOR if any_cut else OK_COLOR
