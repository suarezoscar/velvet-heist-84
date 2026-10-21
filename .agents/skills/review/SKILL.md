---
name: review
description: Revisión independiente de un cambio (código GDScript, escenas, shaders, scripts de Blender o assets) contra su spec FEAT y las reglas del proyecto. Úsala antes de dar por terminada cualquier tarea, al integrar una rama o cuando el usuario pida revisar, auditar o validar un cambio.
---
# /review — revisión independiente

Quien escribió el cambio no lo revisa. Si lo escribiste tú en esta sesión, dilo y pide que lo revise otro subagente (normalmente `lead-architect`, con contexto limpio).

## Pasos
1. Lee `AGENTS.md`, la FEAT del cambio y el diff (`git diff` de la rama contra la base).
2. Comprueba cada punto de la lista siguiente y anota hallazgos con `archivo:línea`.

## Lista de comprobación
- **Spec**: cada criterio de aceptación tiene su evidencia; nada fuera del alcance.
- **Propiedad**: los archivos modificados pertenecen al subagente que los tocó (tabla de `AGENTS.md`).
- **Arquitectura** (`.agents/rules/01`): tipado estático, scripts pequeños con una responsabilidad, sin `get_parent().get_parent()` ni rutas hardcodeadas, señales por `SignalBus`, constantes con nombre.
- **Entidades**: `CollisionShape3D` directo, `Visuals`, `Sensors` y `Components` bien usados; nada espacial bajo `Components`.
- **Assets** (`.agents/rules/02`): medidas, pivote, paleta, `-col`, validación JSON en `pass`; no se escala ni se corrige un `.glb` en Godot.
- **Red** (`.agents/rules/03`) si aplica: autoridad del servidor, RPC validados.
- **Tests y evidencia**: existen, son relevantes y los resultados son reales, no afirmados.
- **Riesgos**: regresiones en sistemas existentes (ruido, visibilidad, peso del botín, captura).

## Salida
Veredicto: `aprobado` o `cambios requeridos`. Después, bloqueantes y sugerencias por separado, cada uno con su referencia.
