## @file game_updater.gd
## Actualizaciones del juego con Velopack (FEAT-036). Velopack instala el juego con un programa
## «Update» al lado y deja en packages/ el paquete completo de la versión instalada (en Linux,
## el AppImage no deja ninguno: la primera vez baja el completo). Aquí el juego:
## - lee el índice de Velopack de la última release de GitHub (releases.<canal>.json);
## - si hay una versión mayor, elige qué bajar (UpdatePlan, que descarta entradas raras);
## - descarga cada paquete y comprueba su SHA256 en otro hilo;
## - con diferencias, Update las suma al paquete completo instalado («patch») en otro hilo; si
##   falla, el siguiente intento baja el completo;
## - deja en packages/ solo el paquete completo nuevo (la base de la siguiente vez);
## - lanza un único «apply» (VelopackInstall.start_apply), que espera a que el juego se cierre
##   y lo vuelve a abrir.
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

## Segundos sin recibir nada antes de dar una descarga por cortada
const STALL_SECONDS: float = 30.0

## Paquetes que hay que bajar, en orden
var plan: Array[Dictionary] = []
var _feed: Dictionary = {}
var _request: HTTPRequest = null
var _thread: Thread = null
var _downloading: bool = false
var _stalled: float = 0.0
var _last_bytes: int = 0
var _done_bytes: int = 0
var _total_bytes: int = 0
var _index: int = -1
var _paths: Array[String] = []
## El paquete completo de la versión nueva, cuando está listo
var _ready_package: String = ""


func _ready() -> void:
	name = "GameUpdater"
	_request = HTTPRequest.new()
	_request.use_threads = true
	add_child(_request)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _process(delta: float) -> void:
	if not _downloading:
		return
	var bytes: int = _request.get_downloaded_bytes()
	_stalled = 0.0 if bytes != _last_bytes else _stalled + delta
	_last_bytes = bytes
	if _total_bytes > 0:
		progress.emit(clampf(float(_done_bytes + bytes) / float(_total_bytes), 0.0, 1.0))
	if _stalled > STALL_SECONDS:
		_request.cancel_request()
		_request.request_completed.disconnect(_on_package)
		_fail("La descarga se cortó. Inténtalo de nuevo.")


## Mira si hay una versión nueva (solo si el juego se instaló con Velopack)
func check() -> void:
	if VelopackInstall.update_program().is_empty():
		return
	_request.request_completed.connect(_on_feed, CONNECT_ONE_SHOT)
	if _request.request(VelopackInstall.feed_url()) != OK:
		_request.request_completed.disconnect(_on_feed)


## Descarga los paquetes del plan, uno tras otro, en packages/
func download() -> void:
	if plan.is_empty() or _downloading or _thread != null:
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
	if _ready_package.is_empty():
		return
	if not VelopackInstall.start_apply(_ready_package, OS.get_process_id()):
		failed.emit("No se pudo instalar la actualización. Inténtalo más tarde.")
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
	var folder: String = VelopackInstall.packages_dir()
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join(String(plan[_index]["FileName"]))
	_paths.append(path)
	_request.download_file = path
	_request.request_completed.connect(_on_package, CONNECT_ONE_SHOT)
	_stalled = 0.0
	_last_bytes = 0
	_downloading = true
	if _request.request(VelopackInstall.package_url(plan[_index])) != OK:
		_request.request_completed.disconnect(_on_package)
		_fail("No se pudo empezar la descarga. Inténtalo de nuevo.")


func _on_package(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_downloading = false
	_request.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("La descarga se cortó. Inténtalo de nuevo.")
		return
	_in_thread(VelopackInstall.sha256.bind(_paths[_index]), _checked)


func _checked(digest: String) -> void:
	_join_thread()
	if digest != String(plan[_index].get("SHA256", "")).to_lower():
		_fail("La descarga llegó dañada. Inténtalo de nuevo.")
		return
	_next_package()


## Con el paquete completo, listo; con diferencias, Update las suma a la base en otro hilo
func _downloaded() -> void:
	if String(plan[0].get("Type", "")) == "Full":
		_prepared(_paths[0])
		return
	var output: String = VelopackInstall.full_package(String(plan[-1]["Version"]))
	var base: String = VelopackInstall.full_package(GameVersion.current())
	var args: Array[String] = ["patch", "--old", base]
	for path: String in _paths:
		args.append_array(["--delta", path])
	args.append_array(["--output", output])
	_paths.append(output)  # si falla, también se borra
	preparing.emit()
	var program: String = VelopackInstall.update_program()
	_in_thread(func() -> int: return OS.execute(program, args), _merged.bind(output))


func _merged(code: int, output: String) -> void:
	_join_thread()
	if code != 0 or not FileAccess.file_exists(output):
		# La base puede estar dañada: el siguiente intento baja el paquete completo
		plan = UpdatePlan.make(_feed, GameVersion.current(), false)
		_fail("No se pudo preparar la actualización. Inténtalo de nuevo.")
		return
	_prepared(output)


## Deja en packages/ solo el paquete completo nuevo y avisa de que está listo
func _prepared(package: String) -> void:
	VelopackInstall.keep_only(VelopackInstall.packages_dir(), package)
	_paths.clear()
	_ready_package = package
	ready_to_apply.emit()


func _on_feed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # sin conexión o sin índice: no se dice nada
	var feed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (feed is Dictionary):
		return
	_feed = feed
	var current: String = GameVersion.current()
	var has_base: bool = FileAccess.file_exists(VelopackInstall.full_package(current))
	plan = UpdatePlan.make(_feed, current, has_base)
	if not plan.is_empty():
		update_found.emit(String(plan[-1]["Version"]))


## Trabajo pesado (SHA256, patch) fuera del hilo principal; done recibe su resultado
func _in_thread(work: Callable, done: Callable) -> void:
	_thread = Thread.new()
	_thread.start(func() -> void: done.call_deferred(work.call()))


func _join_thread() -> void:
	_thread.wait_to_finish()
	_thread = null


## Borra lo descargado a medias y avisa
func _fail(reason: String) -> void:
	_downloading = false
	_index = -1
	for path: String in _paths:
		DirAccess.remove_absolute(path)
	_paths.clear()
	failed.emit(reason)
