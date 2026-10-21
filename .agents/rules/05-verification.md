---
trigger: model_decision
description: "Aplicar al terminar una tarea, validar código, ejecutar tests o lint, importar assets, preparar CI o reportar evidencias de verificación."
---
# Verificación

Los comandos concretos viven en `tools/ci/` y se fijan en FEAT-000. Orden de comprobación:

1. Importar el proyecto en headless: `godot --headless --import`.
2. Parsear cada `.gd` modificado: `godot --headless --check-only --script res://ruta/archivo.gd`. Un `godot --headless --quit` por sí solo no garantiza que se carguen todos los scripts.
3. Lint y formato con gdtoolkit (`gdlint`, `gdformat --check`) cuando esté configurado.
4. Tests del framework elegido en FEAT-000 (GdUnit4 o GUT), siempre en headless.
5. Validador de assets (FEAT-001) sobre cada `.glb` o script de Blender modificado.
6. Prueba manual breve cuando la tarea afecte al game feel: describir qué se probó y qué se vio.

Informe de evidencia obligatorio al cerrar: comando ejecutado, resultado real y archivos afectados. Si un paso no se pudo ejecutar, decirlo; nunca marcarlo como superado.
