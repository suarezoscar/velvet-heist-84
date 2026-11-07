# Relevo — #189 replanteamiento visual (minimalismo noir)

**Hecho**
- Mandos de prototipo en los shaders: `pattern_strength` en `museum_wall` y `museum_floor`, y `line_min_height` en `fog_of_war`. Con sus valores por defecto no cambian nada.
- Prototipo de las direcciones A (minimalismo noir), B (lo actual calmado) y C (holograma) con luz suave: band_softness 0,15, shadow_blur 3, luna fría y claraboyas en VES, GW, GSW, ANT, PAT y ORI. Se aplica desde una prueba de capturas, guardada en `docs/proto_189_capturas.gd.txt`.
- Página de comparación: https://claude.ai/artifact/Umca8VKVR1Wi8wiLtwVK5d

**Falta**
- Que el usuario elija la dirección.
- Después: llevar los valores a los `.tres`; claraboyas de verdad (más fuertes y rectangulares); subir la lámpara de retratos; la regla de jerarquía en `art_style.md`; actualizar `vision.md`; tests.

**Contexto**
- Rama hecha sobre `feat/186-niebla-noir` (PR #188, en pausa).
