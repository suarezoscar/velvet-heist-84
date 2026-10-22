---
trigger: model_decision
description: "Aplicar al terminar una tarea, validar código, ejecutar tests o lint, importar assets, preparar CI o reportar evidencias de verificación."
---
# Verificación

Los comandos viven en `tools/ci/` y se ejecutan desde la raíz. Orden de comprobación:

1. Importar el proyecto en headless: `./tools/ci/import.sh` (en un worktree nuevo es obligatorio antes de todo lo demás: no hay caché `.godot/`). Falla si el log de Godot contiene errores (`scan_godot_log.sh`).
2. Compilar cada `.gd` modificado: `./tools/ci/check_scripts.sh <archivos>`. Carga los scripts dentro del proyecto con sus autoloads; `godot --check-only` no registra autoloads y da falsos errores con `SignalBus` o `NetManager` tipados.
3. Lint y formato de los archivos cambiados respecto a `master`: `./tools/ci/lint.sh` (bloqueante; `gdformat <archivo>` corrige el formato).
4. Patrones prohibidos: `./tools/ci/check_patterns.sh`.
5. Alcance del paquete (en ramas `feat/XXX-pkgN`): `python3 tools/ci/check_scope.py`.
6. Tests GUT en headless: `./tools/ci/run_tests.sh`. Si un test carga un mapa, usa un mapa por test y deja que `autofree` lo libere.
7. Validador de assets (FEAT-001):
   - su suite, si cambia `tools/blender_scripts/`: `./tools/ci/run_blender_tests.sh` (Blender fijado en `tools/ci/blender_version.env`);
   - el validador sobre cada `.glb` o script de Blender modificado.
8. Tests de las herramientas de CI, si cambia `tools/ci/`: `./tools/ci/qa_*.sh`.
9. Prueba manual breve cuando la tarea afecte al game feel: describir qué se probó y qué se vio.

Informe de evidencia obligatorio al cerrar: comando ejecutado, código de salida, resultado real y archivos afectados. Un paso que no se pudo ejecutar se informa con su motivo, nunca como superado.
