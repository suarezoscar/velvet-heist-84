---
trigger: model_decision
description: "Aplicar al crear, modificar, validar o exportar modelos 3D con Blender (bpy, Blender MCP) y al importar .glb en Godot."
---
# Pipeline de assets 3D

## Medidas y estructura
- 1 unidad en Blender = 1 m en Godot.
- Referencias: muro modular 2.0 × 3.0 × 0.2 m; hueco de puerta 1.2 × 2.2 m; personaje cápsula 0.8 m de diámetro × 1.8 m.
- Pivote en la base inferior central del objeto. Aplicar escala y rotación (Ctrl+A) antes de exportar.
- Colisión estática: malla simple con sufijo `-col` junto a la visual (por ejemplo `SafeBox_Mesh` y `SafeBox-col`). Godot crea el `StaticBody3D` al importar.
- Nombres en snake_case, sin espacios ni puntos (se transforman al exportar y rompen referencias).
- Presupuesto de triángulos: lo fija la spec de cada asset. Valores iniciales sugeridos: props ≤ 2.000 y personajes ≤ 5.000; ajústalos en la FEAT.

## Materiales y geometría
- Solo Principled BSDF con valores planos o texturas simples: los nodos procedurales (Color Ramp, ruido, etc.) se pierden al exportar a glTF.
- Solo la paleta "Velvet '84", definida en un único módulo compartido (`tools/blender_scripts/lib/palette.py`); no redefinir colores en cada script:

| Material | Hex | Roughness | Metallic |
|---|---|---|---|
| MahoganyWood | #3B1E14 | 0.35 | 0.0 |
| BrassGold | #D4AF37 | 0.20 | 0.90 |
| Steel80s | #2B2D42 | 0.40 | 0.80 |
| VelvetBlack | #16161A | 0.85 | 0.0 |
| GuardNavy | #1B263B | 0.65 | 0.1 |
| BakeliteBlack | #111113 | 0.15 | 0.05 |

- Modificador BEVEL (width 0.02, segments 2) aplicado antes de exportar.

## Exportación y herramientas
- Exportar siempre por CLI headless (`blender -b -P <script.py>`) con `export_yup=True` y `export_apply=True`. No exportar vía MCP: hay timeouts.
- El MCP de Blender solo para inspección, previews y capturas. Ejecuta código generado por el modelo: mantenerlo en localhost y sin credenciales a mano.
- Tras exportar, comprobar que el `.glb` existe y pesa más de 0 bytes.

## Inmutabilidad y cierre
- En Godot no se escala ni se mueven vértices de un `.glb`. Si tamaño o pivote fallan, se corrige en Blender y se reexporta.
- Un asset no está hecho sin JSON de validación en `pass` (FEAT-001) y un test en Godot que compruebe AABB y origen.
