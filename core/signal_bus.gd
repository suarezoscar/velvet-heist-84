## @file signal_bus.gd
## Bus global de eventos desacoplado (Autoload) para 'Velvet Heist 84'.
## Permite la comunicación asíncrona entre entidades, sistemas acústicos,
## lógica de juego y la interfaz HUD sin acoplamientos rígidos.
extends Node

# -----------------------------------------------------------------------------
# 1. ACÚSTICA, PROPAGACIÓN DE SONIDO Y HUELLAS 3D
# -----------------------------------------------------------------------------

## Emitida cuando cualquier personaje o sistema genera una vibración sonora en el mundo 3D.
## [param world_position]: Coordenadas 3D donde se originó el impacto o paso.
## [param radius]: Radio máximo de expansión de la onda acústica en metros.
## [param source_team]: Equipo originador (&"thief", &"guard", &"neutral").
signal noise_emitted_3d(world_position: Vector3, radius: float, source_team: StringName)

## Ruido con categoría y emisor; noise_emitted_3d se sigue emitiendo para quien ya lo escucha
signal noise_event_3d(
	world_position: Vector3,
	radius: float,
	source_team: StringName,
	category: StringName,
	emitter: Node
)

## El ladrón ha lanzado una moneda (FEAT-038): sale de [param from], vuela en arco
## [param flight_time] segundos y cae en [param landing], donde suena. Solo la emite quien
## tiene la autoridad (el servidor o la partida sin red).
signal coin_thrown(from: Vector3, landing: Vector3, flight_time: float)

## Emitida al dar un paso sobre superficies que puedan registrar huellas temporales (ej. talco).
## [param world_position]: Posición del pie sobre el plano del suelo.
## [param rotation_y]: Orientación angular en radianes para orientar el Decal de la pisada.
signal footprint_stepped_3d(world_position: Vector3, rotation_y: float)

# -----------------------------------------------------------------------------
# 2. INTERACCIÓN ANALÓGICA CON EL ENTORNO (AÑOS 80)
# -----------------------------------------------------------------------------

## Emitida cuando un teléfono de disco marca una extensión remota para generar una distracción.
## [param target_extension_id]: Número de la extensión llamada (ej. 101, 102, 104).
signal rotary_phone_called(target_extension_id: int)

## Emitida cuando un guardia o ladrón descuelga el auricular de un teléfono que estaba sonando.
signal rotary_phone_answered(extension_id: int)

## Emitida cuando un guardia gira su llave en un reloj de pared mecánico de ronda.
## [param clock_id]: Identificador único del reloj fichado.
## [param guard_peer_id]: ID del jugador de la guardia que realizó el fichaje.
signal time_clock_punched(clock_id: int, guard_peer_id: int)

## Emitida cuando se bloquea o desbloquea una puerta física usando cuñas de madera.
signal door_wedge_changed(door_id: int, is_wedged: bool)

# -----------------------------------------------------------------------------
# 3. ESTADO DEL GOLPE, SIGILO Y CONDICIONES DE VICTORIA
# -----------------------------------------------------------------------------

## Emitida cuando el ladrón recoge o asegura botín financiero o artístico.
## [param value]: Valor monetario del botín obtenido en dólares ($).
## [param is_masterpiece]: Verdadero si el botín corresponde a la Pieza Maestra del golpe.
signal loot_stolen(value: int, is_masterpiece: bool)

## Emitida cuando un guardia o linterna detecta visualmente al ladrón en línea de visión.
## [param last_known_position]: Última posición confirmada del ladrón en el espacio 3D.
signal thief_spotted(last_known_position: Vector3)

## Emitida cuando un guardia neutraliza con su porra al ladrón, terminando la partida.
## [param guard_peer_id]: ID del guardia que ejecutó la captura con éxito.
signal thief_captured(guard_peer_id: int)
