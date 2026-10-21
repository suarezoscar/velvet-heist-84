---
trigger: model_decision
description: "Aplicar al escribir o revisar GDScript, escenas .tscn, señales, componentes o recursos .tres en Godot 4."
---
# Arquitectura GDScript

## Tipado y estilo
- Tipado estático siempre: variables, parámetros y retornos (`var radius: float = 5.0`, `func interact(actor: PlayerBase3D) -> void:`).
- Constantes con nombre, sin números mágicos (`const INTERACTION_DISTANCE: float = 1.8`).
- Un archivo, una responsabilidad: objetivo de 60 a 150 líneas, máximo 200. Si crece, extraer un componente a `src/entities/components/`.
- Cada script empieza con un docstring `##` en español (responsabilidad y dependencias). Documenta con `##` las clases, los `@export` y las funciones públicas. Comenta el porqué, no el qué.
- Logs con prefijo `[NombreClase]`. Guard clauses y `assert()` para estados nulos.

## Desacoplamiento
- Prohibido `get_parent().get_parent()` y las rutas absolutas hardcodeadas. Entre módulos se comunica por `SignalBus` o por `@export` (inyección).
- Las señales nuevas solo las añade `lead-architect` a `core/signal_bus.gd`, vía spec, y siempre tipadas.
- Los sistemas del mundo (cajas fuertes, relojes, puertas, teléfonos) implementan `can_interact() -> bool`, `get_interaction_text() -> String` e `interact(actor: PlayerBase3D) -> void`.
- La UI solo escucha señales. Las entidades no tocan nodos de UI.

## Escenas
- La lógica va en `.gd` y `.gdshader`; las `.tscn` quedan pequeñas y modulares. No editarlas a mano salvo cambios triviales, y comprobar siempre que abren sin errores.
- Estructura de entidades: ver `AGENTS.md`. Todo lo espacial va bajo `Visuals` o `Sensors`, nunca bajo `Components`.

## Datos
- El balance vive en `.tres` (`res://data/balance/`), nunca como valores sueltos en el código.
