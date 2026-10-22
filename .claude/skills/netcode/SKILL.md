---
name: netcode
description: Referencia de red multijugador de Velvet Heist '84 en Godot 4 (servidor autoritativo, filtrado de visibilidad del ladrón, predicción e interpolación, servidor dedicado). Úsala al escribir o revisar una spec, un paquete o un cambio que toque multijugador.
---
# netcode — referencia de red

Las decisiones de arquitectura aprobadas están en `docs/tasks/FEAT-002-net-readiness.md` y las reglas en `.agents/rules/03-netcode.md`. Esta skill da los patrones para convertirlas en contratos y paquetes cerrados.

## Modelo del proyecto
- Servidor autoritativo (dedicado headless o host). La simulación es idéntica en ambos casos.
- Clientes: envían input o intención por RPC; nunca posiciones.
- Servidor: simula, valida y replica. Posición y velocidad a 20 Hz, mirada y linterna a 15 Hz, eventos discretos por RPC fiable.
- Ladrón: el servidor decide qué guardias lo perciben y solo a ellos les replica su posición.
- Actor local: predicción y reconciliación. Actores remotos: interpolación con búfer.

## Al escribir una spec de red
1. Tabla de replicación: propiedad, quién escribe, canal (sincronizador o RPC, fiable o no), frecuencia y qué peers la reciben.
2. Cada RPC con firma tipada, modo `@rpc` explícito y la validación del emisor.
3. Para cada dato secreto (posición del ladrón, identidad bajo disfraz), qué peers no deben recibirlo nunca y qué test lo demuestra.
4. Separación input / simulación / presentación por entidad, con los nodos que se desactivan en el servidor.
5. Tests: al menos un test de integración con servidor headless y dos clientes en loopback.

## Referencias
- `references/authority-and-visibility.md`: autoridad del servidor y filtros de visibilidad; el ladrón y el disfraz.
- `references/prediction-and-interpolation.md`: predicción del actor local, reconciliación e interpolación de remotos.
- `references/dedicated-server.md`: exportación headless, arranque servidor/cliente y lista de comprobación.

Material adaptado de GodotPrompter (MIT); ver `.claude/skills/THIRD_PARTY_NOTICES.md`.
