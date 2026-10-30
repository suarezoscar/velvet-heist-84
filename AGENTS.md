# Velvet Heist '84 — Constitución del proyecto

Sigilo táctico asimétrico multijugador (1 ladrón contra 2-4 guardias). 3D isométrico ortográfico en Godot 4.7 (Forward+), arte low-poly neo-noir de 1984.
- Pilares de diseño: @docs/gdd/pillars.md. Toda mecánica, gadget o nivel se mide contra ellos.
- Diseño por sistemas: `docs/gdd/systems/` (índice en su `README.md`). `docs/gdd/MASTER_GSD.md` se está dividiendo ahí; ante un conflicto manda `systems/`.

## Herramientas y relevo
Trabajan en este repositorio, por turnos, Claude Code, Google Antigravity y opencode: cuando a una se le acaban los tokens, la siguiente sigue donde lo dejó. Todas leen este archivo, `.agents/rules/` y `.agents/skills/`; `CLAUDE.md`, `opencode.json` y `.agents/agents/` solo adaptan lo propio de cada herramienta.

| Herramienta | Principal (lo difícil: planificar, red, depuración, integrar) | Rápido (tests, `.tres`, renombrados, UI pequeña) | Revisión y diseño (`reviewer`, `game-designer`) |
|---|---|---|---|
| Claude Code | Opus | Sonnet | Opus |
| Antigravity | Claude Opus 5.5; sin cuota de Claude, Gemini 4 Argon | `flash` | `pro` |
| opencode (Go) | Kimi K3.1 Pro; de reserva, Qwen3.8 Max | Qwen3.8 Flash | el principal |

Orden de relevo: Claude Code → Antigravity (Opus) → Antigravity (Gemini) → opencode.

**Al empezar una sesión**: mira el tablero (https://github.com/users/suarezoscar/projects/1, columna «En curso») y las ramas abiertas. Si hay una tarea a medias, lee el `docs/relevo.md` de su rama antes de tocar nada.

**Mientras trabajas**:
- Commits pequeños y subidos a menudo, para que una sesión cortada no pierda trabajo.
- Mantén `docs/relevo.md` en la rama (plantilla en `docs/tasks/_RELEVO_TEMPLATE.md`): tarea (#N), hecho, falta, decisiones tomadas y preguntas pendientes al usuario. Actualízalo en cada paso que cierres. Se borra en el último commit antes de integrar.

## Flujo de trabajo
Objetivo actual: el tablero de mejoras tras el playtest, en el orden de sus bloques. Lo que no esté en el tablero, al backlog (un issue nuevo).
1. **Diseño, solo si cambia reglas**: una mecánica nueva o un cambio de reglas pasa por `game-designer` (o la skill `design`, `level`, `balance`) y lo aprueba el usuario. Un bug, un ajuste o algo técnico va directo.
2. **Tarea**: cada tarea es un issue del repositorio con su tarjeta en el tablero. Al empezar, la tarjeta pasa a «En curso»; al abrir el PR, a «En revisión»; tras integrar, a «Hecho» (el issue se cierra con «Closes #N», pero la tarjeta se mueve a mano).
3. **Implementación**: una rama `feat/N-slug`, `fix/N-slug` o `chore/` por tarea. Lo difícil lo hace el modelo principal; lo mecánico se delega en el rápido con instrucciones cerradas (archivos, firmas y valores exactos) y el principal revisa su diff antes del commit. Los tests los escribe quien implementa, junto al código.
4. **Revisión**: `reviewer` (contexto limpio) revisa los cambios con riesgo: red, seguridad, sistemas con reglas, refactors grandes. Lo pequeño se integra solo con el CI en verde.
5. **PR y merge**: PR contra `master` (está protegida: solo entra por PR con el check «Verification Pipeline»). Con el CI en verde, y `reviewer` aprobado si se pidió, integra con merge commit fijando el SHA de la cabeza. Después sincroniza `master` local, borra la rama y avisa al usuario. Si el CI falla, lee el log del job antes de tocar nada.

Un ajuste de números que no cambia reglas es una `TUNE-XXX` (solo `.tres`, plantilla `docs/tasks/_TUNE_TEMPLATE.md`).
Ante una duda de diseño o un conflicto con los pilares: parar y preguntar al usuario.

## Cómo trabajar con el usuario
- **Todo en español**: mensajes, commits, PR, comentarios, y también las descripciones de los comandos que se ven en pantalla.
- **Preguntas resaltadas**: el usuario lee en diagonal. Cada pregunta o decisión pendiente va en su propia línea como **❓ Pregunta: …**, y se repite igual de resaltada mientras siga pendiente.
- **Merge con CI verde**: el usuario autoriza a integrar los PR con el CI en verde (y `reviewer` aprobado si el cambio tiene riesgo), y a avisarle después de cada merge.
- **Ideas del playtest**: cuando el usuario dicta ideas, se entrevistan con la skill `grill-me` hasta que no quede nada asumido, y se escriben como issue en el tablero; no se implementan hasta que él lo diga.
- **Nunca**: saltarse los hooks (`--no-verify`), forzar un push, borrar ramas remotas ajenas o tocar el token de GitHub. Lo que pida `sudo` lo ejecuta el usuario en su terminal.

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
