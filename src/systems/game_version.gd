## @file game_version.gd
## Versión del juego (FEAT-023): application/config/version de project.godot, que
## tools/build/export.sh graba al compilar (la etiqueta vX.Y.Z en una release, o la base con
## «-dev+<commit>» en una compilación local). Desde el editor se ve la versión base.
class_name GameVersion
extends RefCounted


static func current() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
