# FEAT-025 — Aviso de versión distinta al conectar

- **Estado**: hecha
- **Diseño**: `n/a — técnica`. El usuario eligió esta opción el 2026-10-28, ahora que cada integración en master publica una versión.
- **Hito del PoC**: H5
- **Rama**: `feat/025-version-check`

## Objetivo
Que nadie juegue con una versión distinta a la del servidor, porque eso da desincronías raras, y que sepa qué versión tiene que descargar.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Con la misma versión, el lobby dice «Conectado (servidor vX). Elige bando.» | `test_version_check.gd` y prueba en local (`same`) |
| 2 | Con otra versión, el servidor rechaza al jugador y lo desconecta, y el lobby dice en ámbar las dos versiones y dónde descargar la buena. El texto sigue a la vista tras la desconexión | `test_version_check.gd` y prueba con servidor exportado `0.1.0-dev+dc13689` y cliente `0.1.0` (`diff`, captura) |
| 3 | Un cliente que no manda su versión (anterior a esta comprobación) queda fuera a los 5 s | `test_silent_peer_times_out` y prueba con el envío desactivado (`old`): `[NetVersion] Peer … sin versión … fuera` |
| 4 | Hasta que el servidor acepta su versión, un jugador no tiene bando, y el servidor ignora sus peticiones de bando y de empezar | `test_side_only_after_version_is_accepted` y prueba con un cliente sin versión que pide bando y empezar: ni bando ni partida |

## Contratos
- Autoload `NetVersion` (`src/network/net_version_check.gd`, clase `NetVersionNode`), en su propio commit de `project.godot`:
  - señales `accepted(server_version)` y `rejected(server_version, own_version)`;
  - `rejection`, `compatible(a, b)`, `mismatch_text(server, own)` y `check_peer(peer, version)`.
- RPC: `_server_hello(version)` (cliente → servidor, fiable); `_client_accepted(version)` y `_client_rejected(version)` (servidor → cliente, fiables).
- `is_verified(peer)`. NetManager no da bando al conectar: lo da `NetVersion` al aceptar la versión, y `_request_role_server` y `_request_start_server` ignoran a quien no está verificado.
- **Contrato congelado**: los tres RPC de `NetVersion` no cambian nunca de nombre ni de parámetros, y no se añaden otros a ese nodo, porque tiene que entenderse entre versiones distintas.
- Compatible = versión idéntica. Una compilación local (`-dev+commit`) solo juega con otra igual.

## Riesgos y decisiones abiertas
- Las versiones anteriores a esta no muestran el motivo, solo «Se perdió la conexión».

## Cierre
2026-10-28. La revisión del PR #77 encontró que un jugador sin verificar, o ya rechazado, podía pedir bando y lanzar la partida antes de que lo echaran. Ahora el bando llega al aceptar la versión y se ignoran sus peticiones.

Backlog: el mapa no reacciona si el servidor se cae o te echa a media partida (te quedas en el mapa). Un cliente nuevo contra un servidor anterior a la 0.1.3 no recibe ningún aviso.
