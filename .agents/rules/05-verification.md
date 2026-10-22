---
trigger: model_decision
description: "Aplicar al terminar una tarea, validar código, ejecutar tests o lint, importar assets, preparar CI o reportar evidencias de verificación."
---
# Verificación

Los comandos concretos viven en `tools/ci/` y se fijan en FEAT-000. Orden de comprobación:

1. Importar el proyecto en headless: `godot --headless --import`.
2. Compilar cada `.gd` modificado: `./tools/ci/check_scripts.sh <archivos>`. Carga los scripts dentro del proyecto con sus autoloads; no usar `godot --check-only`, que no registra autoloads y da falsos errores al usar `SignalBus` o `NetManager` tipados.
3. Lint y formato con gdtoolkit (`gdlint`, `gdformat --check`) cuando esté configurado.
4. Tests GUT en headless (`./tools/ci/run_tests.sh`). Si un test carga un mapa, usa un mapa por test y deja que `autofree` lo libere.
5. Validador de assets (FEAT-001) sobre cada `.glb` o script de Blender modificado.
6. Prueba manual breve cuando la tarea afecte al game feel: describir qué se probó y qué se vio.

Informe de evidencia obligatorio al cerrar: comando ejecutado, resultado real y archivos afectados. Si un paso no se pudo ejecutar, decirlo; nunca marcarlo como superado.
