# Relevo: #116 Fuera los relojes y las rondas

- **Rama**: `feat/116-sin-rondas` · **PR**: sin abrir · **Tarjeta**: En curso
- **Última herramienta**: Claude Code (Opus), 2026-11-04

## Hecho
- Diseño (game-designer) en heist.md R4/R5/R5c/R5d/R7/R11, interaction.md (parte R retirada), stealth.md, vision.md, pillars.md (pilar 5). Números aprobados por el usuario el 2026-11-04.
- Núcleo (Opus): `GuardPatrol` + `GuardPatrolRules` (garita, elegir sala, caminos) sustituye a `RoundPlanner`; GAR con `"guard_post": true`; `GuardSleep` sin `CampingMeter` (sube fuera de la garita, congelado dentro, también la IA); `AlertDirector.alarm_on`; el guardia solo corre con alarma; `GameManager.time_expired_state` → TIME_EXPIRED (ganan los guardias); IA con patrulla libre, café al bostezar y sin oír en la cabezada. Números en guard_sleep.tres y guard_patrol.tres.

## Falta
- Quitar relojes y rondas (paquetes a y e del diseño): TimeClock3D, src/systems/rounds/, RoundRules, time_clock_rules, RoundSheet84, RoundArrow3D, relojes del nivel y del constructor, GameManager (round_faults, _rounds, CLOCK_RULES), informe y puntos (guard_clock, guard_fault), SignalBus (commit propio), HUD, mapa, briefing; CampingMeter; tests.
- Tests nuevos del sueño, la patrulla, la IA y el final por tiempo. Verificación completa, reviewer y PR.

## Decisiones tomadas
- (usuario) Todas las de #116 y los números de game-designer (Q1-Q7, 2026-11-04), y el pilar 5.
- (agente) Los estados TIME_EXPIRED_BREACH/_DRAW se quedan en el enum (no se reordenan los valores que viajan por red) aunque ya no se usan.

## Preguntas pendientes al usuario
- Ninguna.
