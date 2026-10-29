## @file match_report_card_84.gd
## Ficha de un jugador en el informe final (FEAT-041): nombre y bando, lo que hizo y sus puntos
## con el desglose. La del ladrón lista además cada pieza del encargo y cómo se robó. La del
## mejor de la noche lleva un sello. Las monta MatchReport84 con el informe de MatchRecorder.
class_name MatchReportCard84
extends PanelContainer

const BODY_SIZE: int = 19


## Ficha del ladrón
static func thief(data: Dictionary, best: bool) -> MatchReportCard84:
	var card: MatchReportCard84 = _card(
		String(data.get("name", "Ladrón")), "EL LADRÓN", TeamMarker3D.THIEF_COLOR, best
	)
	var box: VBoxContainer = card.get_meta(&"box")
	for piece: Dictionary in data.get("pieces", []):
		var stolen: bool = bool(piece.get("stolen", false))
		var line: String = ("✔ " if stolen else "✘ ") + String(piece.get("name", ""))
		if stolen and not String(piece.get("how", "")).is_empty():
			line += ", " + String(piece["how"])
		box.add_child(_body(line, MenuTheme84.TEXT if stolen else MenuTheme84.DIM))
	var seconds: int = maxi(roundi(float(data.get("time", 0.0))), 0)
	var facts: PackedStringArray = [
		"Alarmas: %d" % int(data.get("alarms", 0)),
		"Monedas: %d" % int(data.get("coins", 0)),
		"Visto: %s" % _times(int(data.get("seen", 0))),
	]
	if bool(data.get("escaped", false)):
		facts.append("Huida a los %d:%02d" % [seconds / 60, seconds % 60])
	box.add_child(_body(" · ".join(facts), MenuTheme84.DIM))
	card.add_score(MatchScore.thief(data))
	return card


## Ficha de un guardia
static func guard(data: Dictionary, number: int, best: bool) -> MatchReportCard84:
	var card: MatchReportCard84 = _card(
		String(data.get("name", "Guardia %d" % number)),
		"GUARDIA %d" % number,
		TeamMarker3D.GUARD_COLOR,
		best
	)
	var box: VBoxContainer = card.get_meta(&"box")
	var facts: PackedStringArray = [
		"Relojes: %d" % int(data.get("clocks", 0)),
		"Faltas: %d" % int(data.get("faults", 0)),
		"Vio al ladrón: %s" % _times(int(data.get("seen", 0))),
	]
	box.add_child(_body(" · ".join(facts), MenuTheme84.TEXT))
	var more: PackedStringArray = [
		"Golpes: %d" % int(data.get("hits", 0)), "Cabezadas: %d" % int(data.get("naps", 0))
	]
	if bool(data.get("capture", false)):
		more.append("¡Lo atrapó!")
	box.add_child(_body(" · ".join(more), MenuTheme84.DIM))
	card.add_score(MatchScore.guard(data))
	return card


## Desglose de puntos y total al pie de la ficha
func add_score(score: Dictionary) -> void:
	var box: VBoxContainer = get_meta(&"box")
	var rule: HSeparator = HSeparator.new()
	box.add_child(rule)
	for line: Dictionary in score.get("lines", []):
		var points: int = int(line["points"])
		box.add_child(
			_body(
				(
					"%s ×%d   %s%d"
					% [line["label"], line["count"], "+" if points >= 0 else "", points]
				),
				MenuTheme84.DIM
			)
		)
	var total: Label = MenuTheme84.label(
		points_text(int(score.get("total", 0))), MenuTheme84.FONT_DISPLAY, 40, MenuTheme84.AMBER
	)
	total.name = "Total"
	box.add_child(total)


static func _card(player: String, side: String, color: Color, best: bool) -> MatchReportCard84:
	var card: MatchReportCard84 = MatchReportCard84.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = MenuTheme84.box(
		Color(MenuTheme84.INK, 0.86), Color(color, 0.55 if not best else 0.95), 2 if not best else 3
	)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	card.set_meta(&"box", box)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	var side_label: Label = MenuTheme84.label(side, MenuTheme84.FONT_STRONG, 20, color)
	side_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(side_label)
	if best:
		var stamp: Label = MenuTheme84.label(
			"MEJOR DE LA NOCHE", MenuTheme84.FONT_DISPLAY, 30, MenuTheme84.NEON_PINK
		)
		stamp.name = "BestStamp"
		stamp.rotation = deg_to_rad(-5.0)
		MenuTheme84.add_glow(stamp, Color(MenuTheme84.NEON_PINK, 0.5), 12)
		header.add_child(stamp)
	box.add_child(MenuTheme84.label(player, MenuTheme84.FONT_DISPLAY, 38, MenuTheme84.TEXT))
	return card


## «1 PUNTO», «-15 PUNTOS»
static func points_text(total: int) -> String:
	return "%d PUNTO" % total if absi(total) == 1 else "%d PUNTOS" % total


static func _body(text: String, color: Color) -> Label:
	var line: Label = MenuTheme84.label(text, MenuTheme84.FONT_BODY, BODY_SIZE, color)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line


static func _times(count: int) -> String:
	if count == 0:
		return "nunca"
	return "1 vez" if count == 1 else "%d veces" % count
