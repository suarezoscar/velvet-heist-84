## @file hud_84.gd
## Capa de interfaz gráfica (HUD) con estética retro años 80 / casete analógico.
## Muestra el progreso de la cuota económica, estado de la obra de arte,
## reloj de ronda, tooltips dinámicos contextuales y paneles de victoria/derrota.
class_name HUD84
extends CanvasLayer

@onready var loot_label: Label = $TopBar/LootLabel if has_node("TopBar/LootLabel") else null
@onready var masterpiece_label: Label = $TopBar/MasterpieceLabel if has_node("TopBar/MasterpieceLabel") else null
@onready var timer_label: Label = $TopBar/TimerLabel if has_node("TopBar/TimerLabel") else null

@onready var prompt_panel: PanelContainer = $PromptPanel if has_node("PromptPanel") else null
@onready var prompt_label: Label = $PromptPanel/PromptLabel if has_node("PromptPanel/PromptLabel") else null

@onready var game_over_panel: PanelContainer = $GameOverPanel if has_node("GameOverPanel") else null
@onready var game_over_title: Label = $GameOverPanel/VBox/TitleLabel if has_node("GameOverPanel/VBox/TitleLabel") else null
@onready var game_over_sub: Label = $GameOverPanel/VBox/SubLabel if has_node("GameOverPanel/VBox/SubLabel") else null
@onready var blueprint_overlay: Control = $BlueprintMapOverlay if has_node("BlueprintMapOverlay") else null

## Referencia al personaje local para leer el objetivo que enfoca actualmente
var target_player: Node3D = null

func _ready() -> void:
	if game_over_panel != null:
		game_over_panel.visible = false
	if prompt_panel != null:
		prompt_panel.visible = false

func _process(_delta: float) -> void:
	_update_header_stats()
	_update_interaction_tooltip()

## Actualiza los textos de la barra superior leyendo reactivamente el GameManager
func _update_header_stats() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return

	if loot_label != null:
		var cur_val: int = int(gm.get("current_loot_value"))
		var target_val: int = int(gm.get("quota_target"))
		loot_label.text = "BOTIN: $%d / $%d" % [cur_val, target_val]
		loot_label.modulate = Color(0.3, 1.0, 0.4) if cur_val >= target_val else Color(1.0, 0.85, 0.3)

	if masterpiece_label != null:
		var has_art: bool = bool(gm.get("has_masterpiece"))
		if has_art:
			masterpiece_label.text = "[★] PIEZA MAESTRA: ASEGURADA"
			masterpiece_label.modulate = Color(1.0, 0.84, 0.0)
		else:
			masterpiece_label.text = "[ ] PIEZA MAESTRA: PENDIENTE"
			masterpiece_label.modulate = Color(0.6, 0.6, 0.6)

	if timer_label != null:
		var sec_left: float = float(gm.get("match_timer"))
		var mins: int = int(sec_left) / 60
		var secs: int = int(sec_left) % 60
		timer_label.text = "TIEMPO: %02d:%02d" % [mins, secs]
		timer_label.modulate = Color(1.0, 0.25, 0.25) if sec_left <= 60.0 else Color(0.9, 0.9, 0.9)

	_check_game_over_state(gm)

func _check_game_over_state(gm: Node) -> void:
	var cur_state: int = int(gm.get("current_state"))
	match cur_state:
		2: # MatchState.THIEF_ESCAPED
			_show_game_over_modal("¡EL LADRÓN HA ESCAPADO!", "El botin de 1984 esta a salvo. ¡Golpe maestro completado!", Color(0.25, 1.0, 0.4))
		3: # MatchState.THIEF_CAPTURED
			_show_game_over_modal("¡EL LADRÓN HA SIDO CAPTURADO!", "La seguridad privada neutralizo la infiltracion.", Color(1.0, 0.25, 0.25))
		4: # MatchState.TIME_EXPIRED
			_show_game_over_modal("¡TIEMPO AGOTADO!", "Llego el furgon policial y aseguro el perimetro.", Color(1.0, 0.55, 0.1))

## Actualiza el texto de interacción inferior cuando el interactor del jugador detecta un objeto
func _update_interaction_tooltip() -> void:
	if prompt_panel == null or prompt_label == null:
		return

	if target_player != null and "focused_interactive" in target_player:
		var obj: Object = target_player.get("focused_interactive")
		if obj != null and obj.has_method("get_interaction_text"):
			var txt: String = str(obj.call("get_interaction_text", target_player))
			prompt_label.text = txt
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
