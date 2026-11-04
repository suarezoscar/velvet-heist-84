## @file blueprint_map_pieces.gd
## Piezas en el plano (#117): el ladrón ve su encargo (diamante, ✔ si ya está robada, con
## nombre); los guardias, las candidatas con el icono de su protección (verde si la revisaron,
## aspa roja si saben que falta). Lo dibuja BlueprintMapOverlay con la capa que toque.
class_name BlueprintMapPieces
extends RefCounted

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")


## El encargo del ladrón (capa de personas) o las candidatas de los guardias (seguridad)
static func draw(on: CanvasItem, thief_view: bool, at: Callable) -> void:
	var heist: HeistDirector = GameManager.heist
	for node: Node in on.get_tree().get_nodes_in_group(&"heist_targets"):
		var piece: TargetPiece3D = node as TargetPiece3D
		var pos: Vector2 = at.call(piece.global_position)
		if thief_view:
			if heist == null or not heist.is_in_contract(piece.piece_id):
				continue
			var pink: Color = TeamMarker3D.THIEF_COLOR
			ICONS.glow(on, pos, pink, 20.0, 0.5)
			ICONS.piece(on, pos, &"cut_diamond", pink)
			if heist.stolen.has(piece.piece_id):
				ICONS.glyph(on, pos + Vector2(9.0, -9.0), "✔", 18, ICONS.COLOR_OK)
			ICONS.text(on, pos + Vector2(15.0, 7.0), piece.piece_name, 17, pink)
			continue
		var icon: StringName = ICONS.PROTECTION_SPRITES.get(piece.protection, &"cut_diamond")
		var color: Color = TeamMarker3D.GUARD_COLOR
		if piece.discovered:
			icon = &"cross_mark"
			color = ICONS.COLOR_ALARM
		elif piece.inspected:
			color = ICONS.COLOR_OK
		ICONS.piece(on, pos, icon, color)
