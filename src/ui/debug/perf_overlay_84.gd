## @file perf_overlay_84.gd
## Panel de rendimiento y red (FEAT-021). Autoload PerfOverlay: esquina inferior derecha,
## encima de todo. Enseña FPS y tiempos de frame y, con red, el ping, la pérdida y el tráfico
## propios, los snapshots por segundo y el ping de cada jugador (NetStats). Se muestra con F9 o
## con la opción «Panel de rendimiento» (GameSettings.show_perf). No existe en el servidor.
class_name PerfOverlay84
extends CanvasLayer

const TOGGLE_KEY: Key = KEY_F9
const REFRESH_INTERVAL: float = 0.25
const MARGIN: Vector2 = Vector2(16.0, 16.0)
## Ping (ms) a partir del cual se pinta en ámbar y en rojo
const PING_WARN: int = 80
const PING_BAD: int = 150
const OK_HEX: String = "4be38a"
const WARN_HEX: String = "f2b84b"
const BAD_HEX: String = "ff4a3d"

var text_label: RichTextLabel = null
var _panel: PanelContainer = null
var _timer: float = 0.0


func _ready() -> void:
	layer = 120
	visible = false
	if DisplayServer.get_name() == "headless":
		set_process(false)
		set_process_unhandled_key_input(false)
		return
	_build()
	set_shown(GameSettings.load_saved().show_perf)


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH_INTERVAL
	refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		set_shown(not visible)
		get_viewport().set_input_as_handled()


func set_shown(on: bool) -> void:
	visible = on and _panel != null
	if visible:
		refresh()


## Recompone el texto con los datos actuales
func refresh() -> void:
	if text_label == null:
		return
	var players: Array[String] = []
	var connected: Dictionary = NetManager.get_connected_players()
	for peer_id: int in NetStats.sorted_peers():
		var info: Dictionary = connected.get(peer_id, {})
		var stats: Dictionary = NetStats.peers[peer_id]
		players.append(
			player_line(
				NetStats.role_label(info.get("role", &"")),
				String(info.get("name", "peer %d" % peer_id)),
				int(stats["rtt"]),
				float(stats["loss"])
			)
		)
	var own_loss: float = 0.0
	var own: Dictionary = NetStats.peers.get(multiplayer.get_unique_id(), {})
	if own.has("loss"):
		own_loss = float(own["loss"])
	text_label.text = compose(
		{
			"fps": Engine.get_frames_per_second(),
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"online": NetManager.is_online(),
			"server": NetManager.is_online() and multiplayer.is_server(),
			"rtt": NetStats.local_rtt(),
			"loss": own_loss,
			"sent": NetStats.sent_kbps,
			"received": NetStats.received_kbps,
			"snapshots": NetStats.snapshots_per_second,
		},
		players
	)


## Texto BBCode del panel a partir de las medidas (lo usan los tests)
static func compose(data: Dictionary, players: Array[String]) -> String:
	var fps: float = float(data.get("fps", 0.0))
	var frame_ms: float = 1000.0 / fps if fps > 0.0 else 0.0
	var lines: Array[String] = [
		(
			"[b]FPS %d[/b]   %.1f ms   [color=#8a8f9c]v%s[/color]"
			% [roundi(fps), frame_ms, GameVersion.current()]
		),
		(
			"proceso %.1f ms · física %.1f ms"
			% [float(data.get("process_ms", 0.0)), float(data.get("physics_ms", 0.0))]
		),
	]
	if not bool(data.get("online", false)):
		lines.append("[color=#8a8f9c]sin red[/color]")
		return "\n".join(PackedStringArray(lines))
	lines.append("")
	if not bool(data.get("server", false)):
		lines.append(
			(
				"[b]RED[/b]  ping %s · pérdida %d %%"
				% [ping_text(int(data.get("rtt", -1))), roundi(float(data.get("loss", 0.0)))]
			)
		)
	(
		lines
		. append(
			(
				"↑ %.1f kB/s · ↓ %.1f kB/s · %d snap/s"
				% [
					float(data.get("sent", 0.0)),
					float(data.get("received", 0.0)),
					int(data.get("snapshots", 0)),
				]
			)
		)
	)
	if not players.is_empty():
		lines.append("")
		lines.append("[b]JUGADORES[/b]")
		lines.append_array(players)
	return "\n".join(PackedStringArray(lines))


## «LADRÓN     Agente_5   42 ms  0 %», con el ping en color
static func player_line(role: String, player_name: String, rtt: int, loss: float) -> String:
	return "%-10s %-12s %s  %d %%" % [role, player_name.left(12), ping_text(rtt), roundi(loss)]


## Ping con color según su valor; «—» si aún no se ha medido
static func ping_text(rtt: int) -> String:
	if rtt < 0:
		return "—"
	var hex: String = OK_HEX
	if rtt >= PING_BAD:
		hex = BAD_HEX
	elif rtt >= PING_WARN:
		hex = WARN_HEX
	return "[color=#%s]%d ms[/color]" % [hex, rtt]


func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = MenuTheme84.box(
		Color(MenuTheme84.INK, 0.78), Color(MenuTheme84.TEXT, 0.18), 1
	)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	# Abajo a la derecha: arriba están la hoja de ronda y el indicador de sombra
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.position -= MARGIN
	root.add_child(_panel)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_label.scroll_active = false
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.custom_minimum_size = Vector2(360.0, 0.0)
	text_label.add_theme_font_override("normal_font", MenuTheme84.FONT_MONO)
	text_label.add_theme_font_override("bold_font", MenuTheme84.FONT_MONO)
	text_label.add_theme_font_size_override("normal_font_size", 17)
	text_label.add_theme_font_size_override("bold_font_size", 17)
	text_label.add_theme_color_override("default_color", MenuTheme84.TEXT)
	_panel.add_child(text_label)
