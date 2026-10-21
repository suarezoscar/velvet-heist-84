# Velvet Heist '84 — Constitución del proyecto

Sigilo táctico asimétrico multijugador (1 ladrón vs 2-4 guardias). 3D isométrico ortográfico en Godot 4.7 (Forward+), arte low-poly años 80 generado con Blender. Regla de oro: cero alta tecnología; toda interacción es física y analógica.
Diseño completo: @docs/gdd/MASTER_GSD.md (consultar bajo demanda; no duplicar aquí).

## Método de trabajo
1. Ninguna feature, mecánica, gadget o asset se implementa sin `docs/tasks/FEAT-XXX-slug.md` aprobada por el usuario (skill `/spec`).
2. Cada tarea cierra con evidencia (skill `/verify`): salida de comandos, JSON de validación o capturas. Un "listo" sin evidencia no cuenta.
3. Quien escribe no revisa: la revisión (`/review`) la hace otro agente con contexto limpio.
4. Orquestación: el agente principal delega con `invoke_subagent` a los subagentes de `.agents/agents/` (no con `define_subagent`), con un worktree aislado por tarea (`branch`). Un subagente empieza sin historial: pásale la ruta de la FEAT y los contratos.
5. Ante una duda de diseño o un conflicto con el GSD: parar y preguntar al usuario.

## Versiones y convenciones
- Godot 4.7.x (la versión exacta se fija en `tools/ci/`). GDScript con tipado estático.
- 1 unidad en Blender = 1 metro en Godot. Godot: Y-up, -Z forward.
- Cámara: `Camera3D` ortográfica, rotación (-35.264°, 45°, 0). Movimiento: input (x, 0, y) rotado 45° sobre Y.
- Assets `.glb` inmutables en Godot: prohibido escalar o mover vértices para corregir tamaño o pivote. Se corrige en Blender y se reexporta.

## Estructura de entidades (actores jugables e interactivos)
Raíz (`CharacterBody3D`, `StaticBody3D` o `Area3D` según el caso) con `CollisionShape3D` como hijo directo y tres ramas:
- `Visuals` (Node3D): solo el `.glb` importado, `AnimationPlayer`, `GPUParticles3D` y Tweens.
- `Sensors` (Node3D): `Area3D` (hitboxes), `RayCast3D` y `SpotLight3D` de gameplay.
- `Components` (Node): solo lógica pura (`HealthComponent`, máquinas de estados). Un Node3D bajo un Node plano no hereda transformaciones, así que nada espacial va aquí.
El código previo usa `VisualRoot`; migrarlo a `Visuals` solo mediante una FEAT dedicada, nunca de pasada.

## Propiedad de carpetas
| Subagente | Es dueño de |
|---|---|
| lead-architect | `project.godot`, `core/` (salvo `net_manager.gd`), `AGENTS.md`, `.agents/`, `docs/` |
| gameplay-engineer | `src/entities/`, `src/systems/`, `src/gadgets/`, `src/network/`, `core/net_manager.gd`, `data/`, `tests/` |
| technical-artist | `tools/blender_scripts/`, `assets/models/` |
| vfx-ui-engineer | `assets/shaders/`, `assets/audio/`, `src/vfx/`, `scenes/ui/` |

`scenes/maps/` lo ensambla el usuario; un agente solo toca mapas si una FEAT lo pide. Para cambiar algo fuera de tu carpeta, pídeselo a su dueño a través del agente principal.

## Definición de hecho
1. Código tipado y parseable.
2. Tests nuevos o actualizados en verde.
3. Assets con validación JSON en `pass`.
4. Cada criterio de la FEAT con su evidencia.
5. Revisión de otro agente sin bloqueantes.
Los comandos concretos viven en `tools/ci/` (ver FEAT-000).

## Prohibido
- `get_parent().get_parent()` y rutas absolutas hardcodeadas.
- Editar `project.godot` o `core/signal_bus.gd` si no eres `lead-architect`.
- Meter lógica en `.tscn` o editarlas a mano más allá de cambios triviales.
- Tocar scripts o escenas existentes fuera del alcance de la FEAT en curso.

## Reglas por dominio (se cargan según su descripción)
`.agents/rules/`: 01 arquitectura GDScript · 02 assets Blender · 03 red · 04 VFX, shaders y UI · 05 verificación.
