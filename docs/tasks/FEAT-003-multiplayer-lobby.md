# FEAT-003 — Lobby Online, Servidor Dedicado y Sincronización Multijugador

- **Estado**: aprobada
- **Responsable**: gameplay-engineer y vfx-ui-engineer  **Revisor**: lead-architect
- **Fase del GSD**: 2 (Lobby con ENetMultiplayerPeer y sincronización de red)

## Objetivo
Permitir que un grupo de amigos juegue a Velvet Heist '84 online a través de internet o LAN, ya sea mediante un servidor dedicado headless en la nube/VPS (recomendado para evitar problemas de NAT residencial) o mediante un Host local, con selección de roles asimétricos (1 Ladrón vs 1-3 Guardias) y sincronización de movimiento, linternas y mecánicas de sigilo.

## Alcance y fuera de alcance
- **Dentro**:
  1. `core/net_manager.gd`: Gestor central de red (Autoload) basado en `ENetMultiplayerPeer`.
  2. Soporte CLI para servidor dedicado headless (`godot --headless -- --server --port 7777`).
  3. UI de Lobby multijugador (`scenes/ui/lobby_menu.tscn` o vista integrada en `scenes/ui/main_menu.tscn`):
     - Modo Host (crear sala, puerto).
     - Modo Cliente (dirección IP del servidor, puerto).
     - Asignación de roles asimétricos (1 Ladrón, Guardias 1..3).
     - Indicador de estado de jugadores en la sala y botón de inicio de partida para el host/servidor.
  4. Spawning y asignación de autoridad:
     - Asignación de `multiplayer_authority` por `peer_id`.
     - Control local exclusivo para el peer autorizado; recepción de snapshots para peers remotos.
  5. Sincronización continua de juego:
     - Sincronización de posición y velocidad (20 Hz) con interpolación de presentación.
     - Sincronización de dirección de mirada y cono Maglite (15 Hz).
     - Filtrado de visibilidad del ladrón (el servidor solo replica si el ladrón es detectable).
  6. Sincronización de eventos de partida:
     - Recogida de botín y cuota mediante RPCs autoritativos del servidor.
     - Golpes de porra y captura del ladrón mediante validación en servidor.
     - Sincronización del reloj de fichar analógico de 90s.
  7. Suite de tests unitarios de red con GUT (`tests/unit/test_multiplayer_lobby.gd`).

- **Fuera**:
  - Servidor central de matchmaking con cuentas de usuario (se conecta por IP/Dominio).
  - Chat de voz / VoIP integrado.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | `core/net_manager.gd` implementado con tipado estático, manejo de `ENetMultiplayerPeer`, señales de conexión/desconexión y gestión de roles | código fuente y `--check-only` |
| 2 | Soporte de Servidor Dedicado Headless: al iniciar Godot con el argumento `--server`, `net_manager` inicializa el puerto sin interfaz gráfica ni errores | ejecución de log en headless |
| 3 | Interfaz de Lobby en `scenes/ui/`: permite elegir rol (Ladrón / Guardia), configurar IP/Puerto, conectarse y ver la lista de jugadores conectados | test de UI y captura del menú |
| 4 | Asignación de autoridad: cada peer solo procesa input sobre la entidad que le corresponde según su `peer_id` | test en `tests/unit/test_multiplayer_lobby.gd` |
| 5 | Sincronización de actores a 20 Hz con interpolación en clientes remotos | test de sincronización |
| 6 | Eventos autoritativos de servidor: botín, golpes de porra y reloj de 90s solo se modifican en el servidor y se replican fielmente a los clientes | test unitario en verde |
| 7 | Todos los 46 tests previos de FEAT-000, 001 y 002 continúan pasando al 100% en verde | salida de `./tools/ci/run_tests.sh` |
| 8 | Prueba local automatizada de 2 instancias (Host/Servidor y Cliente) conectadas por loopback `127.0.0.1` | logs de conexión y handshake de roles |

## Contratos
### `core/net_manager.gd`
- **Señales**:
  - `signal server_started()`
  - `signal connection_succeeded()`
  - `signal connection_failed()`
  - `signal server_disconnected()`
  - `signal player_connected(peer_id: int, player_info: Dictionary)`
  - `signal player_disconnected(peer_id: int)`
  - `signal player_list_updated()`
  - `signal match_started()`
- **Métodos públicos**:
  - `start_host(port: int = 7777, max_players: int = 4) -> Error`
  - `join_server(ip: String = "127.0.0.1", port: int = 7777) -> Error`
  - `start_dedicated_server(port: int = 7777) -> Error`
  - `disconnect_network() -> void`
  - `request_role(role: StringName) -> bool`
  - `get_local_role() -> StringName`
  - `is_server_authoritative() -> bool`
  - `get_connected_players() -> Dictionary`

### Diccionario de Jugador (`player_info`)
```gdscript
{
    "peer_id": int,
    "role": StringName, # &"thief", &"guard_1", &"guard_2", &"guard_3"
    "ready": bool,
    "name": String
}
```

## Impacto en red
Esta es la feature medular de red para multijugador online. Define la autoridad del servidor (peer 1 o dedicado) y los canales de comunicación RPC.

## Reparto y orden
1. **lead-architect**:
   - Registrar `core/net_manager.gd` en `project.godot` como Autoload.
   - Revisar la spec y validar la integración con `project.godot`.
2. **gameplay-engineer**:
   - Implementar `core/net_manager.gd`.
   - Adaptar `scenes/maps/museum_velvet_84.gd` para vincular entidades a sus respectivas autoridades por `peer_id`.
   - Crear `tests/unit/test_multiplayer_lobby.gd`.
3. **vfx-ui-engineer**:
   - Diseñar la vista de Lobby en `scenes/ui/main_menu.tscn` (o componente modular `scenes/ui/lobby_view.tscn`) respetando la estética analógica de 1984.
4. **lead-architect**:
   - Revisión independiente con `/review`.

## Riesgos y decisiones abiertas
- En local, dos instancias ejecutadas con la misma configuración de ventana pueden colisionar si no se pasan parámetros de posición o tamaño de ventana distintos; los scripts de prueba en `tools/ci/` deben contemplar `--resolution` o `--position`.
