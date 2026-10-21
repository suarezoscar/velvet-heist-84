---
trigger: model_decision
description: "Aplicar al trabajar con multijugador: ENetMultiplayerPeer, RPC, MultiplayerSpawner, MultiplayerSynchronizer, lobby, autoridad o replicación de estado."
---
# Red (multijugador)

- No implementar red sin una FEAT de red aprobada (ver `docs/tasks/FEAT-002-net-readiness.md`).
- Modelo: servidor autoritativo. Los clientes envían input o intención; el servidor valida y simula. El estado crítico (botín, capturas, cuota, reloj de partida) solo lo escribe el servidor.
- Separar en cada entidad input, simulación y presentación, para que la simulación pueda ejecutarse en el servidor sin presentación.
- Visibilidad del ladrón: la decide el servidor. Si la FEAT decide proteger contra clientes modificados, no se replica su posición a los guardias que no lo ven (filtros de visibilidad de `MultiplayerSynchronizer`). Un `visible = false` en el cliente no es protección.
- RPC siempre tipados, con `@rpc` y modo explícito, y validando quién llama (`multiplayer.get_remote_sender_id()`).
- La frecuencia de replicación de cada propiedad se documenta en la spec. La interpolación vive solo en la presentación.
- Probar con 2 o más instancias locales antes de dar una tarea por hecha.
