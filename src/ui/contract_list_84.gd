## @file contract_list_84.gd
## Lista del encargo para el ladrón local (heist.md R1): cada pieza con su sala, tachada al
## robarla, bajo el indicador de exposición. A los guardias (FEAT-034), solo un contador: las
## candidatas que siguen en juego y los rastros descubiertos; las fichas están en el plano (M).
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
	visible = heist != null and not NetManager.is_dedicated_server
	if not visible:
		return
	text = compose(heist) if HeistDirector.local_is_thief(get_tree()) else guards_line(heist)


## A los guardias: «CANDIDATAS 17 · RASTROS 3 · plano [M]»
static func guards_line(heist: HeistDirector) -> String:
	var found: int = 0
	var candidates: Array[StringName] = heist.candidates()
	for piece_id: StringName in candidates:
		var piece: TargetPiece3D = heist.piece(piece_id)
		if piece != null and piece.discovered:
			found += 1
	return "CANDIDATAS %d · RASTROS %d · plano [M]" % [candidates.size() - found, found]


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
			return "pieza de pega de una mesa de réplicas"
		&"sensor":
			return "corta la alarma del ala"
	return "combinación"
