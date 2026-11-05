## @file blueprint_map_legend.gd
## Leyenda del plano (#117): un recuadro de terminal arriba a la derecha, con los iconos en
## cuatro capas que se encienden y apagan con [1]-[4] (BlueprintMapOverlay). Distinta por bando;
## usa los mismos iconos que el plano (BlueprintMapIcons y BlueprintMapProps).
class_name BlueprintMapLegend
extends RefCounted

const ICONS := preload("res://src/ui/blueprint_map_icons.gd")
const PROPS := preload("res://src/ui/blueprint_map_props.gd")
const WIDTH: float = 260.0
const ROW: float = 26.0
const GROUP_GAP: float = 34.0
## Capas, en el orden de sus teclas [1]-[4]
const LAYERS: Array[StringName] = [&"people", &"security", &"power", &"places"]

## Por bando: capa → [título, [[icono, texto], ...]]
const THIEF_GROUPS: Dictionary = {
	&"people": ["TÚ Y ENCARGO", [[&"you", "TÚ"], [&"contract", "TU ENCARGO (✔ ROBADA)"]]],
	&"security":
	[
		"SEGURIDAD Y EVENTOS",
		[[&"camera", "CÁMARA"], [&"gate_box", "CAJA DE LA REJA"], [&"alarm", "ALARMA (HACE…)"]]
	],
	&"power": ["RED ELÉCTRICA", [[&"switch", "INTERRUPTOR"], [&"lamp", "LÁMPARA"]]],
	&"places":
	[
		"INSTALACIONES",
		[
			[&"exit", "SALIDA"],
			[&"car", "COCHE DE HUIDA"],
			[&"vent", "REJILLA (S / O / E)"],
			[&"post", "GARITA"],
			[&"coffee", "CAFETERA"],
			[&"desk", "MONITORES"]
		]
	],
}
const GUARD_GROUPS: Dictionary = {
	&"people": ["PERSONAL Y COMMS", [[&"you", "TÚ"], [&"mate", "COMPAÑERO"], [&"ping", "WALKIE"]]],
	&"security":
	[
		"SEGURIDAD Y EVENTOS",
		[
			[&"camera", "CÁMARA"],
			[&"gate_box", "CAJA DE LA REJA"],
			[&"sensor", "SENSOR"],
			[&"pressure", "PRESIÓN"],
			[&"combination", "COMBINACIÓN"],
			[&"alarm", "ALARMA (HACE…)"],
			[&"trace", "RASTRO (FALTA)"]
		]
	],
	&"power": ["RED ELÉCTRICA", [[&"switch", "INTERRUPTOR"], [&"lamp", "LÁMPARA"]]],
	&"places":
	[
		"INSTALACIONES",
		[[&"post", "GARITA"], [&"coffee", "CAFETERA"], [&"desk", "MONITORES"], [&"exit", "SALIDA"]]
	],
}


## Recuadro de la leyenda arriba a la derecha de panel; layers: {capa: bool} encendidas
static func draw(
	on: CanvasItem, panel: Rect2, top: float, thief_view: bool, layers: Dictionary
) -> void:
	var groups: Dictionary = THIEF_GROUPS if thief_view else GUARD_GROUPS
	var height: float = 58.0
	for layer: StringName in LAYERS:
		height += GROUP_GAP + (groups[layer][1].size() * ROW if layers.get(layer, true) else 0.0)
	var box: Rect2 = Rect2(Vector2(panel.end.x - WIDTH - 20.0, top), Vector2(WIDTH, height))
	ICONS.terminal_frame(on, box)
	ICONS.text(on, box.position + Vector2(14.0, 30.0), "LEYENDA", 22, ICONS.COLOR_HEADER)
	var y: float = box.position.y + 48.0
	for i: int in range(LAYERS.size()):
		var layer: StringName = LAYERS[i]
		var on_layer: bool = layers.get(layer, true)
		var color: Color = ICONS.COLOR_HEADER if on_layer else ICONS.COLOR_OFF
		var title: String = "[%d] %s" % [i + 1, groups[layer][0]]
		ICONS.mono(on, Vector2(box.position.x + 14.0, y + 20.0), title, 15, color)
		y += GROUP_GAP
		if not on_layer:
			continue
		for row: Array in groups[layer][1]:
			var middle: float = y + ROW * 0.5  # icono y texto centrados en la fila
			_icon(on, row[0], Vector2(box.position.x + 30.0, middle), thief_view)
			ICONS.text(
				on,
				Vector2(box.position.x + 56.0, middle + 6.0),
				String(row[1]),
				17,
				ICONS.COLOR_TEXT
			)
			y += ROW


static func _icon(on: CanvasItem, kind: StringName, at: Vector2, thief_view: bool) -> void:
	var own: Color = TeamMarker3D.THIEF_COLOR if thief_view else TeamMarker3D.GUARD_COLOR
	match kind:
		&"you":
			ICONS.you(on, at + Vector2(0.0, 3.0), Vector2.UP, 1.0, false)
		&"mate":
			ICONS.badge(on, at, TeamMarker3D.GUARD_COLOR, &"police_officer_head")
		&"contract":
			ICONS.sticker(on, at, &"cut_diamond", 20.0, TeamMarker3D.THIEF_COLOR)
		&"combination", &"pressure", &"sensor":
			ICONS.sticker(on, at, ICONS.PROTECTION_SPRITES[kind], 20.0, own)
		&"trace":
			ICONS.sticker(on, at, &"cross_mark", 20.0, ICONS.COLOR_ALARM)
		&"vent":
			ICONS.vent(on, at, "")
		&"camera":
			ICONS.camera(on, at)
		&"exit":
			ICONS.exit_door(on, at)
		&"post":
			var square: Rect2 = Rect2(at - Vector2(11.0, 8.0), Vector2(22.0, 16.0))
			on.draw_rect(square, Color(ICONS.COLOR_POST, 0.35))
			on.draw_rect(square, ICONS.COLOR_POST, false, 2.0)
		&"ping":
			ICONS.ping(on, at)
		&"alarm":
			ICONS.alarm(on, at, -1.0)
		&"lamp":
			ICONS.sticker(on, at, &"light_bulb", 18.0, Color(ICONS.COLOR_POWER, 0.8))
		_:
			PROPS.icon(on, kind, at)
