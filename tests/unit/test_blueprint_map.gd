## @file test_blueprint_map.gd
## #117: el plano táctico (capas, zoom, objetos interactivos, abanicos, leyenda y dibujo).
extends GutTest

const OVERLAY := preload("res://src/ui/blueprint_map_overlay.gd")
const ICONS := preload("res://src/ui/blueprint_map_icons.gd")
const PROPS := preload("res://src/ui/blueprint_map_props.gd")
const ROOMS := preload("res://src/ui/blueprint_map_rooms.gd")
const LEGEND := preload("res://src/ui/blueprint_map_legend.gd")
const LEVEL_PATH: String = "res://data/levels/museum_v2.json"


func test_toggle_layer_flips_and_restores() -> void:
	var overlay: BlueprintMapOverlay = autofree(BlueprintMapOverlay.new())
	for layer: StringName in overlay.layers:
		assert_true(overlay.layers[layer], "la capa %s empieza encendida" % layer)
	overlay.toggle_layer(&"power")
	assert_false(overlay.layers[&"power"])
	overlay.toggle_layer(&"power")
	assert_true(overlay.layers[&"power"])
	for layer: StringName in [&"people", &"security", &"places"]:
		assert_true(overlay.layers[layer], "la capa %s no cambia" % layer)


func test_zoom_is_clamped() -> void:
	var overlay: BlueprintMapOverlay = autofree(BlueprintMapOverlay.new())
	overlay.zoom_at(Vector2.ZERO, 100.0)
	assert_almost_eq(overlay.zoom, OVERLAY.ZOOM_MAX, 0.001)
	overlay.zoom_at(Vector2.ZERO, 0.1)
	assert_almost_eq(overlay.zoom, 1.0, 0.001)
	overlay.zoom_at(Vector2.ZERO, 2.0)
	assert_almost_eq(overlay.zoom, 2.0, 0.001)


func test_kind_of_maps_each_prop() -> void:
	var pairs: Array = [
		[CoffeeMachine3D.new(), &"coffee"],
		[CCTVDesk3D.new(), &"desk"],
		[PowerBox3D.new(), &"power"],
		[LightSwitch3D.new(), &"switch"],
		[Lamp3D.new(), &"lamp"],
		[ReplicaTable3D.new(), &"copy"],
		[EscapeCar3D.new(), &"car"],
		[LootItem3D.new(), &"loot"],
		[Node3D.new(), &""],
	]
	for pair: Array in pairs:
		var node: Node = autofree(pair[0])
		assert_eq(PROPS.kind_of(node), pair[1], "tipo de %s" % node.get_class())


func test_collect_finds_only_map_props() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	root.add_child(Lamp3D.new())
	var plain: Node3D = Node3D.new()
	root.add_child(plain)
	plain.add_child(PowerBox3D.new())
	assert_eq(PROPS.collect(root).size(), 2)
	assert_eq(PROPS.collect(null).size(), 0)


func test_ray_length_stops_at_walls() -> void:
	var room: Rect2 = Rect2(0, 0, 10, 10)
	var pos: Vector2 = Vector2(5, 5)
	assert_almost_eq(PROPS._ray_length(room, pos, Vector2.RIGHT, 9.5), 5.0, 0.01)
	assert_almost_eq(PROPS._ray_length(room, pos, Vector2.UP, 9.5), 5.0, 0.01)
	assert_almost_eq(PROPS._ray_length(room, pos, Vector2.RIGHT, 3.0), 3.0, 0.01)
	assert_almost_eq(PROPS._ray_length(Rect2(), pos, Vector2.RIGHT, 9.5), 9.5, 0.01)
	var diagonal: Vector2 = Vector2(1, 1).normalized()
	assert_almost_eq(PROPS._ray_length(room, pos, diagonal, 9.5), 5.0 * sqrt(2.0), 0.01)


func test_room_ahead_returns_room_or_empty() -> void:
	var data: LevelData = LevelData.load_json(LEVEL_PATH)
	var rect: Rect2 = data.room_rect(data.section("rooms")[0])
	assert_eq(PROPS._room_ahead(data, rect.get_center()), rect)
	assert_eq(PROPS._room_ahead(data, Vector2(-1000, -1000)), Rect2())


func test_every_target_lies_in_a_gallery() -> void:
	var data: LevelData = LevelData.load_json(LEVEL_PATH)
	var galleries: Dictionary = ROOMS.galleries(data)
	for target: Dictionary in data.section("targets"):
		var pos: Vector2 = Vector2(target["pos"][0], target["pos"][1])
		var inside: bool = false
		for room: Dictionary in data.section("rooms"):
			if galleries.has(String(room["id"])) and data.room_rect(room).has_point(pos):
				inside = true
		assert_true(inside, "la pieza %s está en una galería" % target["id"])
	assert_true(galleries.size() < data.section("rooms").size(), "hay cuartos de servicio")


func test_legend_groups_cover_every_layer() -> void:
	var icons: Dictionary = {}
	for groups: Dictionary in [LEGEND.THIEF_GROUPS, LEGEND.GUARD_GROUPS]:
		var kinds: Array = []
		for layer: StringName in LEGEND.LAYERS:
			assert_true(groups.has(layer), "falta la capa %s" % layer)
			assert_true(groups[layer][0] is String and not String(groups[layer][0]).is_empty())
			assert_gt(groups[layer][1].size(), 0, "la capa %s tiene filas" % layer)
			for row: Array in groups[layer][1]:
				kinds.append(row[0])
		icons[groups] = kinds
	var thief: Array = icons[LEGEND.THIEF_GROUPS]
	var guard: Array = icons[LEGEND.GUARD_GROUPS]
	assert_false(thief.has(&"mate") or thief.has(&"trace"), "el ladrón no ve compañero ni rastro")
	for kind: StringName in [&"contract", &"car", &"copy"]:
		assert_false(guard.has(kind), "el guardia no ve %s" % kind)


func test_icons_grow_a_little_with_zoom() -> void:
	# ICONS.at solo se puede llamar dentro de _draw: aquí se comprueba la escala de los iconos
	assert_almost_eq(pow(4.0, OVERLAY.ICON_GROWTH), 1.62, 0.01)
	assert_eq(pow(1.0, OVERLAY.ICON_GROWTH), 1.0)
	assert_not_null(ICONS)


func test_overlay_draws_without_errors() -> void:
	var overlay: BlueprintMapOverlay = BlueprintMapOverlay.new()
	add_child_autofree(overlay)
	overlay.size = Vector2(1280, 720)
	overlay.data = LevelData.load_json(LEVEL_PATH)
	overlay.visible = true
	overlay.queue_redraw()
	await wait_process_frames(2)
	overlay.zoom_at(Vector2(400, 300), 3.0)
	overlay.queue_redraw()
	await wait_process_frames(2)
	assert_true(overlay.zoom > 1.0)
