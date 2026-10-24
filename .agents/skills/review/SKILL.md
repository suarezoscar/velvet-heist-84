---
name: review
description: Revisión independiente de un cambio (código GDScript, escenas, shaders, scripts de Blender o assets) contra su spec FEAT y las reglas del proyecto. Úsala antes de integrar una rama con riesgo o cuando el usuario pida revisar, auditar o validar un cambio.
---
# /review — revisión independiente

Quien escribió el cambio no lo revisa. En Claude Code la ejecuta el subagente `reviewer`, con contexto limpio.

## Pasos
1. Lee `AGENTS.md`, la FEAT del cambio y el diff de la rama contra su base (`git diff master...HEAD`).
2. Ejecuta las comprobaciones de la regla 05 en el worktree de la rama y copia su salida. La evidencia del ejecutor no cuenta hasta que la reproduces.
3. Recorre la lista de comprobación y anota cada hallazgo con `archivo:línea`.

## Lista de comprobación
- **Spec**: cada criterio de aceptación tiene su evidencia y el código hace lo que dice el criterio, con los valores y contratos de la spec; nada fuera del alcance.
- **Cobertura**: tabla `Criterio → Test(s) → Estado (✅ / ❌ sin test / ⚠️ test débil)`. Un criterio sin test que lo demuestre es bloqueante.
- **Alcance y propiedad**: `check_scope.py` en verde; cada excepción de propiedad está justificada en la spec.
- **Arquitectura** (regla 01): tipado estático, scripts de una responsabilidad y ≤ 300 líneas, señales por `SignalBus`, números leídos de `.tres`.
- **Entidades**: `CollisionShape3D` directo; `Visuals`, `Sensors` y `Components` bien usados.
- **Assets** (regla 02): medidas, pivote, materiales, `-col`, validación en `pass` y bloque `source`.
- **Red** (regla 03) si aplica: autoridad del servidor, RPC validados, filtrado de visibilidad.
- **Diseño**: si la FEAT cambia el diseño, el documento de `docs/gdd/systems/` está actualizado.
- **Riesgos**: regresiones en sistemas existentes (ruido, visibilidad, peso del botín, captura).

## Salida
Veredicto: `aprobado` o `cambios requeridos`. Después, bloqueantes y sugerencias por separado, cada uno con su referencia. Los bloqueantes se redactan como instrucciones que el ejecutor pueda aplicar sin interpretar.
