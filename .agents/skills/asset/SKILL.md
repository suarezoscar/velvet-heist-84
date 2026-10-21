---
name: asset
description: Flujo completo para crear, validar y exportar un modelo 3D con Blender hacia Godot (script bpy, exportación .glb headless, validación, importación y comprobación de medidas). Úsala siempre que haya que crear o corregir un modelo, material, pivote, escala o colisión, o exportar un .glb, aunque el usuario no diga "asset".
---
# /asset — pipeline de un asset 3D

Lee primero `.agents/rules/02-blender-assets.md`. La ficha de cada asset está en `references/asset-card.md`.

1. **Ficha**: confirma con la FEAT o la ficha las medidas (m), el pivote, el presupuesto de triángulos, los materiales de la paleta y si lleva colisión `-col`.
2. **Script**: crea o ajusta el script `bpy` en `tools/blender_scripts/`. Debe ser idempotente y usar la paleta compartida.
3. **Exportar**: `blender -b -P tools/blender_scripts/<script>.py` (CLI headless, nunca por MCP). Comprueba que el `.glb` existe en `assets/models/` y pesa más de 0 bytes.
4. **Validar**: ejecuta `blender -b -P tools/blender_scripts/validate_asset.py -- assets/models/<nombre>.glb tools/blender_scripts/specs/<nombre>.json` y exige el JSON en `pass: true` (código de salida 0). No se aceptan excepciones.
5. **Previsualizar**: render o captura del asset y de su silueta en cámara ortográfica isométrica (rotación -35.264°, 45°).
6. **Importar en Godot**: `godot --headless --import` y test de AABB y origen del `.glb`.
7. **Informe**: rutas, JSON de validación y captura. Los assets principales (personajes, props clave) requieren la aprobación visual del usuario.

Si las medidas o el pivote fallan, se corrige en Blender y se reexporta. Nunca se arregla en Godot.
