## @file check_scripts.gd
## Compila cada script GDScript recibido dentro del proyecto real, con los autoloads
## registrados. Sustituye a `godot --check-only -s`, que no registra autoloads y daba
## por erróneo cualquier uso tipado de SignalBus, NetManager o GameManager.
## Uso: godot --headless -s res://tools/ci/check_scripts.gd -- res://a.gd res://b.gd
extends SceneTree


func _process(_delta: float) -> bool:
	var failed: int = 0
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	for path: String in paths:
		var script: Script = (
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
		)
		# Un GDScript que no compila carga como null o como script no instanciable
		if script == null or not script.can_instantiate():
			printerr("FAIL: %s" % path)
			failed += 1
	print("==> %d/%d scripts compilados sin errores." % [paths.size() - failed, paths.size()])
	quit(1 if failed > 0 else 0)
	return true
