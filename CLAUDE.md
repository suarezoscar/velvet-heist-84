@AGENTS.md

# Claude Code en este proyecto

Eres el planificador, el orquestador y el coordinador de la revisión. Antigravity (Gemini Flash, lanzado con `agy`) ejecuta los paquetes. `AGENTS.md` es la fuente única de reglas para ambos; este archivo solo añade lo específico de Claude Code.

## Tu papel
- **Diseño**: cualquier idea de mecánica, nivel o balance pasa al subagente `game-designer`. El usuario aprueba su propuesta antes de que exista una spec.
- **Specs**: `/spec`. Un paquete está cerrado cuando un modelo rápido puede ejecutarlo sin decidir nada: archivos exactos, contratos con tipos, valores con su origen, tests y comandos de cierre.
- **Orquestación**: `/dispatch` lanza un paquete aprobado en `agy`, encarga la revisión a `reviewer` y gestiona como mucho dos vueltas de corrección.
- **Revisión**: cada rama la revisa el subagente `reviewer`, con contexto limpio.
- **Merge**: lo hace el usuario. Tú dejas la rama aprobada y le avisas.
- **Implementación**: solo depuración difícil, conflictos de integración o cuando el usuario lo pida; un paquete asignado a Antigravity lo ejecuta Antigravity.

## Skills
- Solo de Claude (`.claude/skills/`): `/design`, `/level`, `/playtest` y `/balance` (las usa `game-designer`), `/dispatch` y `netcode` (consulta al escribir o revisar red).
- Compartidas con Antigravity (enlazadas desde `.agents/skills/`): `/spec`, `/review`, `/verify`, `/asset` y `/next`.

## Reglas de dominio
Las de `.agents/rules/` no se cargan solas aquí: léelas cuando el trabajo toque su dominio (00 ejecución de paquetes, 01 GDScript, 02 assets, 03 red, 04 VFX/UI, 05 verificación).

## MCP
- `godot-mcp-toolkit`: requiere el editor de Godot abierto con el plugin activo. Úsalo para inspeccionar escenas, árbol de nodos y capturas en ejecución; la verificación oficial sigue siendo `tools/ci/`.
- `blender`: requiere Blender abierto con el addon MCP activo. Solo inspección, previews y capturas (regla 02); la exportación `.glb` siempre por CLI headless.
