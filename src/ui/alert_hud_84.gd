## @file alert_hud_84.gd
## Lo que se ve del golpe en partida (heist.md R6-R8): el nivel de alerta bajo la barra
## superior (para los dos bandos); las monedas del ladrón; y, para los guardias, el estado de
## las luces de alarma y las marcas del walkie del equipo sobre el mapa.
class_name AlertHud84
extends Control

const LEVEL_TEXT: Array[String] = ["ALERTA: CALMA", "ALERTA: SOSPECHA", "ALERTA: ¡ALARMA!"]
const LEVEL_COLOR: Array[Color] = [Color("8a8f9c"), Color("f2b84b"), Color("ff4a3d")]
const PING_COLOR: Color = Color("3de0e0")

var map: HeistMap3D = null
var level_label: Label = null
var tools_label: Label = null
var _ping_markers: Array[Label3D] = []


func _ready() -> void:
	name = "AlertHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label = _label(56.0, 24)
	tools_label = _label(88.0, 18)


func _process(_delta: float) -> void:
	var alert: AlertDirector = AlertDirector.of(get_tree()) if is_inside_tree() else null
	visible = alert != null and map != null and map.local_player != null
	var none: Array[Dictionary] = []
	if not visible:
		_show_pings(none)
		return
	level_label.text = LEVEL_TEXT[alert.level]
	level_label.modulate = LEVEL_COLOR[alert.level]
	var is_thief: bool = map.local_player == map.thief
	tools_label.text = tools_text(is_thief, alert, GameManager.heist)
	_show_pings(none if is_thief else alert.pings)


## Línea de herramientas del bando local (la usan los tests)
static func tools_text(is_thief: bool, alert: AlertDirector, heist: HeistDirector) -> String:
	var lights: String = ControlsCatalog.keys(&"alarm_lights")
	var walkie: String = ControlsCatalog.keys(&"walkie")
	if is_thief:
		var coins: int = heist.coins_left if heist != null else 0
		var fake: bool = heist != null and heist.carrying_fake
		return (
			"MONEDAS: %d  [%s]%s"
			% [coins, ControlsCatalog.keys(&"throw_coin"), "   ·   PIEZA DE PEGA ✔" if fake else ""]
		)
	var line: String = "WALKIE [%s]" % walkie
	if alert.level == AlertDirector.Level.ALARM:
		if alert.flood_cooldown_left > 0.0:
			line += "   ·   LUCES DE ALARMA EN %d s" % ceili(alert.flood_cooldown_left)
		else:
			line += "   ·   LUCES DE ALARMA [%s]" % lights
	return line


func _show_pings(pings: Array[Dictionary]) -> void:
	while _ping_markers.size() < pings.size() and map != null:
		var marker: Label3D = Label3D.new()
		marker.text = "◉ WALKIE"
		marker.modulate = PING_COLOR
		marker.font_size = 40
		marker.pixel_size = 0.006
		marker.outline_size = 10
		marker.no_depth_test = true
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		map.add_child(marker)
		_ping_markers.append(marker)
	for index: int in range(_ping_markers.size()):
		var marker: Label3D = _ping_markers[index]
		marker.visible = index < pings.size()
		if marker.visible:
			marker.global_position = (pings[index]["pos"] as Vector3) + Vector3.UP * 1.5


func _label(top: float, font_size: int) -> Label:
	var label: Label = MenuTheme84.label("", MenuTheme84.FONT_STRONG, font_size, MenuTheme84.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = top
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label
