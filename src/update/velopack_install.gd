## @file velopack_install.gd
## La instalación de Velopack del juego (FEAT-036): dónde está el programa Update, dónde guarda
## los paquetes, de dónde se bajan el índice y los paquetes y cómo avisa Velopack al juego.
## Windows: %LocalAppData%\VelvetHeist84\{Update.exe, current\, packages\}. Linux: el AppImage
## lleva $APPDIR/usr/bin/UpdateNix y los paquetes van en /var/tmp/velopack/<id>/packages.
class_name VelopackInstall
extends RefCounted

## Releases de GitHub: el índice va en la última; cada paquete, en la release de su versión
const REPOSITORY: String = "https://github.com/suarezoscar/velvet-heist-84"
const LATEST_URL: String = REPOSITORY + "/releases/latest/download/"
const VERSION_URL: String = REPOSITORY + "/releases/download/v%s/%s"
const PACKAGE_ID: String = "VelvetHeist84"


## Canal de Velopack del sistema: «win» o «linux»
static func channel() -> String:
	return "win" if OS.get_name() == "Windows" else "linux"


## Dirección del índice; con VELVET_UPDATE_URL (pruebas) todo sale de esa carpeta
static func feed_url() -> String:
	var custom: String = OS.get_environment("VELVET_UPDATE_URL")
	var base: String = custom if not custom.is_empty() else LATEST_URL
	return base + "releases.%s.json" % channel()


## Dirección de un paquete del índice (ya validado por UpdatePlan)
static func package_url(item: Dictionary) -> String:
	var custom: String = OS.get_environment("VELVET_UPDATE_URL")
	if not custom.is_empty():
		return custom + String(item["FileName"])
	return VERSION_URL % [String(item["Version"]), String(item["FileName"])]


## true si Velopack ha lanzado el juego para avisarle (instalar, actualizar…): hay que cerrar
## en el acto, sin abrir nada
static func is_hook(args: PackedStringArray = OS.get_cmdline_args()) -> bool:
	for arg: String in args:
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


## Carpeta de paquetes de Velopack: junto a Update.exe en Windows; en Linux, la del AppImage
static func packages_dir() -> String:
	if OS.get_name() == "Windows":
		return update_program().get_base_dir().path_join("packages")
	return "/var/tmp/velopack/%s/packages" % PACKAGE_ID


## Paquete completo de una versión dentro de packages/
static func full_package(version: String) -> String:
	var suffix: String = "" if channel() == "win" else "-" + channel()
	return packages_dir().path_join("%s-%s%s-full.nupkg" % [PACKAGE_ID, version, suffix])


## Borra de folder los paquetes (.nupkg) que no sean keep ("" los borra todos)
static func keep_only(folder: String, keep: String) -> void:
	for file: String in DirAccess.get_files_at(folder):
		var path: String = folder.path_join(file)
		if path != keep and file.ends_with(".nupkg"):
			DirAccess.remove_absolute(path)


## Lanza Update para que instale package cuando el juego (wait_pid) se cierre y lo reabra.
## En Windows, Update no puede mover current/ si es su carpeta de trabajo, que heredaría del
## juego: se lanza con cmd desde la carpeta de la instalación. La carpeta va en una variable
## de entorno que cmd expande con «!» después de leer la orden, así que nada de la ruta se
## interpreta; el paquete va relativo (su nombre ya está validado por UpdatePlan)
static func start_apply(package: String, wait_pid: int) -> bool:
	var program: String = update_program()
	if program.is_empty():
		return false
	if OS.get_name() != "Windows":
		var args: Array[String] = ["apply", "--package", package, "--waitPid", str(wait_pid)]
		return OS.create_process(program, args) > 0
	OS.set_environment("VELVET_UPDATE_DIR", program.get_base_dir().replace("/", "\\"))
	var line: String = (
		"cd /d !VELVET_UPDATE_DIR! && Update.exe apply --package packages\\%s --waitPid %d"
		% [package.get_file(), wait_pid]
	)
	return OS.create_process("cmd.exe", ["/v:on", "/c", line]) > 0


## SHA256 de un archivo en hexadecimal ("" si no se puede leer)
static func sha256(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		hashing.update(file.get_buffer(1 << 20))
	return hashing.finish().hex_encode()
