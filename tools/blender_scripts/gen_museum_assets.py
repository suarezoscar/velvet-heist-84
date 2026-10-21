"""
gen_museum_assets.py
Genera los modelos 3D procedurales para el Museo de 1984:
1. cctv_camera_84.glb (Cámara de seguridad analógica ochentera con lente, soporte y LED)
2. museum_display_case.glb (Vitrina de museo clásica con pedestal de caoba y campana de cristal)

Cumple con la regla 02 y FEAT-001 usando lib.palette.
"""

import math
import os
import sys
from pathlib import Path

# Configurar path para importar lib/palette.py
SCRIPT_DIR = Path(__file__).resolve().parent
LIB_DIR = SCRIPT_DIR / "lib"
for p in [str(SCRIPT_DIR), str(LIB_DIR)]:
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    import bpy
    from lib.palette import create_pbr_material
except ImportError:
    print("Error: Este script debe ejecutarse dentro de Blender.")
    sys.exit(1)

OUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
)
os.makedirs(OUT_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build_cctv_camera():
    clear_scene()
    print("Building CCTV Camera '84...")

    # Materiales de la paleta oficial
    mat_casing = create_pbr_material("CctvCasing", "CctvCasing")
    mat_black = create_pbr_material("BakeliteBlack", "BakeliteBlack")
    mat_lens = create_pbr_material("CctvLens", "CctvLens")
    mat_led = create_pbr_material("CctvLed", "CctvLed")
    mat_metal_arm = create_pbr_material("Steel80s", "Steel80s")

    # 1. Base / Soporte a la pared
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.08, depth=0.03, location=(0.0, 0.0, 0.0), rotation=(math.pi / 2, 0, 0)
    )
    bracket_base = bpy.context.active_object
    bracket_base.name = "CCTV_WallPlate"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    bracket_base.data.materials.append(mat_metal_arm)

    # Brazo articulado en L
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.025, depth=0.22, location=(0.0, 0.10, 0.0), rotation=(math.pi / 2, 0, 0)
    )
    arm_horizontal = bpy.context.active_object
    arm_horizontal.name = "CCTV_ArmHorizontal"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    arm_horizontal.data.materials.append(mat_metal_arm)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(0.0, 0.20, 0.0))
    swivel_joint = bpy.context.active_object
    swivel_joint.name = "CCTV_SwivelJoint"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    swivel_joint.data.materials.append(mat_metal_arm)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.025, depth=0.12, location=(0.0, 0.20, -0.06)
    )
    arm_down = bpy.context.active_object
    arm_down.name = "CCTV_ArmDown"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    arm_down.data.materials.append(mat_metal_arm)

    # 2. Cuerpo de la cámara
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.24, -0.16), scale=(0.16, 0.36, 0.12)
    )
    casing = bpy.context.active_object
    casing.name = "CCTV_Body"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    casing.data.materials.append(mat_casing)

    # Visera superior
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.25, -0.095), scale=(0.18, 0.38, 0.015)
    )
    sun_shield = bpy.context.active_object
    sun_shield.name = "CCTV_SunShield"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    sun_shield.data.materials.append(mat_black)

    # Frontal negro del objetivo
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.421, -0.16), scale=(0.155, 0.01, 0.115)
    )
    front_plate = bpy.context.active_object
    front_plate.name = "CCTV_FrontPlate"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    front_plate.data.materials.append(mat_black)

    # Lente cilíndrica con zoom
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.045, depth=0.07, location=(0.0, 0.45, -0.16), rotation=(math.pi / 2, 0, 0)
    )
    lens_barrel = bpy.context.active_object
    lens_barrel.name = "CCTV_LensBarrel"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    lens_barrel.data.materials.append(mat_black)

    # Cristal de la lente frontal
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.038, depth=0.01, location=(0.0, 0.485, -0.16), rotation=(math.pi / 2, 0, 0)
    )
    lens_glass = bpy.context.active_object
    lens_glass.name = "CCTV_LensGlass"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    lens_glass.data.materials.append(mat_lens)

    # LED rojo indicador analógico de grabación
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.012, location=(-0.055, 0.43, -0.12))
    rec_led = bpy.context.active_object
    rec_led.name = "CCTV_RecordLED"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    rec_led.data.materials.append(mat_led)

    # 3. Collision shape (-col para Godot)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.24, -0.12), scale=(0.22, 0.48, 0.26)
    )
    col = bpy.context.active_object
    col.name = "CCTV_Camera-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    out_path = os.path.join(OUT_DIR, "cctv_camera_84.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )
    print(f"Exported {out_path} successfully!")


def build_museum_display_case():
    clear_scene()
    print("Building Museum Display Case '84...")

    # Materiales
    mat_wood = create_pbr_material("MahoganyWood", "MahoganyWood")
    mat_velvet = create_pbr_material("CarpetWine", "CarpetWine")
    mat_brass = create_pbr_material("BrassGold", "BrassGold")
    mat_glass = create_pbr_material("GlassClear", "GlassClear")

    # 1. Pedestal de madera noble (0.8m x 0.8m x 0.85m alto)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.425), scale=(0.80, 0.80, 0.85)
    )
    base = bpy.context.active_object
    base.name = "DisplayCase_Base"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    base.data.materials.append(mat_wood)

    # Moldura zócalo inferior
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.06), scale=(0.86, 0.86, 0.12)
    )
    trim_bottom = bpy.context.active_object
    trim_bottom.name = "DisplayCase_TrimBottom"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    trim_bottom.data.materials.append(mat_wood)

    # Moldura superior cornisa
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.85), scale=(0.84, 0.84, 0.06)
    )
    trim_top = bpy.context.active_object
    trim_top.name = "DisplayCase_TrimTop"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    trim_top.data.materials.append(mat_wood)

    # Cojín de terciopelo interior
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.89), scale=(0.68, 0.68, 0.04)
    )
    cushion = bpy.context.active_object
    cushion.name = "DisplayCase_Cushion"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    cushion.data.materials.append(mat_velvet)

    # Placa conmemorativa de latón en el frontal
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, -0.405, 0.65), scale=(0.24, 0.01, 0.10)
    )
    brass_plaque = bpy.context.active_object
    brass_plaque.name = "DisplayCase_BrassPlaque"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    brass_plaque.data.materials.append(mat_brass)

    # 2. Campana de cristal transparente (0.72m x 0.72m x 0.61m alto)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 1.205), scale=(0.72, 0.72, 0.61)
    )
    glass = bpy.context.active_object
    glass.name = "DisplayCase_Glass"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    glass.data.materials.append(mat_glass)

    # Perfiles de latón en las 4 esquinas del cristal
    for cx in [-0.355, 0.355]:
        for cy in [-0.355, 0.355]:
            bpy.ops.mesh.primitive_cube_add(
                size=1.0, location=(cx, cy, 1.205), scale=(0.02, 0.02, 0.61)
            )
            corner = bpy.context.active_object
            corner.name = f"DisplayCase_BrassCorner_{'pos' if cx > 0 else 'neg'}_{'pos' if cy > 0 else 'neg'}"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            corner.data.materials.append(mat_brass)

    # 3. Colisión física del pedestal (-col)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.75), scale=(0.84, 0.84, 1.50)
    )
    col = bpy.context.active_object
    col.name = "DisplayCase-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    out_path = os.path.join(OUT_DIR, "museum_display_case.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )
    print(f"Exported {out_path} successfully!")


if __name__ == "__main__":
    build_cctv_camera()
    build_museum_display_case()
