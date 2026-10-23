## @file hud_84.gd
## Capa de interfaz gráfica (HUD) con estética retro años 80 / casete analógico.
## Muestra el progreso de la cuota económica, estado de la obra de arte,
## reloj de ronda, tooltips dinámicos contextuales, paneles de fin de partida,
## indicador de exposición del ladrón y marcadores de ruido fuera de pantalla.
class_name HUD84
extends CanvasLayer

const STYLE_PATH: String = "res://assets/ui/noise_ring_style.tres"

## Referencia al personaje local para leer el objetivo que enfoca actualmente
var target_player: Node3D = null

## Estado actual de exposición del ladrón
var exposure_state: StringName = &""
var exposure_icon: Label = null
var exposure_label: Label = null

var _exposure_state: StringName = &""
var _exposure_blink_timer: float = 0.0

@onready var loot_label: Label = get_node_or_null("TopBar/HBox/LootLabel")
@onready var masterpiece_label: Label = get_node_or_null("TopBar/HBox/MasterpieceLabel")
@onready var timer_label: Label = get_node_or_null("TopBar/HBox/TimerLabel")
@onready var exposure_panel: PanelContainer = get_node_or_null("ExposurePanel")
@onready var prompt_panel: PanelContainer = get_node_or_null("PromptPanel")
@onready var prompt_label: Label = get_node_or_null("PromptPanel/PromptLabel")
@onready var game_over_panel: PanelContainer = get_node_or_null("GameOverPanel")
@onready var game_over_title: Label = get_node_or_null("GameOverPanel/VBox/TitleLabel")
@onready var game_over_sub: Label = get_node_or_null("GameOverPanel/VBox/SubLabel")
@onready var blueprint_overlay: Control = get_node_or_null("BlueprintMapOverlay")


func _ready() -> void:
	if game_over_panel != null:
		game_over_panel.visible = false
	if prompt_panel != null:
		prompt_panel.visible = false
	if exposure_panel != null:
		exposure_panel.visible = false

	if exposure_icon == null:
		exposure_icon = get_node_or_null("ExposurePanel/HBox/ExposureIcon") as Label
		if exposure_icon == null:
			exposure_icon = get_node_or_null("ExposureIcon") as Label
	if exposure_label == null:
		exposure_label = get_node_or_null("ExposurePanel/HBox/ExposureLabel") as Label
		if exposure_label == null:
			exposure_label = get_node_or_null("ExposureLabel") as Label


func _process(delta: float) -> void:
	_update_header_stats()
	_update_interaction_tooltip()
	_update_exposure_blink(delta)


## Actualiza el estado de exposición del ladrón en el HUD (&"shadow", &"lit", &"beam", &"")
func set_exposure(state: StringName) -> void:
	_exposure_state = state
	exposure_state = state
	if state == &"":
		if exposure_panel != null:
			exposure_panel.visible = false
		return

	if exposure_panel != null:
		exposure_panel.visible = true

	var text: String = ""
	var icon: String = ""
	var color: Color = Color.WHITE

	match state:
		&"shadow", &"sombra":
			text = "SOMBRA"
			icon = "◐"
			color = Color(0.5, 0.5, 0.5, 1.0)
		&"lit", &"iluminado":
			text = "ILUMINADO"
			icon = "☀"
			color = Color("f2b84b")
		&"beam", &"en_el_haz":
			text = "EN EL HAZ"
			icon = "▲"
			color = Color("ff6b5a")
		_:
			text = str(state).to_upper()
			icon = "[!]"
			color = Color(0.5, 0.5, 0.5, 1.0)

	if exposure_icon != null:
		exposure_icon.text = icon
		exposure_icon.modulate = color
	if exposure_label != null:
		exposure_label.text = text
		exposure_label.modulate = color


## Devuelve el estado actual de exposición
func get_exposure() -> StringName:
	return _exposure_state


func _update_exposure_blink(delta: float) -> void:
	var is_beam: bool = _exposure_state == &"beam" or _exposure_state == &"en_el_haz"
	if is_beam:
		_exposure_blink_timer += delta
		var is_visible_blink: bool = fmod(_exposure_blink_timer, 0.5) < 0.25
		var alpha_blink: float = 1.0 if is_visible_blink else 0.2
		if exposure_icon != null:
			exposure_icon.modulate.a = alpha_blink
		if exposure_label != null:
			exposure_label.modulate.a = alpha_blink
	else:
		_exposure_blink_timer = 0.0
		if exposure_icon != null and exposure_icon.modulate.a < 1.0:
			exposure_icon.modulate.a = 1.0
		if exposure_label != null and exposure_label.modulate.a < 1.0:
			exposure_label.modulate.a = 1.0


## Muestra un chevron de 16 px en el borde de la pantalla en la dirección del ruido
func show_offscreen_noise(world_pos: Vector3, lifetime: float, role: StringName) -> void:
	var chevron: OffscreenChevron = OffscreenChevron.new()
	chevron.world_pos = world_pos
	chevron.lifetime = lifetime
	chevron.time_left = lifetime
	var style: NoiseRingStyle = load(STYLE_PATH) as NoiseRingStyle
	if style != null:
		chevron.chevron_color = style.get_color_for_role(role)
	else:
		chevron.chevron_color = Color("b8e6c1")
	add_child(chevron)


## Devuelve los marcadores de ruido fuera de pantalla activos
func get_active_offscreen_markers() -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in get_children():
		if child is OffscreenChevron:
			result.append(child)
	return result


## Actualiza los textos de la barra superior leyendo reactivamente el GameManager
func _update_header_stats() -> void:
	if not is_instance_valid(GameManager):
		return

	if loot_label != null:
		var cur: int = GameManager.current_loot_value
		var target: int = GameManager.quota_target
		loot_label.text = "BOTIN: $%d / $%d" % [cur, target]
		loot_label.modulate = Color(0.3, 1.0, 0.4) if cur >= target else Color(1.0, 0.85, 0.3)

	if masterpiece_label != null:
		var has_art: bool = GameManager.has_masterpiece
		if has_art:
			masterpiece_label.text = "[★] PIEZA MAESTRA: ASEGURADA"
			masterpiece_label.modulate = Color(1.0, 0.84, 0.0)
		else:
			masterpiece_label.text = "[ ] PIEZA MAESTRA: PENDIENTE"
			masterpiece_label.modulate = Color(0.6, 0.6, 0.6)

	if timer_label != null:
		var sec: float = GameManager.match_timer
		var mins: int = int(sec) / 60
		var secs: int = int(sec) % 60
		timer_label.text = "TIEMPO: %02d:%02d" % [mins, secs]
		if sec <= 60.0:
			timer_label.modulate = Color(1.0, 0.25, 0.25)
		else:
			timer_label.modulate = Color(0.9, 0.9, 0.9)

	_check_game_over_state()


func _check_game_over_state() -> void:
	match int(GameManager.current_state):
		2:  # MatchState.THIEF_ESCAPED
			_show_game_over_modal(
				"¡EL LADRÓN HA ESCAPADO!",
				"El botin de 1984 esta a salvo. ¡Golpe maestro completado!",
				Color(0.25, 1.0, 0.4),
			)
		3:  # MatchState.THIEF_CAPTURED
			_show_game_over_modal(
				"¡EL LADRÓN HA SIDO CAPTURADO!",
				"La seguridad privada neutralizo la infiltracion.",
				Color(1.0, 0.25, 0.25),
			)
		4:  # MatchState.TIME_EXPIRED
			_show_game_over_modal(
				"¡TIEMPO AGOTADO!",
				"Llego el furgon policial y aseguro el perimetro.",
				Color(1.0, 0.55, 0.1),
			)


## Actualiza el texto de interacción inferior cuando el interactor detecta un objeto
func _update_interaction_tooltip() -> void:
	if prompt_panel == null or prompt_label == null:
		return

	if target_player != null and "focused_interactive" in target_player:
		var obj: Object = target_player.get("focused_interactive")
		if obj != null and obj.has_method("get_interaction_text"):
			prompt_label.text = str(obj.call("get_interaction_text", target_player))
			prompt_panel.visible = true
			return

	prompt_panel.visible = false


func _show_game_over_modal(title: String, subtitle: String, title_color: Color) -> void:
	if game_over_panel != null:
		game_over_panel.visible = true
	if game_over_title != null:
		game_over_title.text = title
		game_over_title.modulate = title_color
	if game_over_sub != null:
		game_over_sub.text = subtitle


## Chevron indicador en el borde de la pantalla para ruidos fuera de campo
class OffscreenChevron:
	extends Control
	var world_pos: Vector3 = Vector3.ZERO
	var lifetime: float = 1.0
	var time_left: float = 1.0
	var chevron_color: Color = Color.WHITE

	func _ready() -> void:
		custom_minimum_size = Vector2(16.0, 16.0)
		size = Vector2(16.0, 16.0)
		pivot_offset = Vector2(8.0, 8.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			queue_free()
			return

		var fade_threshold: float = lifetime * 0.4
		if time_left < fade_threshold and fade_threshold > 0.0:
			modulate.a = time_left / fade_threshold
		else:
			modulate.a = 1.0

		_update_edge_transform()
		queue_redraw()

	func _update_edge_transform() -> void:
		var vp: Viewport = get_viewport()
		var sz: Vector2 = Vector2(1920.0, 1080.0)
		if vp != null:
			sz = vp.get_visible_rect().size
		if sz.x <= 0.0 or sz.y <= 0.0:
			sz = Vector2(1920.0, 1080.0)
		var center: Vector2 = sz * 0.5
		var dir: Vector2 = Vector2.UP

		var cam: Camera3D = null
		if vp != null:
			cam = vp.get_camera_3d()
		if cam != null:
			var to_pos: Vector2 = cam.unproject_position(world_pos) - center
			if cam.is_position_behind(world_pos):
				to_pos = -to_pos
			if to_pos.length_squared() > 0.001:
				dir = to_pos.normalized()

		var max_d: Vector2 = (center - Vector2(24.0, 24.0)).abs()
		var t_x: float = 1e9
		if absf(dir.x) > 0.0001:
			t_x = max_d.x / absf(dir.x)
		var t_y: float = 1e9
		if absf(dir.y) > 0.0001:
			t_y = max_d.y / absf(dir.y)

		position = center + dir * min(t_x, t_y) - pivot_offset
		rotation = dir.angle()

	func _draw() -> void:
		var points: PackedVector2Array = PackedVector2Array(
			[
				Vector2(2.0, 2.0),
				Vector2(14.0, 8.0),
				Vector2(2.0, 14.0),
			]
		)
		draw_polyline(points, chevron_color, 2.5, true)
