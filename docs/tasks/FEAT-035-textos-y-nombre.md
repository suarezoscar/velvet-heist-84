# FEAT-035 — Textos con la guía de estilo y nombre del jugador

- **Estado**: en curso
- **Diseño**: `docs/gdd/estilo-de-textos.md` (aprobada por el usuario el 2026-10-29, sesión de preguntas)
- **Hito del PoC**: H5
- **Rama**: `feat/035-textos`

## Objetivo
Que todo lo que lee el jugador suene a la noche del golpe en 1984, sin tecnicismos ni restos del diseño antiguo, y que cada jugador tenga su nombre: el ladrón firma con su inicial.

## Criterios
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Guía de estilo y regla `06-textos.md` para los agentes; el revisor la comprueba | `docs/gdd/estilo-de-textos.md`, `.agents/rules/06-textos.md`, `.claude/agents/reviewer.md` |
| 2 | Sin «IA», «servidor», scripts ni rutas delante del jugador. Se mantienen la IP y el puerto | Búsqueda en `src/`, `scenes/`, README y web; capturas |
| 3 | Glosario aplicado: piezas en el punto de mira, réplica, circuito cerrado y mesa de monitores, Datos de la conexión, sala de espera, la central | Tests de textos actualizados (`test_museum_expansion`, `test_swap_and_power`, `test_rematch_controls`, `test_version_check`) |
| 4 | Pantallas finales y briefing en la voz de cada bando, con tildes; fuera los restos de botín y policía | `test_gameplay_loop_late`, captura |
| 5 | Nombre: se pregunta la primera vez y se cambia en Opciones; 2-16 caracteres permitidos; firma con la inicial o «—V.» | `test_player_name.gd` |
| 6 | En red, el servidor limpia el nombre y le pone número si se repite («Ana 2»); la firma del ladrón sale de su nombre | `test_player_name.gd::test_repeated_names_get_a_number` y prueba en red (1 ladrón y 1 guardia que se llaman igual) |
| 7 | Pantalla final: «Ladrón: … · Guardias: …» y faltas toleradas por guardia | `test_letter_and_summary_use_the_names` |

## Contratos
- `PlayerName`: `clean()`, `signature()`, `unique()`, `thief_signature(tree)`, `FALLBACK_SIGNATURE`.
- `GameSettings.player_name` y `name_asked` (en `user://settings.cfg`).
- `NetNames` (hijo de NetManager): RPC `_set_name_server(raw)` del cliente al servidor. Cada jugador lleva `name` (para mostrar) y `chosen_name` (para la firma).
- `NamePanel` (primer arranque) y el campo de nombre de las Opciones.

## Riesgos y decisiones abiertas
- El nodo nuevo `NetNames` cambia el contrato de RPC entre versiones; la comprobación de versión ya rechaza las partidas con versiones distintas.
- Arreglado de paso: el panel de fin mostraba como tolerancia las faltas de un solo guardia en vez de las de todo el equipo (venía de FEAT-034).

## Cierre
