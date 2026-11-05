# Relevo — #123 Puntos de guardias y ladrón

- **Tarea**: #123 (rama `feat/123-puntos`). Diseño aprobado por el usuario el 2026-11-05 (`heist.md` R4b, R11 y «Puntos (#123)»).
- **Hecho**: `score_rules` con bolsas y puntos nuevos; `MatchScore` (individual, equipo con √G, en vivo sin lo oculto); `ScoreEvents` (despistes, walkie, falsificaciones, robos cerca); `AlertDirector.alarm_by/alarm_sight/trace_by`; `LiveScore` por rol (estado privado); tests en `test_partial_escape_score`, `test_score_events`.
- **Falta**: HUD en vivo (`ScoreHud84`) e informe (Sonnet), enseñar el HUD al usuario, `reviewer` (red y reglas), suite completa, PR.
- **Decisiones**: «Rejas saboteadas» también es oculta en vivo (si bajara, delataría una reparación lejana).
- **Preguntas pendientes**: ninguna.
