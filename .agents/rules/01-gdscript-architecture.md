---
trigger: model_decision
description: "Aplicar al escribir o revisar GDScript, escenas .tscn, señales, componentes o recursos .tres en Godot 4."
---
# Arquitectura GDScript

## Tipado y estilo
- Tipado estático siempre: variables, parámetros y retornos (`var radius: float = 5.0`, `func interact(actor: PlayerBase3D) -> void:`).
- Constantes con nombre para lo que no es balance (`const INTERACTION_DISTANCE: float = 1.8`); los números de juego van en `.tres` (ver "Datos").
- Un archivo, una responsabilidad: objetivo de 60 a 150 líneas. CI bloquea cualquier archivo modificado que pase de **300 líneas** (`gdlint`, `max-file-lines`). Si tu cambio lo supera, extrae un componente a `src/entities/components/`. Si el archivo ya superaba el límite y tu paquete no incluye su refactor, es una ambigüedad: para y repórtala.
- Cada script empieza con un docstring `##` en español (responsabilidad y dependencias). Documenta con `##` las clases, los `@export` y las funciones públicas. Comenta el porqué, no el qué.
- Logs con prefijo `[NombreClase]`. Guard clauses y `assert()` para estados nulos.

## Desacoplamiento
- Entre módulos se comunica por `SignalBus` o por `@export` (inyección), con rutas relativas cortas dentro de la propia escena. `get_parent().get_parent()` y las rutas `/root/...` quedan fuera (CI las busca con `tools/ci/check_patterns.sh`).
- Las señales nuevas se añaden a `core/signal_bus.gd` cuando la FEAT lo dice, siempre tipadas.
- Los sistemas del mundo (cajas fuertes, relojes, puertas, teléfonos) implementan `can_interact() -> bool`, `get_interaction_text() -> String` e `interact(actor: PlayerBase3D) -> void`.
- La UI solo escucha señales. Las entidades no tocan nodos de UI.

## Escenas
- La lógica va en `.gd` y `.gdshader`; las `.tscn` quedan pequeñas y modulares. A mano solo cambios triviales, y comprobar siempre que abren sin errores.
- Estructura de entidades: ver `AGENTS.md`. Todo lo espacial va bajo `Visuals` o `Sensors`.

## Datos
- Cada número de juego (velocidades, ruido, tiempos, distancias de detección, valores de botín) vive en un único `.tres` de `res://data/balance/` y el código lo lee de ahí, sin copia en constantes.
- Los tests comprueban relaciones entre valores (alfombra < mármol < parqué; sigilo < andar < correr) o leen el `.tres`. Así un ajuste `TUNE` no rompe la suite.
