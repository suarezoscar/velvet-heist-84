---
name: asset
description: Flujo completo para crear o adaptar, validar y exportar un modelo 3D con Blender hacia Godot (script bpy o asset de Poly Haven/Mixamo, exportación .glb headless, validación, importación y comprobación de medidas). Úsala siempre que haya que crear o corregir un modelo, textura, material, pivote, escala, colisión o animación, o exportar un .glb.
---
# /asset — pipeline de un asset 3D

Lee primero `.agents/rules/02-blender-assets.md`. La ficha de cada asset sigue `references/asset-card.md`.

1. **Ficha**: confirma con la FEAT las medidas (m), el pivote, el presupuesto de triángulos, los materiales, la colisión `-col` y el origen (`procedural`, `polyhaven`, `mixamo`). Escribe o actualiza `tools/blender_scripts/specs/<nombre>.json` con su bloque `source` (origen, URL, licencia, autor).
2. **Producir**:
   - Procedural: script `bpy` idempotente en `tools/blender_scripts/` que usa la paleta compartida.
   - Externo: script `bpy` que importa el original, lo ajusta a medidas, pivote y nombres, y enlaza sus texturas desde `assets/textures/<material>/` (una sola copia por textura).
3. **Exportar**: `blender -b -P tools/blender_scripts/<script>.py` (CLI headless). Comprueba que el `.glb` existe en `assets/models/` y pesa más de 0 bytes.
4. **Validar**: `blender -b -P tools/blender_scripts/validate_asset.py -- assets/models/<nombre>.glb tools/blender_scripts/specs/<nombre>.json` con JSON en `pass: true` y código de salida 0.
5. **Previsualizar**: render del asset y de su silueta en cámara ortográfica isométrica (rotación -35.264°, 45°).
6. **Importar en Godot**: `./tools/ci/import.sh` y test de AABB y origen del `.glb`.
7. **Informe**: rutas, JSON de validación, bloque `source` y render. Los assets principales (personajes, props clave) requieren la aprobación visual del usuario.

Si las medidas o el pivote fallan, se corrige en Blender y se reexporta.
