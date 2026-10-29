## @file test_game_updater.gd
## Actualizaciones con Velopack (FEAT-036): versiones, qué paquetes bajar (cadena de diferencias
## o completo), avisos de Velopack al arrancar y descarga con su comprobación.
extends GutTest


func _feed() -> Dictionary:
	var assets: Array = []
	for version: String in ["0.9.0", "0.9.1", "0.9.2", "0.9.3"]:
		assets.append(
			{"Version": version, "Type": "Full", "FileName": "f%s" % version, "Size": 1000}
		)
		if version != "0.9.0":
			assets.append(
				{"Version": version, "Type": "Delta", "FileName": "d%s" % version, "Size": 10}
			)
	return {"Assets": assets}


func _names(plan: Array[Dictionary]) -> Array:
	return plan.map(func(item: Dictionary) -> String: return String(item["FileName"]))


func test_versions_compare_by_number() -> void:
	assert_true(GameUpdater.is_newer("0.10.0", "0.9.9"), "10 > 9, no por texto")
	assert_false(GameUpdater.is_newer("0.9.1", "0.9.1"))
	assert_false(GameUpdater.is_newer("0.9.1", "0.9.1-dev+abc"), "Lo que va tras «-» no cuenta")


func test_plan_chains_deltas_or_takes_the_full_package() -> void:
	assert_eq(_names(GameUpdater.make_plan(_feed(), "0.9.3", true)), [], "Al día")
	assert_eq(
		_names(GameUpdater.make_plan(_feed(), "0.9.2", true)), ["d0.9.3"], "Una versión atrás"
	)
	assert_eq(
		_names(GameUpdater.make_plan(_feed(), "0.9.0", true)),
		["d0.9.1", "d0.9.2", "d0.9.3"],
		"Varias atrás: la cadena de diferencias"
	)
	assert_eq(
		_names(GameUpdater.make_plan(_feed(), "0.8.0", true)),
		["f0.9.3"],
		"Versión fuera del índice: completo"
	)
	var feed: Dictionary = _feed()
	(feed["Assets"] as Array).remove_at(3)  # falta el completo de 0.9.2: la cadena sigue
	assert_eq(_names(GameUpdater.make_plan(feed, "0.9.0", true)), ["d0.9.1", "d0.9.2", "d0.9.3"])
	feed = _feed()
	(feed["Assets"] as Array).remove_at(4)  # falta la diferencia de 0.9.2: cadena rota
	assert_eq(
		_names(GameUpdater.make_plan(feed, "0.9.0", true)), ["f0.9.3"], "Cadena rota: completo"
	)


func test_plan_without_installed_full_package_takes_the_full_one() -> void:
	assert_eq(_names(GameUpdater.make_plan(_feed(), "0.9.2", false)), ["f0.9.3"])


func test_plan_prefers_full_when_deltas_weigh_more() -> void:
	var feed: Dictionary = _feed()
	for item: Dictionary in feed["Assets"]:
		if item["Type"] == "Delta":
			item["Size"] = 600
	assert_eq(_names(GameUpdater.make_plan(feed, "0.9.0", true)), ["f0.9.3"])


func test_not_installed_with_velopack_does_not_check() -> void:
	assert_eq(GameUpdater.update_program(), "", "Desde el editor o el .zip no hay Update")
	assert_false(GameUpdater.is_velopack_hook(), "Sin avisos de Velopack al arrancar los tests")


func test_sha256_of_a_file() -> void:
	var path: String = "user://test_updater_hash.bin"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("velvet")
	file.close()
	assert_eq(
		GameUpdater._sha256(path),
		"f4c44266a2dfad9847930615218f2811c5ee3248c6df3d3921a6d2b8e67c8bf6"
	)
	DirAccess.remove_absolute(path)
