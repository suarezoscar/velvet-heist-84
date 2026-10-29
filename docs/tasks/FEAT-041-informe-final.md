# FEAT-041 — Informe de la noche y vuelta a la sala

- **Estado**: en curso
- **Diseño**: `docs/gdd/systems/heist.md` R11 (decisiones del usuario en el grilling del 2026-10-29)
- **Hito del PoC**: H5 (playtest en grupo: cerrar cada partida y encadenar la siguiente)
- **Rama**: `feat/041-informe-final`

## Objetivo
El fin de partida era una ventanita sobre el juego, los personajes se seguían moviendo y en
red no se podía volver a la sala para cambiar de bandos (solo revancha o desconectarse).

## Decisiones
1. Pantalla completa, como un expediente: sello 1,5 s, veredicto y ficha por jugador.
2. Al acabar, todos los personajes quietos (también la IA).
3. Datos y puntos de heist.md R11; puntos en `score_rules.tres`; «MEJOR DE LA NOCHE».
4. «VOLVER A LA SALA» lleva a todos, sin desconectar; la sala dice quién la pidió.
5. Acciones: REVANCHA, VOLVER A LA SALA (solo con red) y SALIR. Sin red, REVANCHA y SALIR.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Cómo se robó cada pieza | `test_match_report.gd` (`test_how_each_piece_was_stolen`) |
| 2 | La cuenta de la partida (piezas, alarmas, veces visto sin repetir, cabezadas) | `test_recorder_counts_the_match`, `test_alarms_count_each_trigger_once` |
| 3 | Puntos con desglose y mejor de la noche | `test_points_with_breakdown`, `test_best_of_the_night` |
| 4 | Nadie se mueve con la partida acabada | `test_nobody_moves_once_the_match_is_over` |
| 5 | El informe ocupa la pantalla: sello y después fichas | `test_report_screen_stamp_then_cards`, capturas |
| 6 | Volver a la sala: solo al acabar, desde quien tiene bando, sin desconectar, cancela la revancha | `test_rematch_controls.gd` (`test_back_to_lobby_takes_everyone_without_disconnecting`); prueba de red de la revisión (servidor y dos clientes, dos rondas) |

## Contratos
- `MatchRecorder` (props, grupo `net_state`): `report`, `track(key, seeing, nodding, now)`,
  `build_report()`, `HITS_META`, `CAPTURE_META`. El informe solo viaja al acabar.
- `HeistDirector.stolen_how`, `TargetPiece3D.steal_method`, `AlertDirector.alarm_triggers`,
  `GuardRound.punched`.
- `ScoreRules` / `score_rules.tres`; `MatchScore.thief`, `guard`, `best`.
- `NetRematch.back_to_lobby()` / `return_to_lobby(peer)` y RPC `_server_lobby`, `_client_lobby`.
- `MenuReturn.to_lobby(tree, message)`.
- `MatchReport84` (CanvasLayer 60) con `MatchReportCard84` y `MatchEndMenu84`.

## Riesgos y decisiones abiertas
- «Alarmas» cuenta lo que hace saltar la alarma (una situación seguida, una vez, con el reloj
  de física), porque el nivel de alerta nunca baja. Los rastros cuentan una vez, al llegar al
  umbral.
- El informe llega a los clientes con el estado del final: puede tardar un instante (se ve
  «Recogiendo el informe…»).
- Los puntos son una primera propuesta: se ajustan con `/balance` tras el playtest.

## Cierre
