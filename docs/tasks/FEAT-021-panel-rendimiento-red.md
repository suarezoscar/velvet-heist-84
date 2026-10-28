# FEAT-021 — Panel de rendimiento y red

- **Estado**: hecha
- **Diseño**: `n/a — técnica`. Lo pidió el usuario el 2026-10-28: «para la partida en red quiero elementos de depuración o calidad, como ver los FPS y la latencia entre jugadores». Eligió además la pérdida de paquetes, el ancho de banda y el tiempo de frame.
- **Hito del PoC**: H5 (prueba por internet)
- **Rama**: `feat/021-panel-red`

## Objetivo
Medir la calidad de una partida en red mientras se juega, para poder hablar con cifras de retraso, tirones o pérdidas en la prueba por internet.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | F9, o la opción «Panel de rendimiento y red» de Opciones (guardada), muestra un panel abajo a la derecha (FEAT-022 lo bajó de arriba, donde tapaba la hoja de ronda) con FPS, ms por frame y ms de proceso y de física | `tests/unit/test_perf_overlay.gd` y captura |
| 2 | Con red muestra el ping y la pérdida propios, los kB/s enviados y recibidos y los snapshots por segundo | test y captura con servidor y 2 clientes |
| 3 | Muestra el ping y la pérdida de cada jugador conectado, con su bando, ordenados por rol. El ping va en verde por debajo de 80 ms, en ámbar hasta 150 ms y en rojo por encima | test y captura |
| 4 | El servidor dedicado escribe cada 10 s una línea `[NetStats]` con el ping y la pérdida de cada jugador | registro del servidor |

## Contratos
- Autoload `NetStats` (`src/network/net_stats.gd`, clase `NetStatsNode`):
  - `peers: Dictionary` (peer_id → `{"rtt": int ms, "loss": float %}`);
  - `sent_kbps`, `received_kbps` y `snapshots_per_second`;
  - `count_snapshot()`, `local_rtt()` y `sorted_peers()`.
- Autoload `PerfOverlay` (`src/ui/debug/perf_overlay_84.gd`, clase `PerfOverlay84`): `set_shown(on)`. No se crea en el servidor dedicado.
- `GameSettings.show_perf`.

| Dato | Quién lo mide | A quién | Frecuencia |
|---|---|---|---|
| Ping y pérdida de cada peer (ENet) | servidor | todos, RPC no fiable | 1 Hz |
| Tráfico propio y snapshots recibidos | cada máquina | nadie | 1 Hz |

## Riesgos y decisiones abiertas
- F9 en lugar de F3: de F1 a F5 cambian de personaje en los builds de depuración.
- El ping es el ida y vuelta de ENet entre cada jugador y el servidor. La latencia entre dos jugadores es, aproximadamente, la suma de sus dos pings más el retardo de interpolación (100 ms).

## Cierre
2026-10-28. Verificado con un servidor dedicado y 2 clientes en local (ping de 13 ms, 20 snap/s y unos 19 kB/s de bajada).
