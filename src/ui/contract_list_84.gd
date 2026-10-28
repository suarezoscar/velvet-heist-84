## @file contract_list_84.gd
## Lista del encargo para el ladrón local (heist.md R1): cada pieza con su sala, tachada al
## robarla, bajo el indicador de exposición. Solo se ve jugando con el ladrón y con encargo.
class_name ContractList84
extends Label

const POSITION: Vector2 = Vector2(20.0, 124.0)


func _ready() -> void:
	name = "ContractList"
	position = POSITION
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", MenuTheme84.FONT_BODY)
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", MenuTheme84.TEXT)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	add_theme_constant_override("outline_size", 6)


func _process(_delta: float) -> void:
	var heist: HeistDirector = GameManager.heist
	visible = heist != null and HeistDirector.local_is_thief(get_tree())
	if visible:
		text = compose(heist)


## «ENCARGO» y una línea por pieza: «✔ Busto de bronce» o «◆ Retrato del Duque · Galería…»
static func compose(heist: HeistDirector) -> String:
	var lines: Array[String] = ["ENCARGO"]
	for piece_id: StringName in heist.targets:
		var piece: TargetPiece3D = heist.piece(piece_id)
		if piece == null:
			continue
		if heist.stolen.has(piece_id):
			lines.append("✔ %s" % piece.piece_name)
		else:
			lines.append("◆ %s · %s · %s" % [piece.piece_name, piece.room_name, hint(piece)])
	if heist.carrying_fake:
		lines.append("Llevas una pieza de pega")
	if heist.is_complete():
		lines.append("¡A cualquier salida!")
	return "\n".join(PackedStringArray(lines))


## Cómo se roba en silencio cada protección
static func hint(piece: TargetPiece3D) -> String:
	match piece.protection:
		&"pressure":
			return "pieza de pega del taller"
		&"sensor":
			return "corta la alarma del ala"
	return "combinación"
