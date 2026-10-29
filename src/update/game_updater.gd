## @file game_updater.gd
## Actualizaciones del juego con Velopack (FEAT-036). Velopack instala el juego en la carpeta
## del usuario con un programa «Update» al lado y deja en packages/ el paquete completo de la
## versión instalada. Aquí el juego:
## - lee el índice de Velopack de la última release de GitHub (releases.<canal>.json);
## - si hay una versión mayor, elige qué bajar (plan): los paquetes de diferencias desde la
##   versión instalada si están todos, pesan menos y está su paquete completo; si no, el completo;
## - descarga cada paquete y comprueba su SHA256;
## - con diferencias, Update las suma al paquete completo instalado («patch») en otro hilo;
## - deja en packages/ solo el paquete completo nuevo (la base de la siguiente vez);
## - lanza un único «apply», que espera a que el juego se cierre y lo vuelve a abrir.
## Sin instalación de Velopack (el .zip o el .tar.gz) no se actualiza solo.
class_name GameUpdater
extends Node

## Hay una versión mayor publicada
signal update_found(version: String)
## Parte descargada del total, de 0 a 1
signal progress(fraction: float)
## Descargado: Update está montando la versión nueva a partir de las diferencias
signal preparing
## Versión nueva lista para aplicar
signal ready_to_apply
## No se pudo: qué ha pasado, para el jugador (estilo-de-textos.md)
signal failed(reason: String)

## El índice y los paquetes: la última release de GitHub, o VELVET_UPDATE_URL (pruebas)
const REPOSITORY: String = "https://github.com/suarezoscar/velvet-heist-84"
const RELEASES_URL: String = REPOSITORY + "/releases/latest/download/"
const PACKAGE_ID: String = "VelvetHeist84"

## Paquetes que hay que bajar, en orden
var plan: Array[Dictionary] = []
var _request: HTTPRequest = null
var _thread: Thread = null
var _done_bytes: int = 0
var _total_bytes: int = 0
var _index: int = -1
var _paths: Array[String] = []
## El paquete completo de la versión nueva, cuando está listo
var _ready_package: String = ""


static func base_url() -> String:
	var custom: String = OS.get_environment("VELVET_UPDATE_URL")
	return custom if not custom.is_empty() else RELEASES_URL


## Canal de Velopack del sistema: «win» o «linux»
static func channel() -> String:
	return "win" if OS.get_name() == "Windows" else "linux"


## true si Velopack ha lanzado el juego para avisarle (instalar, actualizar…): hay que cerrar
## en el acto, sin abrir nada
static func is_velopack_hook() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--veloapp-"):
			return true
	return false


## El programa Update de Velopack ("" si el juego no se instaló con Velopack)
static func update_program() -> String:
	var path: String = ""
	if OS.get_name() == "Windows":
		path = OS.get_executable_path().get_base_dir().path_join("../Update.exe").simplify_path()
	else:
		var appdir: String = OS.get_environment("APPDIR")
		if not appdir.is_empty():
			path = appdir.path_join("usr/bin/UpdateNix")
	return path if not path.is_empty() and FileAccess.file_exists(path) else ""


## Carpeta de paquetes de Velopack, junto al programa Update
static func packages_dir() -> String:
	return update_program().get_base_dir().path_join("packages")


## Paquete completo de una versión dentro de packages/
static func full_package(version: String) -> String:
	return packages_dir().path_join("%s-%s-full.nupkg" % [PACKAGE_ID, version])


## a > b en versiones «X.Y.Z» (lo que va tras un «-» no cuenta)
static func is_newer(a: String, b: String) -> bool:
	var left: PackedStringArray = a.get_slice("-", 0).split(".")
	var right: PackedStringArray = b.get_slice("-", 0).split(".")
	for index: int in range(maxi(left.size(), right.size())):
		var l: int = int(left[index]) if index < left.size() else 0
		var r: int = int(right[index]) if index < right.size() else 0
		if l != r:
			return l > r
	return false


## Qué bajar para pasar de current a la versión más nueva del índice ([] si ya está al día):
## las diferencias de cada versión intermedia si hay base (el paquete completo de current), si
## están todas y si pesan menos que el completo; si no, solo el paquete completo de la última
static func make_plan(feed: Dictionary, current: String, has_base: bool) -> Array[Dictionary]:
	var fulls: Dictionary = {}
	var deltas: Dictionary = {}
	for entry: Variant in feed.get("Assets", []):
		var item: Dictionary = entry as Dictionary
		var version: String = String(item.get("Version", ""))
		if String(item.get("Type", "")) == "Full":
			fulls[version] = item
		elif String(item.get("Type", "")) == "Delta":
			deltas[version] = item
	var versions: Array = fulls.keys()
	for version: String in deltas:
		if not fulls.has(version):
			versions.append(version)
	versions.sort_custom(func(a: String, b: String) -> bool: return is_newer(b, a))
	var result: Array[Dictionary] = []
	if versions.is_empty() or not fulls.has(versions[-1]) or not is_newer(versions[-1], current):
		return result
	var latest: Dictionary = fulls[versions[-1]]
	var start: int = versions.find(current)
	var chain_size: int = 0
	if has_base and start >= 0:
		for version: String in versions.slice(start + 1):
			if not deltas.has(version):
				result.clear()
				break
			result.append(deltas[version])
			chain_size += int(deltas[version].get("Size", 0))
	if result.is_empty() or chain_size >= int(latest.get("Size", 0)):
		result.assign([latest])
	return result


func _ready() -> void:
	name = "GameUpdater"
	_request = HTTPRequest.new()
	_request.use_threads = true
	add_child(_request)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _process(_delta: float) -> void:
	if _index >= 0 and _total_bytes > 0:
		var now: int = _done_bytes + _request.get_downloaded_bytes()
		progress.emit(clampf(float(now) / float(_total_bytes), 0.0, 1.0))


## Mira si hay una versión nueva (solo si el juego se instaló con Velopack)
func check() -> void:
	if update_program().is_empty():
		return
	_request.request_completed.connect(_on_feed, CONNECT_ONE_SHOT)
	if _request.request(base_url() + "releases.%s.json" % channel()) != OK:
		_request.request_completed.disconnect(_on_feed)


## Descarga los paquetes del plan, uno tras otro, en packages/
func download() -> void:
	if plan.is_empty():
		return
	_paths.clear()
	_ready_package = ""
	_done_bytes = 0
	_total_bytes = 0
	for item: Dictionary in plan:
		_total_bytes += int(item.get("Size", 0))
	_index = -1
	_next_package()


## Deja a Update aplicando la versión nueva en cuanto se cierre el juego (luego lo vuelve a
## abrir) y cierra
func apply() -> void:
	var program: String = update_program()
	if program.is_empty() or _ready_package.is_empty():
		return
	var args: Array[String] = ["apply", "--package", _ready_package]
	args.append_array(["--waitPid", str(OS.get_process_id())])
	if OS.get_name() == "Windows":
		# Update no puede mover current/ si es su carpeta de trabajo, que heredaría del juego:
		# se lanza con cmd desde la carpeta de la instalación. Una sola línea, sin comillas
		# dentro (Godot entrecomilla el argumento entero): cd admite espacios sin comillas y
		# Update y el paquete van relativos a esa carpeta
		var line: String = (
			"cd /d %s && Update.exe apply --package packages\\%s --waitPid %d"
			% [
				program.get_base_dir().replace("/", "\\"),
				_ready_package.get_file(),
				OS.get_process_id()
			]
		)
		args = ["/c", line]
		program = "cmd.exe"
	if OS.create_process(program, args) <= 0:
		failed.emit("No se pudo instalar la versión nueva. Inténtalo más tarde.")
		return
	get_tree().quit()


func _next_package() -> void:
	if _index >= 0:
		_done_bytes += int(plan[_index].get("Size", 0))
	_index += 1
	if _index >= plan.size():
		_index = -1
		_downloaded()
		return
	DirAccess.make_dir_recursive_absolute(packages_dir())
	var path: String = packages_dir().path_join(String(plan[_index]["FileName"]))
	_paths.append(path)
	_request.download_file = path
	_request.request_completed.connect(_on_package, CONNECT_ONE_SHOT)
	if _request.request(base_url() + String(plan[_index]["FileName"])) != OK:
		_request.request_completed.disconnect(_on_package)
		_fail("No se pudo empezar la descarga. Inténtalo de nuevo.")


## Con el paquete completo, listo; con diferencias, Update las suma a la base en otro hilo
func _downloaded() -> void:
	if String(plan[0].get("Type", "")) == "Full":
		_prepared(_paths[0])
		return
	var output: String = full_package(String(plan[-1]["Version"]))
	var args: Array[String] = ["patch", "--old", full_package(GameVersion.current())]
	for path: String in _paths:
		args.append_array(["--delta", path])
	args.append_array(["--output", output])
	preparing.emit()
	_thread = Thread.new()
	_thread.start(_merge.bind(update_program(), args, output))


func _merge(program: String, args: Array[String], output: String) -> void:
	var code: int = OS.execute(program, args)
	_merged.call_deferred(code, output)


func _merged(code: int, output: String) -> void:
	_thread.wait_to_finish()
	if code != 0 or not FileAccess.file_exists(output):
		_fail("No se pudo preparar la versión nueva. Inténtalo de nuevo.")
		return
	_prepared(output)


## Deja en packages/ solo el paquete completo nuevo y avisa de que está listo
func _prepared(package: String) -> void:
	for file: String in DirAccess.get_files_at(packages_dir()):
		var path: String = packages_dir().path_join(file)
		if path != package and file.ends_with(".nupkg"):
			DirAccess.remove_absolute(path)
	_ready_package = package
	ready_to_apply.emit()


func _on_feed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # sin conexión o sin índice: no se dice nada
	var feed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (feed is Dictionary):
		return
	var current: String = GameVersion.current()
	plan = make_plan(feed, current, FileAccess.file_exists(full_package(current)))
	if not plan.is_empty():
		update_found.emit(String(plan[-1]["Version"]))


func _on_package(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_request.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("La descarga se cortó. Inténtalo de nuevo.")
		return
	var expected: String = String(plan[_index].get("SHA256", "")).to_lower()
	if _sha256(_paths[_index]) != expected:
		_fail("La descarga llegó dañada. Inténtalo de nuevo.")
		return
	_next_package()


func _fail(reason: String) -> void:
	_index = -1
	failed.emit(reason)


static func _sha256(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		hashing.update(file.get_buffer(1 << 20))
	return hashing.finish().hex_encode()
