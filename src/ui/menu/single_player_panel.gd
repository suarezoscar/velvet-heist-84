## @file single_player_panel.gd
## Panel «Un jugador» del menú principal: el jugador es el ladrón y los guardias los lleva la
## IA. Lista de mapas, ficha del elegido y botón para empezar.
class_name SinglePlayerPanel
extends PanelContainer

## Se emite al pulsar «Empezar», con la escena del mapa elegido
signal start_requested(scene_path: String)
## Se emite al pulsar «Volver»
signal back_requested

const MAPS: Array[Dictionary] = [
	{
		"title": "MUSEO '84",
		"tag": "20 OBRAS  ·  VENTILACIÓN  ·  CUATRO SALIDAS",
		"desc": "Veintidós salas y un ala oriental. Roba tu encargo y sal por cualquier puerta.",
		"scene": "res://scenes/maps/museum_v2.tscn",
		"thumb": "res://assets/ui/thumb_museum_v2.png",
	},
]

var selected: int = 0
var map_buttons: Array[Button] = []
var start_button: Button = null
var back_button: Button = null
var _thumb: TextureRect = null
var _tag: Label = null
var _desc: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(820.0, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	box.add_child(MenuTheme84.label("UN JUGADOR", MenuTheme84.FONT_DISPLAY, 64, MenuTheme84.TEXT))
	box.add_child(
		MenuTheme84.label(
			"Eres el ladrón de guante blanco; la IA lleva a los guardias.",
			MenuTheme84.FONT_BODY,
			24,
			MenuTheme84.DIM
		)
	)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.custom_minimum_size = Vector2(300.0, 0.0)
	columns.add_child(list)
	for index: int in range(MAPS.size()):
		var button: Button = Button.new()
		button.text = MAPS[index]["title"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.toggle_mode = true
		button.pressed.connect(select.bind(index))
		list.add_child(button)
		map_buttons.append(button)
	columns.add_child(_build_card())
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	box.add_child(actions)
	back_button = Button.new()
	back_button.text = "VOLVER"
	back_button.pressed.connect(back_requested.emit)
	actions.add_child(back_button)
	start_button = Button.new()
	start_button.text = "EMPEZAR  ▶"
	start_button.custom_minimum_size = Vector2(220.0, 0.0)
	start_button.pressed.connect(func() -> void: start_requested.emit(MAPS[selected]["scene"]))
	actions.add_child(start_button)
	select(0)


## Elige un mapa de la lista y rellena su ficha
func select(index: int) -> void:
	selected = clampi(index, 0, MAPS.size() - 1)
	for i: int in range(map_buttons.size()):
		map_buttons[i].button_pressed = i == selected
	var data: Dictionary = MAPS[selected]
	_tag.text = data["tag"]
	_desc.text = data["desc"]
	_thumb.texture = load(data["thumb"]) if ResourceLoader.exists(data["thumb"]) else null


func _build_card() -> VBoxContainer:
	var card: VBoxContainer = VBoxContainer.new()
	card.add_theme_constant_override("separation", 10)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(460.0, 258.0)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card.add_child(_thumb)
	_tag = MenuTheme84.label("", MenuTheme84.FONT_STRONG, 20, MenuTheme84.AMBER)
	card.add_child(_tag)
	_desc = MenuTheme84.label("", MenuTheme84.FONT_BODY, 22, MenuTheme84.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc.custom_minimum_size = Vector2(460.0, 0.0)
	card.add_child(_desc)
	return card
