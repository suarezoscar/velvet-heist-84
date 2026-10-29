@AGENTS.md

# Claude Code en este proyecto

Desde el 2026-10-24 todo el trabajo lo hace Claude: la sesión principal (Opus) planifica, implementa y integra, y delega en subagentes Sonnet lo rápido y mecánico. `AGENTS.md` es la fuente de reglas; este archivo añade cómo trabajar aquí.

## Cómo trabajar
- **Hacia lo jugable**: prioriza lo que acerca el PoC (`docs/decisions/2026-10-23-roadmap-poc.md`) y mueve el tablero del PoC al avanzar. Lo demás, al backlog.
- **Delegar con el modelo justo**: `Agent` con `model: "sonnet"` para tareas acotadas (tests de algo ya implementado, datos `.tres`, renombrados, ajustes de UI pequeños, búsquedas amplias). Lo que exige criterio (red, percepción, depuración difícil, diseño de sistemas) lo hace la sesión principal. Varias tareas independientes pueden ir en paralelo, cada una en su worktree si tocan archivos distintos de la rama.
- **Lo que es sensación** (aspecto, sonido, HUD, ritmo) se prototipa rápido en una rama y se enseña al usuario antes de pulirlo.
- **PR y merge**: con el CI en verde (y `reviewer` aprobado si el cambio tiene riesgo), integra con merge commit y `expectedHeadSha`. Si falla, lee el log del job (`get_job_logs`). Después sincroniza `master` local y borra la rama. Avisa al usuario de cada merge.
- **Preguntas al usuario**: resáltalas en el texto (**❓ Pregunta: …**); lee en diagonal.

## Skills
- Diseño de juego: `/design` (mecánicas y sistemas contra los pilares), `/level` (niveles como datos), `/balance` (números y TUNE), `/playtest` (informe estructurado tras jugar). Úsalas directamente o a través de `game-designer`.
- Godot: `godot-mcp-toolkit` para inspeccionar escenas, el árbol de nodos, ejecutar el juego y hacer capturas con el editor abierto; la verificación oficial sigue siendo `tools/ci/`.
- Técnicas: `netcode` (red), `/asset` (modelos con Blender), `/verify` (definición de hecho), `/review` (revisión), `/spec` (nota de FEAT) y `/next` (cola de trabajo).

## Reglas de dominio
Las de `.agents/rules/` no se cargan solas aquí: léelas cuando el trabajo toque su dominio (01 GDScript, 02 assets, 03 red, 04 VFX/UI, 05 verificación, 06 textos para el jugador).

## MCP
- `github`: registrado en ámbito local del proyecto (token del usuario, fuera del repositorio). Para PR, estado del CI y logs de Actions.
- `godot-mcp-toolkit`: requiere el editor de Godot abierto con el plugin activo. Úsalo para inspeccionar escenas, árbol de nodos y capturas en ejecución.
- `blender`: requiere Blender abierto con el addon MCP activo. Solo inspección, previews y capturas (regla 02); la exportación `.glb` siempre por CLI headless.
