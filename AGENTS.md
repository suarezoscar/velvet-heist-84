# Velvet Heist '84 — Constitución del proyecto

Sigilo táctico asimétrico multijugador (1 ladrón contra 2-4 guardias). 3D isométrico ortográfico en Godot 4.7 (Forward+), arte low-poly neo-noir de 1984.
- Pilares de diseño: @docs/gdd/pillars.md. Toda mecánica, gadget o nivel se mide contra ellos.
- Diseño por sistemas: `docs/gdd/systems/` (índice en su `README.md`). `docs/gdd/MASTER_GSD.md` se está dividiendo ahí; ante un conflicto manda `systems/`.

## Flujo de trabajo (desde el 2026-10-24: solo Claude)
Objetivo actual: el PoC jugable de `docs/decisions/2026-10-23-roadmap-poc.md`. Lo que no acerque a esa meta va al backlog.
1. **Diseño, solo si cambia reglas**: una mecánica nueva o un cambio de reglas pasa por `game-designer` (`/design`, `/level`, `/balance`) y lo aprueba el usuario. Un bug, un ajuste o algo técnico va directo.
2. **Nota de FEAT**: `docs/tasks/FEAT-XXX-slug.md` corta (plantilla `_TEMPLATE.md`): objetivo, criterios medibles, riesgos y decisiones abiertas. Se ajusta en la misma rama mientras se trabaja.
3. **Implementación**: una rama `feat/XXX-slug` (o `fix/`, `chore/`) por FEAT, commits pequeños. Claude implementa; los tests los escribe quien implementa, junto al código.
4. **Revisión**: `reviewer` (contexto limpio) revisa los cambios con riesgo: red, seguridad, sistemas con reglas, refactors grandes. Lo pequeño se integra solo con el CI en verde.
5. **PR y merge**: PR contra `master` y merge con el CI en verde (y `reviewer` aprobado si se pidió). El usuario puede revisar o integrar él mismo cualquier PR.

Un ajuste de números que no cambia reglas es una `TUNE-XXX` (solo `.tres`, plantilla `docs/tasks/_TUNE_TEMPLATE.md`).
La cola de trabajo se consulta con `/next` y el tablero del PoC. Ante una duda de diseño o un conflicto con los pilares: parar y preguntar al usuario.

## Agentes y modelos
| Quién | Modelo | Papel |
|---|---|---|
| Sesión principal de Claude Code | Opus | Planifica, implementa lo difícil (red, sistemas, depuración), integra |
| Subagentes de tareas rápidas | Sonnet | Tests, ajustes pequeños, datos `.tres`, refactors acotados y mecánicos |
| `game-designer` (`.claude/agents/`) | — | Propone mecánicas, niveles y balance; no escribe código |
| `reviewer` (`.claude/agents/`) | Opus | Revisión y auditoría independientes de los cambios con riesgo |

`scenes/maps/` lo ensambla el usuario; solo se toca si una FEAT lo pide.

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
4. Patrones prohibidos: `./tools/ci/check_patterns.sh`.
5. Tests en verde: `./tools/ci/run_tests.sh`.
6. Assets validados en `pass` y con origen y licencia en su ficha (regla 02).
7. Cada criterio de la FEAT con su evidencia empírica.
8. `reviewer` aprueba sin bloqueantes, si el cambio tiene riesgo.
9. Si cambió el diseño, `docs/gdd/systems/` está actualizado.

## Límites duros
- Comunicación entre módulos por `SignalBus` o `@export`; sin `get_parent().get_parent()` ni rutas absolutas.
- `project.godot` y `core/signal_bus.gd` se cambian solo cuando la FEAT lo dice, y en su propio commit.
- La lógica va en `.gd` y `.gdshader`; las `.tscn` se editan a mano solo para cambios triviales.
- Cada cambio se queda dentro del alcance de su FEAT; lo demás va al backlog.

## Reglas por dominio (se cargan según su descripción)
`.agents/rules/`: 01 arquitectura GDScript · 02 assets · 03 red · 04 VFX, shaders y UI · 05 verificación · 06 textos para el jugador (`docs/gdd/estilo-de-textos.md`).
