## @file blueprint_map_overlay.gd
## Plano arquitectónico cianotipo diegético 1984 para Velvet Heist 84.
## Renderiza el plano vectorial 2D del edificio con estética de papel azul técnico,
## activable en partida con la tecla [M] o [TAB].

class_name BlueprintMapOverlay
extends Control

const FloorplanBlueprint = preload("res://src/generation/floorplan_blueprint.gd")

var blueprint: FloorplanBlueprint = null
var player_pawn: Node3D = null

# Configuración visual cianotipo
const COLOR_BG: Color = Color(0.04, 0.10, 0.18, 0.95)
const COLOR_GRID: Color = Color(0.08, 0.20, 0.32, 0.40)
const COLOR_WALL: Color = Color(0.80, 0.92, 1.0, 0.90)
const COLOR_DOOR: Color = Color(0.20, 0.90, 0.60, 0.85)
const COLOR_TEXT: Color = Color(0.70, 0.88, 1.0, 0.95)
const COLOR_HEADER: Color = Color(1.0, 0.82, 0.40, 1.0)
const COLOR_PLAYER: Color = Color(0.30, 0.85, 1.0, 1.0)

var map_scale: float = 24.0 # Pixeles por metro
var map_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	set_process_unhandled_input(true)
	if blueprint == null:
		blueprint = FloorplanBlueprint.generate_museum_1984()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_blueprint"):
		toggle_map()
		get_viewport().set_input_as_handled()

func toggle_map() -> void:
	visible = not visible
	if visible:
		queue_redraw()

func _draw() -> void:
	if not visible or blueprint == null:
		return

	var vp_size: Vector2 = get_viewport_rect().size
	# Panel de fondo con margen
	var margin: float = 40.0
	var panel_rect: Rect2 = Rect2(margin, margin, vp_size.x - margin * 2.0, vp_size.y - margin * 2.0)
	draw_rect(panel_rect, COLOR_BG, true)
	draw_rect(panel_rect, COLOR_WALL, false, 2.0)

	# Centro del mapa en el centro del panel
	var center_ui: Vector2 = panel_rect.position + panel_rect.size * 0.5
	# Centro del museo en 3D está aprox en (X=0, Z=-3.0)
	map_offset = center_ui - Vector2(0.0, -3.0) * map_scale

	# 1. Cuadrícula técnica de fondo
	var grid_step: float = map_scale * 2.0 # Cada 2 metros
	for x: float in range(int(panel_rect.position.x), int(panel_rect.end.x), int(grid_step)):
		draw_line(Vector2(x, panel_rect.position.y), Vector2(x, panel_rect.end.y), COLOR_GRID, 1.0)
	for y: float in range(int(panel_rect.position.y), int(panel_rect.end.y), int(grid_step)):
		draw_line(Vector2(panel_rect.position.x, y), Vector2(panel_rect.end.x, y), COLOR_GRID, 1.0)

	# 2. Dibujar Salas
	var default_font = ThemeDB.fallback_font
	for room_id: String in blueprint.rooms:
		var room: FloorplanBlueprint.RoomData = blueprint.rooms[room_id]
		var r_pos: Vector2 = _world_to_map(Vector2(room.bounds.position.x, room.bounds.position.y))
		var r_size: Vector2 = Vector2(room.bounds.size.x * map_scale, room.bounds.size.y * map_scale)
		var r_rect: Rect2 = Rect2(r_pos, r_size)

		# Fondo sutil de habitación
		var room_color: Color = Color(0.10, 0.22, 0.36, 0.45)
		if room.id == "vault":
			room_color = Color(0.35, 0.08, 0.12, 0.55)
		elif room.id.begins_with("alley") or room.id == "sidewalk":
			room_color = Color(0.06, 0.12, 0.18, 0.45)
		draw_rect(r_rect, room_color, true)
		draw_rect(r_rect, COLOR_WALL, false, 2.0)

		# Nombre de la sala
		var font_size: int = 13
		var text_pos: Vector2 = r_rect.position + Vector2(10.0, 22.0)
		draw_string(default_font, text_pos, room.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_TEXT)

	# 3. Dibujar Puertas y Accesos
	for d: FloorplanBlueprint.DoorwayData in blueprint.doors:
		var d_center_2d: Vector2 = Vector2(d.center.x, d.center.z)
		var ui_pos: Vector2 = _world_to_map(d_center_2d)
		var d_color: Color = Color(1.0, 0.4, 0.4) if d.is_reinforced else COLOR_DOOR

		if d.wall_axis == 0: # Muro en X
			var half_w: float = (d.width * map_scale) * 0.5
			# Limpiar hueco de pared
			draw_line(ui_pos - Vector2(half_w, 0), ui_pos + Vector2(half_w, 0), COLOR_BG, 4.0)
			# Marcador de puerta
			draw_line(ui_pos - Vector2(half_w, 0), ui_pos + Vector2(half_w, 0), d_color, 2.5)
		else: # Muro en Z
			var half_h: float = (d.width * map_scale) * 0.5
			draw_line(ui_pos - Vector2(0, half_h), ui_pos + Vector2(0, half_h), COLOR_BG, 4.0)
			draw_line(ui_pos - Vector2(0, half_h), ui_pos + Vector2(0, half_h), d_color, 2.5)

	# 4. Marcadores de Objetivos Tácticos
	# Bóveda Central (Pieza Maestra)
	var vault_pos: Vector2 = _world_to_map(Vector2(0.0, -6.25))
	draw_circle(vault_pos, 7.0, Color(1.0, 0.2, 0.3))
	draw_string(default_font, vault_pos + Vector2(-28, 20), "[PIEZA MAESTRA]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.4, 0.4))

	# Coche de huida
	var car_pos: Vector2 = _world_to_map(Vector2(-2.0, 8.0))
	draw_circle(car_pos, 6.0, Color(0.2, 0.9, 0.4))
	draw_string(default_font, car_pos + Vector2(-24, 18), "[PUNTO DE HUIDA]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 1.0, 0.5))

	# Marcador del Jugador Ladrón (si está presente)
	if player_pawn != null and is_instance_valid(player_pawn):
		var p_xz: Vector2 = Vector2(player_pawn.global_position.x, player_pawn.global_position.z)
		var p_ui: Vector2 = _world_to_map(p_xz)
		draw_circle(p_ui, 5.0, COLOR_PLAYER)
		draw_circle(p_ui, 9.0, Color(0.3, 0.85, 1.0, 0.4))

	# 5. Cabecera y Leyenda Técnica 1984
	var header_pos: Vector2 = panel_rect.position + Vector2(25.0, 35.0)
	draw_string(default_font, header_pos, "PLANO ARQUITECTÓNICO CIANOTIPO — METROPOLITAN MUSEUM '84", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_HEADER)
	draw_string(default_font, header_pos + Vector2(0.0, 22.0), "DOCUMENTO CLASIFICADO // NIVEL DE SEGURIDAD 4 // PULSA [M] / [TAB] PARA CERRAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_TEXT)

func _world_to_map(world_xz: Vector2) -> Vector2:
	return map_offset + world_xz * map_scale
