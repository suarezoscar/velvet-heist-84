## @file update_notice.gd
## Aviso de versión nueva en el menú principal (FEAT-036). Solo aparece si el juego se instaló
## con Velopack y hay una versión mayor en GitHub: «Ha llegado la versión 0.1.23» con un botón
## que la descarga (barra de progreso) y luego reinicia el juego ya actualizado. Nunca sale en
## mitad de una partida: vive en el menú.
class_name UpdateNotice
extends PanelContainer

var updater: GameUpdater = null
var title: Label = null
var detail: Label = null
var bar: ProgressBar = null
var action: Button = null
## Descargada y lista: se instala en cuanto el menú principal esté a la vista
var _ready_to_install: bool = false


func _ready() -> void:
	name = "UpdateNotice"
	visible = false
	custom_minimum_size = Vector2(440.0, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	title = MenuTheme84.label("", MenuTheme84.FONT_STRONG, 26, MenuTheme84.AMBER)
	box.add_child(title)
	detail = MenuTheme84.label("", MenuTheme84.FONT_BODY, 20, MenuTheme84.DIM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)
	bar = ProgressBar.new()
	bar.visible = false
	bar.max_value = 1.0
	box.add_child(bar)
	action = Button.new()
	action.text = "ACTUALIZAR Y REINICIAR"
	action.pressed.connect(_on_action)
	box.add_child(action)
	updater = GameUpdater.new()
	add_child(updater)
	updater.update_found.connect(_on_found)
	updater.progress.connect(func(fraction: float) -> void: bar.value = fraction)
	updater.preparing.connect(func() -> void: action.text = "PREPARANDO…")
	updater.ready_to_apply.connect(_on_ready_to_apply)
	visibility_changed.connect(_apply_when_visible)
	updater.failed.connect(_on_failed)
	updater.check()


func _on_found(version: String) -> void:
	title.text = "HA LLEGADO LA VERSIÓN %s" % version
	detail.text = "El juego se cerrará un momento y volverá a abrirse ya actualizado."
	visible = true


func _on_action() -> void:
	action.disabled = true
	action.text = "DESCARGANDO…"
	bar.visible = true
	updater.download()


## Solo se cierra para instalar con el menú principal a la vista: si el jugador ha entrado en
## la sala de espera mientras tanto, espera a que vuelva
func _apply_when_visible() -> void:
	if _ready_to_install and is_visible_in_tree():
		updater.apply()


func _on_ready_to_apply() -> void:
	_ready_to_install = true
	action.text = "INSTALANDO…"
	_apply_when_visible()


func _on_failed(reason: String) -> void:
	_ready_to_install = false
	detail.text = reason
	action.disabled = false
	action.text = "VOLVER A INTENTARLO"
