## @file hud_84.gd
## Capa de interfaz gráfica (HUD) con estética retro años 80 / casete analógico.
## Muestra el progreso de la cuota económica, estado de la obra de arte,
## reloj de ronda, tooltips dinámicos contextuales, paneles de fin de partida,
## indicador de exposición del ladrón, vúmetro de ruido y marcadores fuera de pantalla.
class_name HUD84
extends CanvasLayer

const HUD_PALETTE: HudPalette = preload("res://assets/ui/hud_palette.tres")

## Referencia al personaje local para leer el objetivo que enfoca actualmente
var target_player: Node3D = null

## Estado actual de exposición del ladrón
var exposure_state: StringName = &""
var exposure_icon: Label = null
var exposure_label: Label = null
var exposure_row: Control = null
var noise_meter: NoiseMeter84 = null
## Tablilla de ronda: solo con un guardia en pantalla (interaction.md R6-R7)
var round_sheet: RoundSheet84 = null
## Imágenes de las cámaras del guardia que mira los monitores (LocalViewPresenter, M2)
var cctv_feeds: CCTVFeeds84 = null

var _exposure_state: StringName = &""
var _exposure_blink_timer: float = 0.0
var _noise_meter_visible: bool = false

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

	if exposure_icon == null:
		exposure_icon = get_node_or_null("ExposurePanel/VBox/HBox/ExposureIcon") as Label
		if exposure_icon == null:
			exposure_icon = get_node_or_null("ExposurePanel/HBox/ExposureIcon") as Label
		if exposure_icon == null:
			exposure_icon = get_node_or_null("ExposureIcon") as Label

	if exposure_label == null:
		exposure_label = get_node_or_null("ExposurePanel/VBox/HBox/ExposureLabel") as Label
		if exposure_label == null:
			exposure_label = get_node_or_null("ExposurePanel/HBox/ExposureLabel") as Label
		if exposure_label == null:
			exposure_label = get_node_or_null("ExposureLabel") as Label

	if exposure_row == null:
		exposure_row = get_node_or_null("ExposurePanel/VBox/HBox") as Control
		if exposure_row == null:
			exposure_row = get_node_or_null("ExposurePanel/HBox") as Control

	if noise_meter == null:
		noise_meter = get_node_or_null("ExposurePanel/VBox/NoiseMeter") as NoiseMeter84
		if noise_meter == null:
			noise_meter = get_node_or_null("NoiseMeter") as NoiseMeter84

	_update_exposure_panel_visibility()
	round_sheet = RoundSheet84.new()
	round_sheet.visible = false
	add_child(round_sheet)
	cctv_feeds = CCTVFeeds84.new()
	cctv_feeds.visible = false
	add_child(cctv_feeds)


func _process(delta: float) -> void:
	round_sheet.visible = target_player is GuardController3D
	_update_header_stats()
	_update_interaction_tooltip()
	_update_exposure_blink(delta)


## Actualiza el estado de exposición del ladrón en el HUD (&"shadow", &"lit", &"beam", &"")
func set_exposure(state: StringName) -> void:
	_exposure_state = state
	exposure_state = state
	_update_exposure_panel_visibility()
	if state == &"":
		return

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


## Devuelve el vúmetro de ruido del HUD
func get_noise_meter() -> NoiseMeter84:
	if noise_meter == null:
		noise_meter = get_node_or_null("ExposurePanel/VBox/NoiseMeter") as NoiseMeter84
		if noise_meter == null:
			noise_meter = get_node_or_null("NoiseMeter") as NoiseMeter84
		if noise_meter == null:
			noise_meter = NoiseMeter84.new()
			add_child(noise_meter)

	return noise_meter


## Controla la visibilidad del vúmetro de ruido
func set_noise_meter_visible(p_visible: bool) -> void:
	_noise_meter_visible = p_visible
	if noise_meter != null:
		noise_meter.visible = p_visible
	_update_exposure_panel_visibility()


func _update_exposure_panel_visibility() -> void:
	var has_exposure: bool = _exposure_state != &""

	if exposure_row != null:
		exposure_row.visible = has_exposure
	if noise_meter != null:
		noise_meter.visible = _noise_meter_visible
	if exposure_panel != null:
		exposure_panel.visible = has_exposure or _noise_meter_visible


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
	var chevron: OffscreenChevron84 = OffscreenChevron84.new()
	chevron.world_pos = world_pos
	chevron.lifetime = lifetime
	chevron.time_left = lifetime
	chevron.chevron_color = HUD_PALETTE.get_color_for_role(role)
	add_child(chevron)


## Devuelve los marcadores de ruido fuera de pantalla activos
func get_active_offscreen_markers() -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in get_children():
		if child is OffscreenChevron84:
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
	var sheet: String = (
		"Hoja de ronda: %d faltas de %d toleradas."
		% [GameManager.round_faults, GameManager.CLOCK_RULES.allowed_misses]
	)
	match GameManager.current_state:
		GameManager.MatchState.THIEF_ESCAPED:
			_show_game_over_modal(
				"¡EL LADRÓN HA ESCAPADO!",
				"El botin de 1984 esta a salvo. ¡Golpe maestro completado!",
				Color(0.25, 1.0, 0.4)
			)
		GameManager.MatchState.THIEF_CAPTURED:
			_show_game_over_modal(
				"¡EL LADRÓN HA SIDO CAPTURADO!",
				"La seguridad privada neutralizo la infiltracion.",
				Color(1.0, 0.25, 0.25)
			)
		GameManager.MatchState.TIME_EXPIRED:
			_show_game_over_modal(
				"¡TIEMPO AGOTADO!",
				"La ronda estaba al dia y la policia aseguro el perimetro.\n" + sheet,
				Color(1.0, 0.55, 0.1)
			)
		GameManager.MatchState.TIME_EXPIRED_BREACH:
			_show_game_over_modal(
				"¡LA RONDA FALLO!",
				"La central no cubrio a los guardias y la Pieza Maestra se fue.\n" + sheet,
				Color(0.25, 1.0, 0.4)
			)
		GameManager.MatchState.TIME_EXPIRED_DRAW:
			_show_game_over_modal(
				"EMPATE",
				"La ronda fallo, pero el ladron no llevaba la Pieza Maestra.\n" + sheet,
				Color(0.9, 0.9, 0.9)
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
