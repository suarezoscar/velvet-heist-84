## @file sleep_hud_84.gd
## Lo que ve el guardia local de su sueño (heist.md R5): una taza con su estado bajo la hoja
## de ronda («☕ DESPIERTO», «SOMNOLIENTO», «AGOTADO: ¡CAFÉ!», «SIRVIENDO CAFÉ…», «DESPEJADO»)
## y un fundido a negro durante cada cabezada. Solo se ve jugando con un guardia que tiene sueño.
class_name SleepHud84
extends Control

## Bajo la hoja de ronda, alineado a la derecha
const LABEL_TOP: float = 236.0
const LABEL_WIDTH: float = 460.0
const NOD_ALPHA: float = 0.92
const COLORS: Dictionary = {
	GuardSleep.Stage.AWAKE: Color(0.75, 0.9, 1.0),
	GuardSleep.Stage.DROWSY: Color(1.0, 0.75, 0.3),
	GuardSleep.Stage.EXHAUSTED: Color(1.0, 0.35, 0.25),
}

var map: HeistMap3D = null
var label: Label = null
var blackout: ColorRect = null


func _ready() -> void:
	name = "SleepHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout = ColorRect.new()
	blackout.color = Color(0.0, 0.0, 0.0, 0.0)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blackout)
	label = MenuTheme84.label("", MenuTheme84.FONT_STRONG, 20, MenuTheme84.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -LABEL_WIDTH - 20.0
	label.offset_right = -20.0
	label.offset_top = LABEL_TOP
	add_child(label)


func _process(delta: float) -> void:
	var sleep: GuardSleep = _local_sleep()
	visible = sleep != null
	if sleep == null:
		return
	label.text = status_text(sleep)
	label.modulate = COLORS[sleep.stage()]
	var target: float = NOD_ALPHA if sleep.nodding else 0.0
	blackout.color.a = move_toward(blackout.color.a, target, delta * 4.0)


## Texto de la taza para un sueño (lo usan los tests)
static func status_text(sleep: GuardSleep) -> String:
	if sleep.drinking_left > 0.0:
		return "☕ SIRVIENDO CAFÉ…"
	if sleep.fresh_left > 0.0:
		return "☕ DESPEJADO"
	var percent: int = roundi(sleep.level * 100.0)
	match sleep.stage():
		GuardSleep.Stage.EXHAUSTED:
			return "☕ AGOTADO: ¡CAFÉ EN LA GARITA!"
		GuardSleep.Stage.DROWSY:
			return "☕ SOMNOLIENTO %d %%" % percent
	return "☕ DESPIERTO %d %%" % percent


func _local_sleep() -> GuardSleep:
	if map == null or not (map.local_player is GuardController3D):
		return null
	return map.local_player.get_node_or_null("Sleep") as GuardSleep
