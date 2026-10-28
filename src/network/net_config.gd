## Constantes técnicas de la capa de red (FEAT-014). No son valores de balance:
## fijan frecuencias de replicación, roles del PoC y acciones válidas.
## Las usan NetManager, NetSession, NetServer, NetClient y NetVisibility.
class_name NetConfig
extends RefCounted

## Frecuencia de los snapshots de actores remotos (20 Hz, FEAT-002)
const REMOTE_SNAPSHOT_HZ: float = 20.0

## Estado propio en cada tick de física (60 Hz): sin predicción en el PoC
const OWN_STATE_EVERY_TICK: bool = true

## Retardo de interpolación de los actores remotos en el cliente (segundos)
const INTERP_DELAY: float = 0.1

## Snapshots guardados por actor remoto para interpolar
const INTERP_BUFFER: int = 8

## Frecuencia del estado del mundo; solo se envían los cambios (10 Hz)
const WORLD_STATE_HZ: float = 10.0

## Frecuencia del reloj de partida dentro del estado de GameManager (1 Hz)
const GAME_TIMER_HZ: float = 1.0

## Distancia horizontal máxima de un look_target respecto al actor (metros)
const MAX_LOOK_DISTANCE: float = 30.0

## Roles del PoC: un ladrón y hasta tres guardias (FEAT-022)
const ROLES: Array[StringName] = [&"thief", &"guard_1", &"guard_2", &"guard_3"]

## Acciones discretas que un cliente puede pedir al servidor
const ACTIONS: Array[StringName] = [
	&"interact",
	&"toggle_flashlight",
	&"strike",
	&"crouch_toggle",
	&"dial_left",
	&"dial_right",
	&"dial_cancel",
	&"force",
	&"throw_coin",
	&"walkie",
	&"alarm_lights",
]


## Puerto de `--port <n>` en los argumentos de la línea de órdenes, o default_port
static func cli_port(args: PackedStringArray, default_port: int) -> int:
	var port: int = default_port
	for i: int in range(args.size()):
		if args[i] == "--port" and i + 1 < args.size():
			port = args[i + 1].to_int()
	return port
