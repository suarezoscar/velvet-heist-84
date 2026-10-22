# Autoridad del servidor y visibilidad

## Autoridad
- La autoridad de simulación de todos los actores es el servidor (peer 1). El peer del jugador solo es dueño de su **input**.
- Patrón por actor:
  - `PlayerInput` (Node, autoridad = peer del jugador): recoge input en el cliente y lo envía con un RPC `unreliable_ordered` a 60 Hz con un número de tick.
  - Simulación (`PlayerBase3D`, autoridad = servidor): aplica el input recibido con `apply_world_move()` o equivalente; es el mismo código que mueve a la IA.
  - Presentación (`Visuals`): interpola en los clientes; en el servidor headless se desactiva.
- Cada RPC que llega del cliente valida `multiplayer.get_remote_sender_id()` contra el dueño del actor y comprueba el rango de cada valor (dirección normalizada, postura válida, distancia de interacción).
- El estado crítico (botín, capturas, cuota, reloj) solo se escribe en el servidor y se anuncia por RPC fiable (`@rpc("authority", "call_local", "reliable")`).

## MultiplayerSynchronizer
- Hijo directo del nodo que replica. Propiedades continuas (posición, velocidad) en modo "Always" con `replication_interval` (0,05 s = 20 Hz); las que cambian poco (postura, botín cargado) en "On Change" con `delta_interval`.
- La autoridad del sincronizador es la del nodo: con servidor autoritativo, peer 1.
- Visibilidad: un peer recibe datos si su visibilidad (por defecto `public_visibility`, o la fijada con `set_visibility_for(peer, bool)`) es verdadera y todos los filtros de `add_visibility_filter(callable)` devuelven `true`. Los filtros se reevalúan con `update_visibility()` o según `visibility_update_mode`.
- Verificar en Godot 4.7 con un test: cuando la escena la instancia un `MultiplayerSpawner`, la visibilidad del sincronizador raíz decide también si el nodo existe en ese peer (aparece y desaparece).

## El ladrón
- El servidor calcula cada tick de física qué guardias perciben al ladrón (proximidad 1,8 m sin muros, conos de luz con `RayCast3D`, reglas futuras del disfraz) y lo guarda como conjunto de peers.
- Filtro del sincronizador del ladrón: visible para su propio peer, para el servidor y para los peers de guardias del conjunto. Un cambio en el conjunto llama a `update_visibility(peer)`.
- Un guardia que no lo percibe no recibe ni su posición ni su existencia: un cliente modificado no puede dibujarlo.
- Las señales y RPC que delatan posición (ruido, huellas) se envían a todos, porque son información de diseño (pilar 2); su contenido es solo lo que el diseño permite saber (punto y radio del ruido, no la identidad).

## El disfraz (pendiente de `docs/gdd/systems/disguise.md`)
Cuando el ladrón está disfrazado y un guardia lo ve, ese guardia debe recibir algo indistinguible de un guardia. Puntos que la spec de red tiene que resolver:
- Fugas de identidad: nombre del nodo, escena instanciada, equipo, propiedades exclusivas del ladrón, ID de peer. Cualquiera de ellas en el cliente del guardia rompe el disfraz para un cliente modificado.
- Opción a valorar: un actor "disfrazado" separado que el servidor crea solo para los peers de guardias y que replica la posición del ladrón, frente a replicar el ladrón con una propiedad de apariencia. La primera evita fugas por construcción.
- Qué rompe el disfraz (según el diseño) y cómo se notifica: RPC fiable del servidor a los guardias afectados.
