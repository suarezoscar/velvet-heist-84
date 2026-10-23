# Ficha de asset

Vive solo en `tools/blender_scripts/specs/<nombre>.json`. La leen `validate_asset.py`, `validate_all.py` y `tests/unit/test_asset_import.gd`; todos los campos son obligatorios (check `spec_schema`). Ejemplo y tipos: `docs/tasks/FEAT-009-validador-estricto-y-fichas.md`, sección Contratos.

| Campo | Valor |
|---|---|
| Nombre (snake_case) | |
| FEAT | |
| Dimensiones objetivo (m) | |
| Pivote | `bottom_center`, `top_center` o `back_center` (regla 02) |
| Triángulos máximos | |
| Materiales | lista exacta; procedural: claves de `PALETTE`; externo: nombres de sus materiales |
| Colisión `-colonly` | sí / no |
| `source.origin` | procedural / polyhaven / mixamo / otro |
| `source.url` | |
| `source.license` | p. ej. CC0 1.0 (Poly Haven) |
| `source.author` | |
