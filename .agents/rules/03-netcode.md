---
trigger: model_decision
description: "Aplicar al trabajar con multijugador: ENetMultiplayerPeer, RPC, MultiplayerSpawner, MultiplayerSynchronizer, lobby, autoridad o replicación de estado."
---
# Red (multijugador)

- La red se implementa solo con una FEAT de red aprobada. Las decisiones de arquitectura están en `docs/tasks/FEAT-002-net-readiness.md`. Claude usa la skill `netcode` al escribir o revisar esas specs.
- Modelo: servidor autoritativo. Los clientes envían input o intención; el servidor valida y simula. El estado crítico (botín, capturas, cuota, reloj de partida) solo lo escribe el servidor.
- Separar en cada entidad input, simulación y presentación, para que la simulación pueda ejecutarse en el servidor sin presentación.
- Visibilidad del ladrón: la decide el servidor, que deja de enviar su posición a los guardias que no lo perciben (filtros de visibilidad de `MultiplayerSynchronizer`). Un `visible = false` en el cliente no protege nada. El disfraz de guardia cambiará este filtro: su comportamiento lo fija el documento de diseño `docs/gdd/systems/disguise.md` cuando esté aprobado.
- RPC siempre tipados, con `@rpc` y modo explícito, y validando quién llama (`multiplayer.get_remote_sender_id()`).
- La frecuencia de replicación de cada propiedad se documenta en la spec. La interpolación vive solo en la presentación.
- Probar con 2 o más instancias locales antes de dar una tarea por hecha.
