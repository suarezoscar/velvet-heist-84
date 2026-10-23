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

La ficha de cada asset vive solo en `tools/blender_scripts/specs/<nombre>.json` (formato en `.agents/skills/asset/references/asset-card.md`) y lleva un bloque `source`:
`{ "origin": "procedural" | "polyhaven" | "mixamo" | "otro", "url": str, "license": str, "author": str }`.
Un asset sin `source` completo no está hecho.

## Medidas y estructura
- 1 unidad en Blender = 1 m en Godot.
- Referencias: muro modular 2.0 × 3.0 × 0.2 m; hueco de puerta 1.2 × 2.2 m; personaje cápsula 0.8 m de diámetro × 1.8 m.
- Pivote en la base inferior central: el centro X/Y de la AABB de las mallas visuales en el origen y su mínimo Z en 0. Aplicar escala y rotación (Ctrl+A) antes de exportar.
- Tolerancias del validador: dimensiones ±1 % (mínimo 1 mm), base ±2 mm, centro X/Y ±1 % de la dimensión (mínimo 5 mm).
- Las medidas se consiguen modelando, nunca escalando la malla de forma no uniforme después.
- Colisión estática: malla simple con sufijo `-col` junto a la visual (por ejemplo `SafeBox_Mesh` y `SafeBox-col`). Godot crea el `StaticBody3D` al importar.
- Nombre del asset (archivo `.glb` y `name` de la ficha) en snake_case en minúsculas. Objetos y materiales: solo letras, números y guiones bajos (se admite PascalCase), más el sufijo `-col`/`-colonly` en la colisión; los espacios y puntos se transforman al exportar y rompen referencias.
- Presupuesto de triángulos: lo fija la spec de cada asset. Valores iniciales: props ≤ 2.000 y personajes ≤ 5.000.

## Materiales y geometría
- Solo Principled BSDF con valores planos o texturas de imagen: los nodos procedurales (Color Ramp, ruido, etc.) se pierden al exportar a glTF.
- Los assets procedurales usan solo materiales de la paleta "Velvet '84". Su única fuente es `tools/blender_scripts/lib/palette.py` (`PALETTE`): el nombre del material es la clave exacta y el validador compara Base Color, Roughness, Metallic y Alpha por valor (±0,01).
- Los assets externos conservan sus texturas PBR; su ficha las declara.
- Modificador BEVEL aplicado antes de exportar en los assets procedurales, con width ≤ 0,02 m y ≤ 10 % de la menor dimensión de la pieza, y segments 1–2.

## Exportación y herramientas
- Exportar siempre por CLI headless (`blender -b -P <script.py>`) con `export_yup=True` y `export_apply=True`. El MCP de Blender da timeouts al exportar.
- El MCP de Blender solo para inspección, previews y capturas. Ejecuta código generado por el modelo: mantenerlo en localhost y sin credenciales.
- Tras exportar, comprobar que el `.glb` existe y pesa más de 0 bytes.

## Inmutabilidad y cierre
- En Godot el `.glb` se usa tal cual. Si tamaño o pivote fallan, se corrige en Blender y se reexporta.
- Un asset está hecho con su JSON de validación en `pass` (FEAT-001), su bloque `source` y un test en Godot que compruebe AABB y origen.
