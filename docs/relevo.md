# Relevo: #116 Fuera los relojes y las rondas

- **Rama**: `feat/116-sin-rondas` · **PR**: sin abrir · **Tarjeta**: En curso
- **Última herramienta**: Claude Code (Opus), 2026-11-04

## Hecho
- Diseño (game-designer) en heist.md R4/R5/R5c/R5d/R7/R11, interaction.md (parte R retirada), stealth.md, vision.md, pillars.md (pilar 5). Números aprobados por el usuario el 2026-11-04.
- Núcleo (Opus): `GuardPatrol` + `GuardPatrolRules` (garita, elegir sala, caminos) sustituye a `RoundPlanner`; GAR con `"guard_post": true`; `GuardSleep` sin `CampingMeter` (sube fuera de la garita, congelado dentro, también la IA); `AlertDirector.alarm_on`; el guardia solo corre con alarma; `GameManager.time_expired_state` → TIME_EXPIRED (ganan los guardias); IA con patrulla libre, café al bostezar y sin oír en la cabezada. Números en guard_sleep.tres y guard_patrol.tres.
- Sonnet/Opus (2026-11-04): fuera relojes y rondas (TimeClock3D, GuardRound, RoundPlanner, RoundRules, RoundSheet84, RoundArrow3D, CampingMeter, time_clock_84 con ficha y generador), GameManager sin faltas, HUD/informe/puntos/briefing/plano sin relojes, nivel sin «clocks», señal `time_clock_punched` fuera (commit propio). Tests: borrados los de rondas, adaptados los demás y nuevos de sueño, patrulla, correr e IA (`test_guard_patrol`, `test_guard_sprint`, `tests/integration/test_ai_patrol`).

## Falta
- `reviewer` y PR (la tarjeta pasa a «En revisión»); revisar docs/gdd (MASTER_GSD, museum_v2.md, gentleman.md, estilo-de-textos.md aún mencionan relojes); borrar este archivo en el último commit.

## Decisiones tomadas
- (usuario) Todas las de #116 y los números de game-designer (Q1-Q7, 2026-11-04), y el pilar 5.
- (agente) Los estados TIME_EXPIRED_BREACH/_DRAW se quedan en el enum (no se reordenan los valores que viajan por red) aunque ya no se usan.

## Revisión
- (Opus) La IA iba en línea recta a la cafetera y se atascaba a 1,54 m: ahora sigue el camino por las puertas (`_follow_path`), se sirve a 1,9 m y detecta atascos también en COFFEE. Test desde el vestíbulo.
- 403/403 tests. Falta: reviewer y PR.

## Preguntas pendientes al usuario
- Ninguna.
