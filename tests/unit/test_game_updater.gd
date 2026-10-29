## @file test_game_updater.gd
## Actualizaciones con Velopack (FEAT-036): versiones, qué paquetes bajar (cadena de diferencias
## o completo), avisos de Velopack al arrancar y descarga con su comprobación.
extends GutTest


func _feed() -> Dictionary:
	var assets: Array = []
	for version: String in ["0.9.0", "0.9.1", "0.9.2", "0.9.3"]:
		assets.append(
			{"Version": version, "Type": "Full", "FileName": "f%s.nupkg" % version, "Size": 1000}
		)
		if version != "0.9.0":
			assets.append(
				{"Version": version, "Type": "Delta", "FileName": "d%s.nupkg" % version, "Size": 10}
			)
	return {"Assets": assets}


func _names(plan: Array[Dictionary]) -> Array:
	return plan.map(
		func(item: Dictionary) -> String: return String(item["FileName"]).trim_suffix(".nupkg")
	)


func test_versions_compare_by_number() -> void:
	assert_true(UpdatePlan.is_newer("0.10.0", "0.9.9"), "10 > 9, no por texto")
	assert_false(UpdatePlan.is_newer("0.9.1", "0.9.1"))
	assert_false(UpdatePlan.is_newer("0.9.1", "0.9.1-dev+abc"), "Lo que va tras «-» no cuenta")


func test_plan_chains_deltas_or_takes_the_full_package() -> void:
	assert_eq(_names(UpdatePlan.make(_feed(), "0.9.3", true)), [], "Al día")
	assert_eq(_names(UpdatePlan.make(_feed(), "0.9.2", true)), ["d0.9.3"], "Una versión atrás")
	assert_eq(
		_names(UpdatePlan.make(_feed(), "0.9.0", true)),
		["d0.9.1", "d0.9.2", "d0.9.3"],
		"Varias atrás: la cadena de diferencias"
	)
	assert_eq(
		_names(UpdatePlan.make(_feed(), "0.8.0", true)),
		["f0.9.3"],
		"Versión fuera del índice: completo"
	)
	var feed: Dictionary = _feed()
	(feed["Assets"] as Array).remove_at(3)  # falta el completo de 0.9.2: la cadena sigue
	assert_eq(_names(UpdatePlan.make(feed, "0.9.0", true)), ["d0.9.1", "d0.9.2", "d0.9.3"])
	feed = _feed()
	(feed["Assets"] as Array).remove_at(4)  # falta la diferencia de 0.9.2: cadena rota
	assert_eq(_names(UpdatePlan.make(feed, "0.9.0", true)), ["f0.9.3"], "Cadena rota: completo")


func test_plan_without_installed_full_package_takes_the_full_one() -> void:
	assert_eq(_names(UpdatePlan.make(_feed(), "0.9.2", false)), ["f0.9.3"])


func test_plan_prefers_full_when_deltas_weigh_more() -> void:
	var feed: Dictionary = _feed()
	for item: Dictionary in feed["Assets"]:
		if item["Type"] == "Delta":
			item["Size"] = 600
	assert_eq(_names(UpdatePlan.make(feed, "0.9.0", true)), ["f0.9.3"])


func test_each_package_comes_from_the_release_of_its_version() -> void:
	var item: Dictionary = {"Version": "0.1.30", "FileName": "VelvetHeist84-0.1.30-delta.nupkg"}
	assert_eq(
		VelopackInstall.package_url(item),
		VelopackInstall.REPOSITORY + "/releases/download/v0.1.30/VelvetHeist84-0.1.30-delta.nupkg"
	)
	assert_string_ends_with(
		VelopackInstall.feed_url(), "/releases/latest/download/releases.linux.json"
	)


func test_not_installed_with_velopack_does_not_check() -> void:
	assert_eq(VelopackInstall.update_program(), "", "Desde el editor o el .zip no hay Update")
	assert_false(VelopackInstall.is_hook(), "Sin avisos de Velopack al arrancar los tests")


func test_velopack_hooks_close_the_game() -> void:
	assert_true(VelopackInstall.is_hook(PackedStringArray(["--veloapp-updated", "0.9.6"])))
	assert_true(VelopackInstall.is_hook(PackedStringArray(["--veloapp-install", "0.9.4"])))
	assert_false(VelopackInstall.is_hook(PackedStringArray(["--server"])))


func test_odd_index_entries_are_ignored() -> void:
	var good: Dictionary = {"Version": "0.9.3", "FileName": "VelvetHeist84-0.9.3-full.nupkg"}
	assert_true(UpdatePlan.is_safe(good))
	for bad: Dictionary in [
		{"Version": "0.9.3", "FileName": "..\\..\\evil.nupkg"},
		{"Version": "0.9.3", "FileName": "a&calc.nupkg"},
		{"Version": "0.9.3", "FileName": "../x.nupkg"},
		{"Version": "0.9.3", "FileName": "..nupkg"},
		{"Version": "0.9.3", "FileName": "setup.exe"},
		{"Version": "0.9.3&x", "FileName": "ok.nupkg"},
		{"Version": "../0.9.3", "FileName": "ok.nupkg"},
	]:
		assert_false(UpdatePlan.is_safe(bad), "Descartada: %s" % bad)
	var feed: Dictionary = _feed()
	(feed["Assets"] as Array).append(
		{"Version": "9.9.9", "Type": "Full", "FileName": "a&b.nupkg", "Size": 1}
	)
	(feed["Assets"] as Array).append("basura")
	assert_eq(_names(UpdatePlan.make(feed, "0.9.2", true)), ["d0.9.3"], "Lo raro no cuenta")


func test_keep_only_leaves_the_new_full_package() -> void:
	var folder: String = OS.get_user_data_dir().path_join("test_updater_packages")
	DirAccess.make_dir_recursive_absolute(folder)
	for file: String in ["a-full.nupkg", "b-delta.nupkg", "c-full.nupkg", "notas.txt"]:
		FileAccess.open(folder.path_join(file), FileAccess.WRITE).close()
	VelopackInstall.keep_only(folder, folder.path_join("c-full.nupkg"))
	var left: Array = Array(DirAccess.get_files_at(folder))
	left.sort()
	assert_eq(left, ["c-full.nupkg", "notas.txt"])
	for file: String in left:
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


func test_sha256_of_a_file() -> void:
	var path: String = "user://test_updater_hash.bin"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("velvet")
	file.close()
	assert_eq(
		VelopackInstall.sha256(path),
		"f4c44266a2dfad9847930615218f2811c5ee3248c6df3d3921a6d2b8e67c8bf6"
	)
	DirAccess.remove_absolute(path)
