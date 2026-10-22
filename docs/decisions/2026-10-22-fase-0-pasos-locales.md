# Fase 0 — pasos locales

Para Claude Code en la máquina del usuario (o para el usuario). Una sesión de Claude en la nube ya escribió en la carpeta del proyecto los archivos de la lista final, **sin commit**. Lo que sigue necesita terminal. El porqué está en `docs/decisions/2026-10-22-flujo-v2.md`.

## 1. Rama
1. `git status`: deberían aparecer solo los archivos de la lista final (modificados o nuevos). Si hay otros cambios del usuario, pregúntale qué hacer con ellos antes de seguir.
2. La copia estaba en `fix/stabilize-baseline`. Si esa rama aún no está en `master`, pregunta al usuario si crear la rama de este cambio desde ella o integrarla antes.
3. `git switch -c chore/flujo-v2`

## 2. Ajustes que no se pueden hacer escribiendo archivos
1. La sesión en la nube no puede escribir en `.claude/`: dejó esos archivos en `_fase0_claude/` con la misma estructura. Muévelos y borra la carpeta temporal:
   `cp -r _fase0_claude/. .claude/ && rm -r _fase0_claude`
   Comprueba que `.claude/agents/reviewer.md` es la versión nueva (menciona el "Modo auditoría").
2. Tampoco puede escribir el workflow de CI: `mv docs/decisions/fase-0-ci.yml .github/workflows/ci.yml` y revisa el diff con `git diff .github/workflows/ci.yml` (añade `fetch-depth: 0`, `BASE_REF`, `SCOPE_BRANCH` y los pasos de alcance, patrones y lint bloqueante).
3. `git rm .agents/agents/lead-architect.md` (lo sustituye `integrator.md`).
4. Enlace de la skill compartida nueva, con el mismo formato que los existentes (`ls -l .claude/skills`): por ejemplo `ln -s ../../.agents/skills/next .claude/skills/next`.
5. `chmod +x tools/ci/*.sh tools/ci/check_scope.py tools/agy/dispatch.sh .githooks/pre-commit`
6. `git config core.hooksPath .githooks`
7. Opcional: borrar `velvet-heist-antigravity-config.zip` (copia antigua de la configuración; git ya la ignora).

## 3. Herramientas
1. gdtoolkit: `gdlint --version`; si falta, `pip install --user gdtoolkit==4.5.0`.
2. Antigravity CLI: instalador oficial `curl -fsSL https://antigravity.google/cli/install.sh | bash` (enséñale el script al usuario antes de ejecutarlo). Después, `agy` en interactivo una vez para iniciar sesión (el modo headless reutiliza esas credenciales; en Linux necesita el llavero desbloqueado).
3. `agy models`: copia el slug del modelo Flash en `AGY_MODEL` de `tools/agy/config.env`.
4. `agy agents`: deben aparecer `integrator`, `gameplay-engineer`, `technical-artist`, `vfx-ui-engineer` y `qa-engineer`. Si no aparecen, pon `AGY_USE_AGENT_FLAG=0` en `tools/agy/config.env` y díselo al usuario.
5. Permisos de `agy` en `~/.gemini/antigravity-cli/settings.json` (fusiona con lo que haya). Sintaxis comprobada en la documentación del CLI: `toolPermission` es una clave de primer nivel y `command(<prefijo>)` compara palabra por palabra. `proceed-in-sandbox` avanza sin preguntar dentro del sandbox (`--sandbox`); la lista `deny` manda sobre las demás:
   ```json
   {
     "toolPermission": "proceed-in-sandbox",
     "enableTerminalSandbox": true,
     "permissions": {
       "allow": [
         "command(git)", "command(godot)", "command(blender)",
         "command(gdlint)", "command(gdformat)", "command(python3)",
         "command(./tools/ci/import.sh)", "command(./tools/ci/check_scripts.sh)",
         "command(./tools/ci/run_tests.sh)", "command(./tools/ci/lint.sh)",
         "command(./tools/ci/check_patterns.sh)", "command(./tools/ci/changed_files.sh)",
         "read_file(<home>/.local/bin)", "read_file(<home>/.local/share/uv/tools/gdtoolkit)",
         "read_file(<ruta real del binario de godot>)",
         "write_file(<home>/.local/share/godot)", "write_file(<home>/.config/godot)",
         "write_file(<home>/.cache/godot)"
       ],
       "deny": ["command(git push)", "command(rm -rf)", "command(curl)", "command(wget)"]
     }
   }
   ```
   El sandbox solo ve `/usr`, `/etc`, el workspace y lo concedido con `read_file`/`write_file`: las herramientas instaladas en `$HOME` (gdtoolkit, Godot) y los datos de Godot hay que concederlos con rutas absolutas (`readlink -f $(command -v godot gdlint)`). Sin ellas, `lint.sh` falla con "faltan gdlint/gdformat".
   Nunca `--dangerously-skip-permissions` ni `toolPermission: always-proceed`.

## 4. Pruebas de humo de agy
1. Lee la configuración del repositorio:
   `agy -p "Lee AGENTS.md y .agents/rules/00-ejecucion-de-paquetes.md y resume en cinco líneas cómo se ejecuta un paquete" --model <slug> --output-format json --sandbox`
   El resumen debe hablar del bloque `allowed`, de parar ante ambigüedades y del informe de entrega.
2. Permisos de comandos:
   `agy -p "Ejecuta ./tools/ci/lint.sh y dime su código de salida" --model <slug> --output-format json --sandbox`
   En stderr no debe aparecer ningún permiso denegado. Si aparece, ajusta la lista del paso 3.5.

## 5. Verificación
| Comando | Esperado |
|---|---|
| `./tools/ci/import.sh` | sin errores |
| `./tools/ci/check_scripts.sh` | todos compilan |
| `./tools/ci/run_tests.sh` | verde, como antes del cambio |
| `./tools/ci/lint.sh` | "no hay archivos .gd cambiados" (este cambio no toca GDScript) |
| `./tools/ci/check_patterns.sh` | ídem |
| `python3 tools/ci/check_scope.py` | "no es una rama de paquete; se omite" |
| `./tools/ci/lint.sh --all` y `./tools/ci/check_patterns.sh --all` | informe de la deuda heredada: anota el número de avisos para el usuario |

## 6. Commit y publicación
1. `git add` de los archivos de la lista final (los de `.claude/` ya en su sitio), más el borrado y el enlace del paso 2. Nada más; `_fase0_claude/` y `docs/decisions/fase-0-ci.yml` ya no deben existir.
2. `git commit -m "chore: flujo de trabajo v2 (Claude planifica y revisa, agy ejecuta)"`
3. CI necesita `origin/master` como base: si `git ls-remote origin master` no devuelve nada, pide al usuario publicar `master`.
4. `git push -u origin chore/flujo-v2` y pide al usuario que revise y haga el merge.

## 7. Siguiente paso
Fase 1: el usuario pide a Claude Code "audita FEAT-000 a FEAT-005 con reviewer en modo auditoría".

## Archivos escritos por la sesión en la nube
Nuevos: `.agents/agents/integrator.md`, `.agents/ownership.yml`, `.agents/rules/00-ejecucion-de-paquetes.md`, `.agents/skills/next/SKILL.md`, `.claude/agents/game-designer.md`, `.githooks/pre-commit`, `docs/decisions/2026-10-22-fase-0-pasos-locales.md`, `docs/decisions/2026-10-22-flujo-v2.md`, `docs/gdd/balance-changelog.md`, `docs/gdd/pillars.md`, `docs/gdd/systems/README.md`, `docs/tasks/_TUNE_TEMPLATE.md`, `tools/agy/config.env`, `tools/agy/dispatch.sh`, `tools/ci/changed_files.sh`, `tools/ci/check_patterns.sh`, `tools/ci/check_scope.py`.
Lista completa:
```
.agents/agents/gameplay-engineer.md
.agents/agents/integrator.md
.agents/agents/qa-engineer.md
.agents/agents/technical-artist.md
.agents/agents/vfx-ui-engineer.md
.agents/ownership.yml
.agents/rules/00-ejecucion-de-paquetes.md
.agents/rules/01-gdscript-architecture.md
.agents/rules/02-blender-assets.md
.agents/rules/03-netcode.md
.agents/rules/05-verification.md
.agents/skills/asset/SKILL.md
.agents/skills/asset/references/asset-card.md
.agents/skills/next/SKILL.md
.agents/skills/review/SKILL.md
.agents/skills/spec/SKILL.md
.agents/skills/verify/SKILL.md
.claude/agents/game-designer.md
.claude/agents/reviewer.md
.claude/skills/THIRD_PARTY_NOTICES.md
.claude/skills/balance/SKILL.md
.claude/skills/design/SKILL.md
.claude/skills/design/references/design-review.md
.claude/skills/design/references/system-template.md
.claude/skills/dispatch/SKILL.md
.claude/skills/level/SKILL.md
.claude/skills/level/references/level-checklist.md
.claude/skills/netcode/SKILL.md
.claude/skills/netcode/references/authority-and-visibility.md
.claude/skills/netcode/references/dedicated-server.md
.claude/skills/netcode/references/prediction-and-interpolation.md
.claude/skills/playtest/SKILL.md
.claude/skills/playtest/references/report-template.md
.githooks/pre-commit
.github/workflows/ci.yml
.gitignore
AGENTS.md
CLAUDE.md
docs/decisions/2026-10-22-fase-0-pasos-locales.md
docs/decisions/2026-10-22-flujo-v2.md
docs/gdd/MASTER_GSD.md
docs/gdd/balance-changelog.md
docs/gdd/pillars.md
docs/gdd/systems/README.md
docs/tasks/_TEMPLATE.md
docs/tasks/_TUNE_TEMPLATE.md
gdlintrc
tools/agy/config.env
tools/agy/dispatch.sh
tools/ci/changed_files.sh
tools/ci/check_patterns.sh
tools/ci/check_scope.py
tools/ci/lint.sh
```
