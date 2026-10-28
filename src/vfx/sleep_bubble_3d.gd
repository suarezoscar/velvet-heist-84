## @file sleep_bubble_3d.gd
## «Zzz» sobre la cabeza de un guardia que da una cabezada (FEAT-033). Cuelga de VisualRoot,
## como TeamMarker3D: se oculta con el cuerpo y nunca delata a un guardia que no se ve.
## Quien lo enciende es GuardSleep (visible = nodding); aquí solo flota y respira.
class_name SleepBubble3D
extends Label3D

const COLOR: Color = Color("ffd84a")
const HEIGHT: float = 2.6
const BOB: float = 0.08

var base_y: float = 0.0


static func attach(actor: Node3D) -> SleepBubble3D:
	var body: Node3D = actor.get_node_or_null("VisualRoot") as Node3D if actor != null else null
	if body == null:
		return null
	var bubble: SleepBubble3D = SleepBubble3D.new()
	bubble.name = "SleepBubble"
	body.add_child(bubble)
	bubble.transform = body.transform.affine_inverse()
	bubble.position.y += HEIGHT
	bubble.base_y = bubble.position.y
	return bubble


func _init() -> void:
	text = "Zzz"
	visible = false
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	font = MenuTheme84.FONT_STRONG
	font_size = 64
	pixel_size = 0.006
	outline_size = 12
	outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	modulate = COLOR
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if not visible:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	position.y = base_y + sin(t * 3.0) * BOB
	modulate.a = 0.7 + 0.3 * sin(t * 2.0)
