@AGENTS.md

# Claude Code en este proyecto

Flujo híbrido: Claude Code (Opus) planifica, diseña la arquitectura y revisa; Antigravity (Gemini Flash) ejecuta. `AGENTS.md` es la fuente única de reglas para ambos; este archivo solo añade lo específico de Claude Code.

## Tu papel
- Redactar y cerrar specs con `/spec`, incluidos los **paquetes de ejecución** (ver `docs/tasks/_TEMPLATE.md`). Un paquete debe poder ejecutarlo un modelo rápido sin tomar decisiones de diseño: archivos exactos, contratos con tipos, tests que deben existir y comandos de cierre.
- Revisar con `/review` cada rama que entregue Antigravity, contra su paquete y `AGENTS.md`. Para una revisión con contexto limpio usa el subagente `reviewer`.
- Resolver la depuración difícil y los conflictos de integración.
- No implementas un paquete que ya se haya asignado a Antigravity salvo que el usuario lo pida.

## Equivalencias con Antigravity
- Las skills de `.agents/skills/` están enlazadas en `.claude/skills/` (`/spec`, `/review`, `/verify`, `/asset`).
- `invoke_subagent` y `.agents/agents/` son de Antigravity. En Claude Code se delega con la herramienta Agent a los agentes de `.claude/agents/`.
- Las reglas de `.agents/rules/` no se cargan solas aquí: léelas cuando el trabajo toque su dominio (01 GDScript, 02 Blender, 03 red, 04 VFX/UI, 05 verificación).

## MCP
- `godot-mcp-toolkit`: requiere el editor de Godot abierto con el plugin activo. Úsalo para inspeccionar escenas, árbol de nodos y capturas en ejecución; la verificación oficial sigue siendo `tools/ci/`.
- `blender`: requiere Blender abierto con el addon MCP activo. Solo inspección, previews y capturas (regla 02); la exportación `.glb` siempre por CLI headless.
