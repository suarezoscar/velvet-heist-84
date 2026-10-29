# FEAT-040 — Crear partida desde el menú

- **Estado**: en curso
- **Diseño**: `n/a — técnica` (decisiones del usuario en el grilling del 2026-10-29)
- **Hito del PoC**: H5 (que un jugador pueda montar una partida con un amigo sin terminal)
- **Rama**: `feat/040-crear-partida`

## Objetivo
El usuario quiso jugar con un amigo y no encontró cómo crear la partida: solo se podía unir, y
el servidor había que arrancarlo a mano con `servidor.bat`/`servidor.sh`, que en las versiones
instaladas quedaba escondido.

## Decisiones
1. «CREAR PARTIDA» arranca el servidor dedicado de siempre (FEAT-014) como otro proceso del
   mismo juego, sin ventana, y conecta al jugador con él.
2. Intenta abrir el puerto en el router con UPnP y lo cierra al acabar; si no puede, lo dice.
3. Enseña la IP pública (la del router, por UPnP) y la de casa, con el puerto y «COPIAR».
4. El servidor se cierra al salir de la sala («CERRAR PARTIDA» o «VOLVER»), al cerrar el juego
   o, si el juego se cae, solo (HostWatch: cuando se desconecta quien la creó, o si nadie se
   conecta en 60 s).
5. Puerto 7777 por defecto, cambiable en el mismo campo.
6. Aviso: «Si Windows pregunta, pulsa Permitir».

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Crear partida arranca el servidor y el jugador se conecta solo | `test_host_launcher.gd` (`test_create_join_and_close_a_real_match`), captura |
| 2 | Si quien la creó se va sin cerrarla, el servidor se cierra solo | Mismo test, tras desconectarse |
| 3 | IP de casa, texto para los amigos y lo que se copia | `test_host_launcher.gd` |
| 4 | UPnP abre el puerto y da la IP pública | Captura del 2026-10-29 con un router real |
| 5 | No queda ningún servidor suelto tras los tests | `pgrep` vacío tras ejecutarlos |

## Contratos
- `HostLauncher` (en la raíz): `start(tree, port)`, `current(tree)`, `close()`, `server_args`,
  `private_ips`; señal `upnp_finished(ok)`; `public_ip`, `local_ips`, `upnp_ok`.
- `HostWatch` (servidor con `--hosted`): `attach_if_requested`, `requested`, `is_local`.
- `HostPanel84` en la sala de espera: `attach`, `close_hosted`, `friends_text`, `copy_text`.

## Riesgos y decisiones abiertas
- `OS.is_process_running` solo sirve con procesos hijos: por eso el servidor no vigila el
  proceso del juego sino la conexión de quien la creó.
- Con CGNAT del proveedor, UPnP abre el puerto del router pero no llega desde internet: eso es
  jugar por internet (H2).
- Si quien la creó vuelve al menú, la partida se cierra para todos.

## Cierre
