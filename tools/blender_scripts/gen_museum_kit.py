"""
gen_museum_kit.py
Kit modular del museo (#177, fase 2): piezas sueltas que visten los muros, que siguen siendo
cajas de Godot pintadas por shader. Low-poly, de cajas biseladas, pensadas para el cel-shading.

- door_frame_<familia>_<12|24>: marco de un paso de 1,2 o 2,4 m. El muro de Godot se alarga
  medio grueso (0,15 m) dentro del hueco, así que el paso libre es el ancho menos 0,3 m y las
  jambas se apoyan sobre esos extremos sin estrecharlo. Familias: public (caoba con clave de
  latón), service (acero fino; el dintel deja pasar la hoja de 2,3 m de la garita) y vault
  (acero grueso con pernos de latón).
- wall_pilaster: pilastra de mármol para las esquinas y cruces de las salas públicas.
- window_frame_service: marco de acero con parteluz sobre el alféizar (1,0 m) de la ventana.

Todo con pivote bottom_center, eje X a lo largo del muro y eje Y (Blender) a través de él.
Uso: blender -b -P tools/blender_scripts/gen_museum_kit.py
"""

import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
for p in [str(SCRIPT_DIR), str(SCRIPT_DIR / "lib")]:
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    import bpy
    from lib.palette import create_pbr_material
    from lib.blender_utils import center_by_pivot
except ImportError:
    print("Error: Este script debe ejecutarse dentro de Blender.")
    sys.exit(1)

OUT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", "assets", "models"))
WALL_THICKNESS = 0.3
BEVEL = 0.01
# Paso libre de cada ancho de puerta del JSON (el muro entra 0,15 m por cada lado)
INNER = {"12": 1.2 - WALL_THICKNESS, "24": 2.4 - WALL_THICKNESS}


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def box(name, size, center, material):
    """Caja de size (x, y, z) centrada en center, biselada y con su material."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    width = min(BEVEL, 0.1 * min(size))
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(material)
    return obj


def export(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name.title().replace("_", "") + "_Mesh"
    center_by_pivot([joined], "bottom_center")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    path = os.path.join(OUT_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_apply=True, export_yup=True
    )
    print(f"Exportado {path}")


def jambs_and_head(inner, jamb, depth, height, head, mat, prefix):
    """Dos jambas sobre los extremos del muro y el dintel que las une."""
    half = inner * 0.5 + jamb * 0.5
    outer = inner + jamb * 2.0
    return [
        box(f"{prefix}JambL", (jamb, depth, height), (-half, 0.0, height * 0.5), mat),
        box(f"{prefix}JambR", (jamb, depth, height), (half, 0.0, height * 0.5), mat),
        box(f"{prefix}Head", (outer, depth, head), (0.0, 0.0, height - head * 0.5), mat),
    ]


def door_frame_public(key):
    clear_scene()
    wood = create_pbr_material("MahoganyWood", "MahoganyWood")
    brass = create_pbr_material("BrassGold", "BrassGold")
    inner = INNER[key]
    objs = jambs_and_head(inner, 0.12, 0.42, 2.5, 0.12, wood, "Frame")
    for side in (-1.0, 1.0):
        x = side * (inner * 0.5 + 0.07)
        objs.append(box(f"Plinth{side:+.0f}", (0.14, 0.44, 0.22), (x, 0.0, 0.11), wood))
    objs.append(box("Keystone", (0.18, 0.46, 0.14), (0.0, 0.0, 2.51), brass))
    export(objs, f"door_frame_public_{key}")


def door_frame_service(key):
    clear_scene()
    steel = create_pbr_material("Steel80s", "Steel80s")
    objs = jambs_and_head(INNER[key], 0.08, 0.4, 2.4, 0.08, steel, "Frame")
    export(objs, f"door_frame_service_{key}")


def door_frame_vault(key):
    clear_scene()
    steel = create_pbr_material("Steel80s", "Steel80s")
    brass = create_pbr_material("BrassGold", "BrassGold")
    inner = INNER[key]
    objs = jambs_and_head(inner, 0.18, 0.42, 2.6, 0.2, steel, "Frame")
    for side in (-1.0, 1.0):
        x = side * (inner * 0.5 + 0.09)
        for z in (0.4, 1.2, 2.0):
            name = f"Bolt{side:+.0f}_{int(z * 10)}"
            objs.append(box(name, (0.06, 0.44, 0.06), (x, 0.0, z), brass))
    export(objs, f"door_frame_vault_{key}")


def wall_pilaster():
    clear_scene()
    marble = create_pbr_material("MarbleWhite", "MarbleWhite")
    objs = [
        box("Base", (0.42, 0.42, 0.2), (0.0, 0.0, 0.1), marble),
        box("Shaft", (0.38, 0.38, 2.76), (0.0, 0.0, 1.58), marble),
        box("Capital", (0.42, 0.42, 0.24), (0.0, 0.0, 3.08), marble),
    ]
    export(objs, "wall_pilaster")


def window_frame_service():
    clear_scene()
    steel = create_pbr_material("Steel80s", "Steel80s")
    inner = 2.0 - WALL_THICKNESS
    objs = jambs_and_head(inner, 0.08, 0.4, 1.5, 0.08, steel, "Window")
    objs.append(box("Rail", (inner, 0.4, 0.06), (0.0, 0.0, 0.03), steel))
    objs.append(box("Mullion", (0.05, 0.36, 1.36), (0.0, 0.0, 0.74), steel))
    objs.append(box("Transom", (inner, 0.36, 0.05), (0.0, 0.0, 1.0), steel))
    export(objs, "window_frame_service")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for key in INNER:
        door_frame_public(key)
        door_frame_service(key)
        door_frame_vault(key)
    wall_pilaster()
    window_frame_service()


if __name__ == "__main__":
    main()
