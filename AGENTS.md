# Velvet Heist '84 — Constitución del proyecto

Sigilo táctico asimétrico multijugador (1 ladrón contra 2-4 guardias). 3D isométrico ortográfico en Godot 4.7 (Forward+), arte low-poly neo-noir de 1984.
- Pilares de diseño: @docs/gdd/pillars.md. Toda mecánica, gadget o nivel se mide contra ellos.
- Diseño por sistemas: `docs/gdd/systems/` (índice en su `README.md`). `docs/gdd/MASTER_GSD.md` se está dividiendo ahí; ante un conflicto manda `systems/`.

## Flujo de trabajo
1. **Diseño**: mecánicas, niveles y balance nacen como propuesta de `game-designer` (`/design`, `/level`, `/balance`) y el usuario la aprueba. Las tareas puramente técnicas (refactor, red, CI) empiezan en el paso 2.
2. **Spec**: Claude Code escribe `docs/tasks/FEAT-XXX-slug.md` con contratos y un paquete de ejecución por agente (`/spec`). El usuario la aprueba.
3. **Ejecución**: Claude lanza cada paquete en Antigravity (`agy`) en su propio worktree y rama `feat/XXX-pkgN`. El ejecutor sigue `.agents/rules/00-ejecucion-de-paquetes.md`.
4. **Revisión**: `reviewer` (Claude, contexto limpio) repite las comprobaciones y audita spec, código y tests. Como mucho dos vueltas de corrección; después decide el usuario.
5. **PR y merge**: Claude publica la rama aprobada, abre el PR contra la rama de integración de la FEAT (por defecto `master`) y lo integra cuando `reviewer` ha aprobado y el CI está en verde. Con el CI en rojo o pendiente no se integra. El usuario puede revisar o integrar él mismo cualquier PR.

Quien escribe el código no lo revisa ni escribe sus tests de aceptación: esos tests los escribe `qa-engineer` en su propio paquete, a partir de los criterios de la spec.
Un ajuste de números que no cambia reglas es una `TUNE-XXX` (solo `.tres`, plantilla `docs/tasks/_TUNE_TEMPLATE.md`).
La cola de trabajo se consulta con `/next`. Ante una duda de diseño o un conflicto con los pilares: parar y preguntar al usuario.

## Agentes
| Agente | Dónde | Papel |
|---|---|---|
| Claude Code | Claude | Planifica, escribe specs, orquesta `agy` y coordina la revisión |
| `game-designer` | Claude (`.claude/agents/`) | Propone mecánicas, niveles y balance; no escribe código |
| `reviewer` | Claude (`.claude/agents/`) | Revisión y auditoría independientes |
| `integrator` | Antigravity | Integra ramas y aplica en `core/` y `project.godot` lo que dicte un paquete |
| `gameplay-engineer`, `technical-artist`, `vfx-ui-engineer`, `qa-engineer` | Antigravity | Ejecutan paquetes |

Propiedad de carpetas: `.agents/ownership.yml` es la única fuente y CI la comprueba (`tools/ci/check_scope.py`). Si un paquete necesita tocar algo ajeno, la spec lo declara como excepción.
`scenes/maps/` lo ensambla el usuario; un agente solo lo toca si una FEAT lo pide.

## Versiones y convenciones
- Godot 4.7.x (la versión exacta se fija en `tools/ci/`). GDScript con tipado estático.
- 1 unidad en Blender = 1 metro en Godot. Godot: Y-up, -Z forward.
- Cámara: `Camera3D` ortográfica, rotación (-35.264°, 45°, 0). Movimiento: input (x, 0, y) rotado 45° sobre Y.
- Assets `.glb` inmutables en Godot: el tamaño y el pivote se corrigen en Blender y se reexporta.
- Los números de juego viven en `.tres` de `data/balance/`; el código los lee de ahí.

## Estructura de entidades (actores jugables e interactivos)
Raíz (`CharacterBody3D`, `StaticBody3D` o `Area3D` según el caso) con `CollisionShape3D` como hijo directo y tres ramas:
- `Visuals` (Node3D): solo el `.glb` importado, `AnimationPlayer`, `GPUParticles3D` y Tweens.
- `Sensors` (Node3D): `Area3D` (hitboxes), `RayCast3D` y `SpotLight3D` de gameplay.
- `Components` (Node): solo lógica pura (`HealthComponent`, máquinas de estados). Un Node3D bajo un Node plano no hereda transformaciones, así que lo espacial va en `Visuals` o `Sensors`.
El código previo usa `VisualRoot`; migrarlo a `Visuals` solo mediante una FEAT dedicada.
Los modelos de Mixamo miran a +Z: `VisualRoot` los gira 180° para que el frente del personaje sea -Z.

## Control de personajes y mapas
- Cada mapa jugable extiende `HeistMap3D` (`src/maps/heist_map_3d.gd`), que localiza ladrón y guardias, decide el jugador local, la cámara, el HUD, la percepción y el golpe. La lógica propia del mapa va en sus ganchos (`_on_map_ready`, `_setup_online_control`…).
- Solo el personaje con `is_locally_controlled = true` lee `Input`, y como mucho hay uno por cliente. Sin red se controla al ladrón; en builds de depuración, F1–F5 cambian de personaje.
- Para saber si hay red usa `NetManager.is_online()`. Sin red, Godot usa un `OfflineMultiplayerPeer` con autoridad sobre todo, así que `multiplayer_peer != null` e `is_multiplayer_authority()` no sirven para decidirlo.
- La IA escribe su intención con `apply_world_move()`; la simulación (gravedad, estamina, pasos) es la misma que para un humano.

## Definición de hecho
1. Importación limpia: `./tools/ci/import.sh`.
2. Scripts que compilan con los autoloads: `./tools/ci/check_scripts.sh`.
3. Lint y formato de los archivos cambiados, bloqueante (máximo 300 líneas por archivo): `./tools/ci/lint.sh`.
4. Patrones prohibidos y alcance del paquete: `./tools/ci/check_patterns.sh` y `python3 tools/ci/check_scope.py`.
5. Tests en verde: `./tools/ci/run_tests.sh`.
6. Assets validados en `pass` y con origen y licencia en su ficha (regla 02).
7. Cada criterio de la FEAT con su evidencia empírica.
8. `reviewer` aprueba sin bloqueantes.
9. Si cambió el diseño, `docs/gdd/systems/` está actualizado.

## Límites duros
- Comunicación entre módulos por `SignalBus` o `@export`; sin `get_parent().get_parent()` ni rutas absolutas.
- `project.godot` y `core/signal_bus.gd` los edita `integrator`, siguiendo un paquete.
- La lógica va en `.gd` y `.gdshader`; las `.tscn` se editan a mano solo para cambios triviales.
- Cada cambio se queda dentro del alcance de su paquete.

## Reglas por dominio (se cargan según su descripción)
`.agents/rules/`: 00 ejecución de paquetes · 01 arquitectura GDScript · 02 assets · 03 red · 04 VFX, shaders y UI · 05 verificación.
