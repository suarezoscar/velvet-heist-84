## @file main_menu.gd
## Menú principal de inicio para 'Velvet Heist 84'.
## Controla la navegación del título, selección interactiva de mapas/escenarios,
## previsualización de fichas de misión e inicio de partida.
class_name MainMenu
extends Control

const SCENARIOS: Array[Dictionary] = [
	{
		"id": "museum",
		"title": "MUSEO METROPOLITANO '84",
		"subtitle": "Operación Asimétrica (1 Ladrón vs 2 Guardias)",
		"desc": "Infiltra las galerías de arte, evade las cámaras de videovigilancia CCTV en tiempo real y burla a los dos guardias para saquear la cámara acorazada.",
		"scene_path": "res://scenes/maps/museum_velvet_84.tscn",
		"thumb": "res://assets/ui/thumb_museum.png",
		"difficulty": "ALTA • CCTV EN DIRECTO • 2 GUARDIAS",
		"badge_color": Color(1.0, 0.35, 0.25)
	},
	{
		"id": "mansion",
		"title": "VILLA BELMONTE '84",
		"subtitle": "Infiltración Clásica en Mansión",
		"desc": "Residencia de época con suelos de mármol resonante y parqué. Localiza la caja fuerte de combinación analógica y escapa en el bólido burdeos.",
		"scene_path": "res://scenes/maps/mansion_belmonte.tscn",
		"thumb": "res://assets/ui/thumb_mansion.png",
		"difficulty": "MEDIA • 1 GUARDIA DE RONDA",
		"badge_color": Color(0.3, 0.75, 1.0)
	},
	{
		"id": "gym",
		"title": "GIMNASIO ACÚSTICO '84",
		"subtitle": "Campo de Entrenamiento de Sigilo",
		"desc": "Entorno de calibración táctica para experimentar con la propagación de ondas sonoras en 3D, pisadas según superficie y conos de visión.",
		"scene_path": "res://scenes/maps/test_isometric_gym.tscn",
		"thumb": "res://assets/ui/thumb_museum.png",
		"difficulty": "PRÁCTICA Y MECÁNICAS",
		"badge_color": Color(0.4, 0.95, 0.5)
	}
]

@onready var main_view: Control = $MainView
@onready var scenario_view: Control = $ScenarioView

@onready var quick_play_btn: Button = $MainView/ButtonsBox/QuickPlayButton
@onready var select_stage_btn: Button = $MainView/ButtonsBox/SelectStageButton
@onready var quit_btn: Button = $MainView/ButtonsBox/QuitButton
@onready var back_btn: Button = $ScenarioView/BackButton

@onready var scenario_title_lbl: Label = $ScenarioView/ContentHBox/DetailsPanel/VBox/TitleLabel
@onready var scenario_sub_lbl: Label = $ScenarioView/ContentHBox/DetailsPanel/VBox/SubLabel
@onready var scenario_desc_lbl: Label = $ScenarioView/ContentHBox/DetailsPanel/VBox/DescLabel
@onready var scenario_diff_lbl: Label = $ScenarioView/ContentHBox/DetailsPanel/VBox/DifficultyLabel
@onready var scenario_thumb_rect: TextureRect = $ScenarioView/ContentHBox/DetailsPanel/VBox/ThumbRect
@onready var launch_btn: Button = $ScenarioView/ContentHBox/DetailsPanel/VBox/LaunchButton
@onready var list_container: VBoxContainer = $ScenarioView/ContentHBox/ListPanel/Scroll/VBox

var _selected_idx: int = 0

func _ready() -> void:
	quick_play_btn.pressed.connect(_on_quick_play_pressed)
	select_stage_btn.pressed.connect(_on_select_stage_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	launch_btn.pressed.connect(_on_launch_scenario_pressed)
	_show_main_view()
	_populate_scenario_list()
	_select_scenario(0)

func _show_main_view() -> void:
	main_view.visible = true
	scenario_view.visible = false

func _show_scenario_view() -> void:
	main_view.visible = false
	scenario_view.visible = true

func _populate_scenario_list() -> void:
	for child in list_container.get_children():
		child.queue_free()

	for i: int in range(SCENARIOS.size()):
		var data: Dictionary = SCENARIOS[i]
		var btn: Button = Button.new()
		btn.text = " [ %d ]  %s" % [i + 1, data["title"]]
		btn.custom_minimum_size = Vector2(0, 52)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_scenario_btn_pressed.bind(i))
		list_container.add_child(btn)

func _select_scenario(idx: int) -> void:
	_selected_idx = clampi(idx, 0, SCENARIOS.size() - 1)
	var data: Dictionary = SCENARIOS[_selected_idx]

	scenario_title_lbl.text = data["title"]
	scenario_sub_lbl.text = data["subtitle"]
	scenario_desc_lbl.text = data["desc"]
	scenario_diff_lbl.text = "NIVEL DE ALERTA: " + data["difficulty"]
	scenario_diff_lbl.modulate = data["badge_color"]

	if ResourceLoader.exists(data["thumb"]):
		scenario_thumb_rect.texture = load(data["thumb"])

func _on_scenario_btn_pressed(idx: int) -> void:
	_select_scenario(idx)

func _on_quick_play_pressed() -> void:
	_load_scene("res://scenes/maps/museum_velvet_84.tscn")

func _on_select_stage_pressed() -> void:
	_show_scenario_view()

func _on_launch_scenario_pressed() -> void:
	var data: Dictionary = SCENARIOS[_selected_idx]
	_load_scene(data["scene_path"])

func _on_back_pressed() -> void:
	_show_main_view()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _load_scene(path: String) -> void:
	print("[MainMenu] Cargando escenario: ", path)
	get_tree().change_scene_to_file(path)
