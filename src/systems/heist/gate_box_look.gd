## @file gate_box_look.gd
## Aspecto de la caja de la reja (heist.md R7c): caja de chapa gris con placa «REJA». Con la
## tapa fuera (a medias) se ven los cables; saboteada, la tapa queda torcida. Cada chispa nueva
## pinta un destello corto. Solo lee la caja.
class_name GateBoxLook
extends RefCounted

const CASE_COLOR: Color = Color("6b6f76")
const COVER_COLOR: Color = Color("8a8f97")
const WIRES_COLOR: Color = Color("c0392b")
const SPARK_COLOR: Color = Color(1.0, 0.85, 0.4)
const FLASH_TIME: float = 0.15


static func build(box: GateBox3D) -> void:
	var case_mesh: MeshInstance3D = _box("Case", GateBox3D.SIZE, CASE_COLOR)
	case_mesh.position = Vector3(0.0, GateBox3D.HEIGHT, 0.0)
	box.add_child(case_mesh)
	var wires: MeshInstance3D = _box("Wires", GateBox3D.SIZE * Vector3(0.7, 0.6, 1.05), WIRES_COLOR)
	wires.position = Vector3(0.0, GateBox3D.HEIGHT, 0.0)
	box.add_child(wires)
	var cover: MeshInstance3D = _box("Cover", Vector3(0.52, 0.62, 0.03), COVER_COLOR)
	cover.position = Vector3(0.0, GateBox3D.HEIGHT, GateBox3D.SIZE.z * 0.5 + 0.015)
	box.add_child(cover)
	var plate: Label3D = Label3D.new()
	plate.name = "Plate"
	plate.text = "REJA"
	plate.font_size = 24
	plate.pixel_size = 0.004
	plate.position = Vector3(0.0, GateBox3D.HEIGHT + 0.2, GateBox3D.SIZE.z * 0.5 + 0.035)
	box.add_child(plate)
	var spark: OmniLight3D = OmniLight3D.new()
	spark.name = "Spark"
	spark.light_color = SPARK_COLOR
	spark.light_energy = 0.0
	spark.omni_range = 2.5
	spark.position = Vector3(0.0, GateBox3D.HEIGHT, 0.3)
	box.add_child(spark)
	box.set_meta(&"look_sparks", 0)
	box.set_meta(&"look_flash", 0.0)


static func update(box: GateBox3D) -> void:
	var cover: Node3D = box.get_node_or_null("Cover") as Node3D
	var wires: Node3D = box.get_node_or_null("Wires") as Node3D
	if cover == null or wires == null:
		return
	var open: bool = box.step == GateBox3D.Step.CUT  # con la tapa fuera se ven los cables
	cover.visible = not open
	wires.visible = open
	cover.rotation_degrees.z = 9.0 if box.is_tampered() else 0.0  # la tapa mal cerrada
	var spark: OmniLight3D = box.get_node_or_null("Spark") as OmniLight3D
	var flash: float = float(box.get_meta(&"look_flash", 0.0))
	if box.sparks != int(box.get_meta(&"look_sparks", 0)):
		box.set_meta(&"look_sparks", box.sparks)
		flash = FLASH_TIME
	flash = maxf(0.0, flash - box.get_process_delta_time())
	box.set_meta(&"look_flash", flash)
	if spark != null:
		spark.light_energy = 4.0 if flash > 0.0 else 0.0


static func _box(node_name: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = node_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.5
	material.roughness = 0.5
	box_mesh.material = material
	mesh.mesh = box_mesh
	return mesh
