@AGENTS.md

# Claude Code en este proyecto

`AGENTS.md` es la fuente de reglas, común a Claude Code, Antigravity y opencode. Aquí solo va lo propio de Claude Code.

- **Delegar**: lo mecánico va a `Agent` con `model: "sonnet"` y un prompt cerrado (archivos, firmas y valores exactos). Al cerrar cada PR, di qué hizo Sonnet.
- **Subagentes**: `reviewer` y `game-designer` están en `.claude/agents/`, generados desde `.agents/agents/` con `tools/agents/sync.py` (no los edites a mano).
- **Skills**: en `.agents/skills/`; `.claude/skills/` solo tiene enlaces a ellas.
- **Reglas de dominio**: las de `.agents/rules/` no se cargan solas aquí; léelas cuando el trabajo toque su dominio (01 GDScript, 02 assets, 03 red, 04 VFX/UI, 05 verificación, 06 textos para el jugador).
- **MCP**: `github` (ámbito local, token del usuario fuera del repositorio) para PR, CI y logs; `godot-mcp-toolkit` con el editor abierto para inspeccionar escenas y capturas (la verificación oficial sigue siendo `tools/ci/`); `blender` con Blender abierto, solo inspección (la exportación `.glb` siempre por CLI headless).
- **Lo que es sensación** (aspecto, sonido, HUD, ritmo) se prototipa rápido y se enseña al usuario antes de pulirlo.
