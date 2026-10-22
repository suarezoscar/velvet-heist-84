# FEAT-002 — Preparación para red (antes del lobby LAN/Online)

- **Estado**: hecha parcialmente (auditoría de la Fase 1, 2026-10-22: `docs/decisions/2026-10-22-fase-1-auditoria.md`)
- **Responsable**: gameplay-engineer  **Revisor**: lead-architect
- **Fase del GSD**: 2 (pendiente: lobby con ENetMultiplayerPeer)

## Objetivo
Dejar las entidades y los sistemas listos para multijugador online/LAN antes de implementar el lobby, desacoplando input, simulación y presentación en `PlayerBase3D` y controladores, evitando dependencias de viewport o cámara en el servidor y blindando la autoridad de los datos críticos.

## Alcance y fuera de alcance
- Dentro: modelo de autoridad autoritativo; separar input, simulación y presentación en `PlayerBase3D` y controladores (`ThiefController3D`, `GuardController3D`); tabla de replicación formal; visibilidad del ladrón filtrada por servidor; tests de simulación desacoplada.
- Fuera: interfaz gráfica del lobby de emparejamiento y `MultiplayerSpawner` en escena de mapa (se implementan en FEAT-003).

## Decisiones arquitectónicas (aprobadas por el usuario el 2026-10-22)
1. **Topología de red**: **Servidor Autoritativo Híbrido** (diseñado primariamente para **Servidor Dedicado Headless** en VPS/cloud para juego online directo sin bloqueo por NAT de routers residenciales, con soporte alternativo de **Host/Listen Server** con UPnP). La lógica de simulación corre 100% idéntica en ambos.
2. **Visibilidad y filtrado del ladrón**: **Servidor Autoritativo con Filtrado de Replicación (Fog-of-War)**. El servidor evalúa la línea de visión (proximidad 1.8 m, `SpotLight3D` y oclusión de muros por `RayCast3D`). Si el ladrón no es visible para los guardias, el servidor **no envía su posición** a los peers de los guardias, imposibilitando hacks de memoria o radar en clientes externos.
3. **Frecuencias de sincronización**:
   - Posición y velocidad física de actores: **20 Hz** (cada 50 ms) con interpolación de presentación continua en el cliente a 60 FPS.
   - Rotación y ángulo de la linterna: **15 Hz**.
   - Eventos discretos de juego (recoger botín, golpear con porra, fichar reloj, alarmas): **RPC Fiable (Reliable)** en el tick en que ocurren.
4. **Manejo de latencia**:
   - **Predicción del lado del cliente (Client-side prediction)** para el actor local: el cliente ejecuta inmediatamente su movimiento en local para respuesta fluida a 60 FPS sin input lag perceptible. El servidor ejecuta la simulación canónica y reconcilia si hay discrepancia física.
   - **Interpolación en presentación** con buffer para los actores remotos.

## Tabla de replicación y autoridad
| Entidad / Estado | Quién escribe (Autoridad) | Canal / Modo | Frecuencia | Notas de Seguridad |
|---|---|---|:---:|---|
| Input del jugador (ejes, sprint, sneak) | Cliente local | RPC Unreliable / Input buffer | 60 Hz | Solo se transmite intención, nunca coordenadas directas |
| Posición y velocidad de `PlayerBase3D` | Servidor (simula) | MultiplayerSynchronizer / Snapshot | 20 Hz | Clientes interpolan presentación |
| Rotación horizontal y ángulo linterna | Servidor (valida y simula) | MultiplayerSynchronizer | 15 Hz | Unreliable Ordered |
| Visibilidad del ladrón hacia guardias | Servidor exclusivamente | MultiplayerSynchronizer (Visibility Filter) | 20 Hz / Cambio | Coordenadas ocultas a clientes de guardias si no está detectado |
| Estado de botín (cargando, valor, dueño) | Servidor exclusivamente | RPC Reliable / Propiedad sincronizada | Al cambiar | Clientes solo envían `request_interact(loot_id)` |
| Impactos de porra y captura | Servidor exclusivamente | RPC Reliable (`validate_melee_hit`) | Al impactar | El servidor valida distancia <= 1.6m y línea de visión |
| Reloj de ronda (tiempo restante, alarma) | Servidor exclusivamente | Sincronización continua / RPC alarma | 1 Hz / Evento | Solo guardias pueden reiniciar el temporizador |
| Cuota de partida y condición de victoria | Servidor exclusivamente | RPC Reliable (`game_ended`) | Al cambiar | `GameManager` autoritativo |

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Las 4 decisiones de arquitectura y la tabla de replicación documentadas en esta spec | este archivo |
| 2 | `PlayerBase3D` refactorizado separando claramente `gather_input()`, `simulate_movement(delta)` y `update_presentation(delta)` | código fuente de `player_base_3d.gd` |
| 3 | La simulación de `PlayerBase3D` y controladores se puede ejecutar en servidor headless sin `Camera3D` ni `get_viewport().get_mouse_position()` | test unitario en headless |
| 4 | Los controladores de guardia y ladrón delegan el estado autoritativo (botín, hits de porra, reloj) en comprobaciones de servidor | test de simulación autoritativa |
| 5 | Todos los tests de caracterización de FEAT-000 y FEAT-001 continúan pasando al 100% en verde | salida de `./tools/ci/run_tests.sh` |
| 6 | Test específico de separación de capas de red en `tests/unit/test_net_readiness.gd` | test en verde con GUT |

## Contratos
- `PlayerBase3D`:
  - `gather_input() -> Dictionary`: captura input del dispositivo local (vector de movimiento, banderas sprint/sneak, punto objetivo en el mundo).
  - `apply_input(input_data: Dictionary) -> void`: aplica datos de entrada validados para la simulación.
  - `simulate_movement(delta: float) -> void`: ejecuta cálculo físico (`move_and_slide()`, gravedad, fricción, cadencia de pasos) sin tocar nodos de presentación ni viewport.
  - `update_presentation(delta: float) -> void`: rota mallas visuales, interpola transformaciones y reproduce animaciones.

## Impacto en red
Prepara la arquitectura de red y el servidor autoritativo para FEAT-003 (Lobby LAN/Online).

## Reparto y orden
1. lead-architect redacta y aprueba la spec y contratos (completado).
2. gameplay-engineer refactoriza `PlayerBase3D` y controladores, añade `tests/unit/test_net_readiness.gd`.
3. lead-architect revisa con `/review` y verifica que los 35 tests previos más los nuevos pasen sin regresiones.
