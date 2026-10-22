---
trigger: model_decision
description: "Aplicar al crear, adaptar, validar o exportar modelos 3D, texturas o animaciones (bpy, Blender MCP, Poly Haven, Mixamo) y al importar .glb en Godot."
---
# Pipeline de assets 3D

## Origen de cada asset
| Tipo | Origen | Cómo |
|---|---|---|
| Props, mobiliario, muros y suelos modulares | Procedural | Script `bpy` idempotente en `tools/blender_scripts/` |
| Props detallados | Modelo CC0 de Poly Haven | Se adapta en Blender a medidas, pivote y nombres de esta regla y se valida igual |
| Personajes y animaciones | Mixamo | Importación y retarget en Blender; miran a +Z (`VisualRoot` gira 180°) |
| Texturas PBR | Poly Haven (CC0) | Una sola copia en `assets/textures/<material>/`; materiales y modelos la referencian |

La ficha de cada asset (`tools/blender_scripts/specs/<nombre>.json`) lleva un bloque `source`:
`{ "origin": "procedural" | "polyhaven" | "mixamo" | "otro", "url": str, "license": str, "author": str }`.
Un asset sin `source` completo no está hecho.

## Medidas y estructura
- 1 unidad en Blender = 1 m en Godot.
- Referencias: muro modular 2.0 × 3.0 × 0.2 m; hueco de puerta 1.2 × 2.2 m; personaje cápsula 0.8 m de diámetro × 1.8 m.
- Pivote en la base inferior central del objeto. Aplicar escala y rotación (Ctrl+A) antes de exportar.
- Colisión estática: malla simple con sufijo `-col` junto a la visual (por ejemplo `SafeBox_Mesh` y `SafeBox-col`). Godot crea el `StaticBody3D` al importar.
- Nombres en snake_case, solo letras, números y guiones bajos (los espacios y puntos se transforman al exportar y rompen referencias).
- Presupuesto de triángulos: lo fija la spec de cada asset. Valores iniciales: props ≤ 2.000 y personajes ≤ 5.000.

## Materiales y geometría
- Solo Principled BSDF con valores planos o texturas de imagen: los nodos procedurales (Color Ramp, ruido, etc.) se pierden al exportar a glTF.
- Los assets procedurales usan solo la paleta "Velvet '84", definida en `tools/blender_scripts/lib/palette.py`:

| Material | Hex | Roughness | Metallic |
|---|---|---|---|
| MahoganyWood | #3B1E14 | 0.35 | 0.0 |
| BrassGold | #D4AF37 | 0.20 | 0.90 |
| Steel80s | #2B2D42 | 0.40 | 0.80 |
| VelvetBlack | #16161A | 0.85 | 0.0 |
| GuardNavy | #1B263B | 0.65 | 0.1 |
| BakeliteBlack | #111113 | 0.15 | 0.05 |

- Los assets externos conservan sus texturas PBR; su ficha las declara.
- Modificador BEVEL (width 0.02, segments 2) aplicado antes de exportar en los assets procedurales.

## Exportación y herramientas
- Exportar siempre por CLI headless (`blender -b -P <script.py>`) con `export_yup=True` y `export_apply=True`. El MCP de Blender da timeouts al exportar.
- El MCP de Blender solo para inspección, previews y capturas. Ejecuta código generado por el modelo: mantenerlo en localhost y sin credenciales.
- Tras exportar, comprobar que el `.glb` existe y pesa más de 0 bytes.

## Inmutabilidad y cierre
- En Godot el `.glb` se usa tal cual. Si tamaño o pivote fallan, se corrige en Blender y se reexporta.
- Un asset está hecho con su JSON de validación en `pass` (FEAT-001), su bloque `source` y un test en Godot que compruebe AABB y origen.
