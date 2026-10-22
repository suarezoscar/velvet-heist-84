# Servidor dedicado

El proyecto ya arranca servidor con `godot --headless -- --server --port 7777` (FEAT-003). Para el servidor de producción:

## Exportación
- Preset Linux con **Export Mode: Export as dedicated server**: añade la feature `dedicated_server`, arranca sin display ni audio aunque falte `--headless` y exporta los recursos visuales como marcadores (se pueden marcar carpetas como **Keep**).
- Excluir del PCK del servidor lo que solo usa el cliente (audio, escenas de UI).
- Godot 4 no tiene plantilla de servidor aparte: el binario es el normal; lo que cambia es el PCK y la feature.

## Arranque
- En el arranque: `if OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless"` → `RenderingServer.set_render_loop_enabled(false)` y ruta de servidor; si no, ruta de cliente.
- Los sistemas solo de servidor (IA, puntuación, validación) se desactivan en clientes con `process_mode = PROCESS_MODE_DISABLED`, y los solo de cliente (cámara, HUD, audio, interpolación) en el servidor.
- Argumentos de línea de comandos (`--port`, `--max-players`, `--tick-rate`) leídos antes de que arranquen los demás autoloads; `Engine.physics_ticks_per_second` se fija antes del primer tick.

## Flujo de partida
- Máquina de estados en el servidor: `LOBBY → COUNTDOWN → IN_GAME → RESULTS`. Los clientes solo reciben los cambios por RPC.
- El lobby es un diccionario por `peer_id` en el servidor, con límite de jugadores y confirmación de "listo".

## Comprobación
- [ ] Preset de servidor dedicado creado y probado.
- [ ] El servidor no renderiza ni reproduce audio.
- [ ] Nodos de servidor y de cliente separados por `process_mode`.
- [ ] Argumentos de arranque leídos antes del resto de autoloads.
- [ ] Estado del lobby y de la partida solo en el servidor.
- [ ] Despliegue (cuando toque): systemd o Docker con reinicio automático y logs en el journal; puerto UDP abierto en el cortafuegos.
