# FEAT-002 — Preparación para red (antes del lobby LAN)

- **Estado**: borrador con decisiones abiertas (requiere al usuario)
- **Responsable**: gameplay-engineer  **Revisor**: lead-architect
- **Fase del GSD**: 2 (pendiente: lobby LAN con ENetMultiplayerPeer)

## Objetivo
Dejar las entidades y los sistemas listos para multijugador antes de implementar el lobby, evitando reescribir la lógica local ya hecha.

## Alcance y fuera de alcance
- Dentro: modelo de autoridad; separar input, simulación y presentación en `PlayerBase3D` y controladores; definir qué se replica; spec de visibilidad del ladrón.
- Fuera: el lobby y los spawners (se hacen en una FEAT posterior con esta spec aprobada).

## Decisiones abiertas (las resuelve el usuario)
1. **Topología**: host como servidor autoritativo (LAN) o servidor dedicado.
2. **Visibilidad del ladrón**: ¿importa la protección contra clientes modificados? Si sí, el servidor decide la visibilidad y no replica la posición a los guardias que no lo ven. Si no, basta `visible = false` en el cliente.
3. **Frecuencia de sincronización** de posición y de ángulo de linterna.
4. **Latencia**: solo interpolación en presentación, o también predicción en el cliente del ladrón.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Las 4 decisiones abiertas resueltas y anotadas en este archivo | este archivo |
| 2 | Tabla de replicación completa: propiedad, quién la escribe, frecuencia | tabla en este archivo |
| 3 | `PlayerBase3D` separa input, simulación y presentación sin cambiar el comportamiento local | tests de FEAT-000 en verde |
| 4 | Botín, capturas, cuota y reloj de partida solo se modifican en el servidor | test o revisión de código |
| 5 | Prueba local con 2 instancias: el movimiento se ve sincronizado | captura o log |

## Contratos
Pendientes de las decisiones 1 a 4. Punto de partida para la tabla de replicación: posición y rotación de jugadores, ángulo de linterna, estados (cargando botín, "nervioso", capturado), botín y su dueño, reloj de partida y reloj de ronda.

## Impacto en red
Es la feature de red.

## Reparto y orden
1. lead-architect redacta la tabla de replicación con las decisiones del usuario.
2. gameplay-engineer refactoriza y prueba.
3. lead-architect revisa.

## Riesgos y decisiones abiertas
Refactorizar `PlayerBase3D` puede romper sistemas existentes; FEAT-000 debe estar terminada antes.
