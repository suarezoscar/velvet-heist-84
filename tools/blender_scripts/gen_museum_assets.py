"""
gen_museum_assets.py
Genera los modelos 3D procedurales para el Museo de 1984:
1. cctv_camera_84.glb (Cámara de seguridad analógica ochentera con lente, soporte y LED)
2. museum_display_case.glb (Vitrina de museo clásica con pedestal de caoba y campana de cristal)
"""

import bpy
import math
import os

OUT_DIR = "/home/oscar/Workspace/velvet-heist-84/assets/models"

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_pbr_mat(name, base_color, roughness=0.5, metallic=0.0, emission=None, emission_strength=1.0, alpha=1.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = [n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'][0]
    bsdf.inputs['Base Color'].default_value = base_color
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    if 'Alpha' in bsdf.inputs:
        bsdf.inputs['Alpha'].default_value = alpha
        if alpha < 1.0:
            mat.blend_method = 'BLEND'
    if emission and 'Emission Color' in bsdf.inputs:
        bsdf.inputs['Emission Color'].default_value = emission
        if 'Emission Strength' in bsdf.inputs:
            bsdf.inputs['Emission Strength'].default_value = emission_strength
    return mat

def build_cctv_camera():
    clear_scene()
    print("Building CCTV Camera '84...")

    # Materiales
    mat_casing = create_pbr_mat("Mat_CCTV_Casing", (0.84, 0.82, 0.76, 1.0), roughness=0.35, metallic=0.1) # Beige ochentero
    mat_black = create_pbr_mat("Mat_CCTV_Black", (0.06, 0.06, 0.07, 1.0), roughness=0.6, metallic=0.3)
    mat_lens = create_pbr_mat("Mat_CCTV_Lens", (0.02, 0.03, 0.05, 1.0), roughness=0.05, metallic=0.9)
    mat_led = create_pbr_mat("Mat_CCTV_LED", (1.0, 0.1, 0.1, 1.0), roughness=0.2, emission=(1.0, 0.0, 0.0, 1.0), emission_strength=4.0)
    mat_metal_arm = create_pbr_mat("Mat_CCTV_Bracket", (0.35, 0.35, 0.38, 1.0), roughness=0.3, metallic=0.85)

    # 1. Base / Soporte a la pared (Mounting bracket)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.03, location=(0.0, 0.0, 0.0), rotation=(math.pi/2, 0, 0))
    bracket_base = bpy.context.active_object
    bracket_base.name = "CCTV_WallPlate"
    bracket_base.data.materials.append(mat_metal_arm)

    # Brazo articulado en L
    bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=0.22, location=(0.0, 0.10, 0.0), rotation=(math.pi/2, 0, 0))
    arm_horizontal = bpy.context.active_object
    arm_horizontal.name = "CCTV_ArmHorizontal"
    arm_horizontal.data.materials.append(mat_metal_arm)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(0.0, 0.20, 0.0))
    swivel_joint = bpy.context.active_object
    swivel_joint.name = "CCTV_SwivelJoint"
    swivel_joint.data.materials.append(mat_metal_arm)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=0.12, location=(0.0, 0.20, -0.06))
    arm_down = bpy.context.active_object
    arm_down.name = "CCTV_ArmDown"
    arm_down.data.materials.append(mat_metal_arm)

    # 2. Cuerpo de la cámara (Prisma rectangular clásico)
    # Dimensiones: 0.36m largo (Y), 0.16m ancho (X), 0.12m alto (Z)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.24, -0.16))
    casing = bpy.context.active_object
    casing.name = "CCTV_Body"
    casing.scale = (0.16, 0.36, 0.12)
    bpy.ops.object.transform_apply(scale=True)
    casing.data.materials.append(mat_casing)

    # Visera superior antisol / protección
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.25, -0.095))
    sun_shield = bpy.context.active_object
    sun_shield.name = "CCTV_SunShield"
    sun_shield.scale = (0.18, 0.38, 0.015)
    bpy.ops.object.transform_apply(scale=True)
    sun_shield.data.materials.append(mat_black)

    # Frontal negro del objetivo
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.421, -0.16))
    front_plate = bpy.context.active_object
    front_plate.name = "CCTV_FrontPlate"
    front_plate.scale = (0.155, 0.01, 0.115)
    bpy.ops.object.transform_apply(scale=True)
    front_plate.data.materials.append(mat_black)

    # Lente cilíndrica con zoom
    bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.07, location=(0.0, 0.45, -0.16), rotation=(math.pi/2, 0, 0))
    lens_barrel = bpy.context.active_object
    lens_barrel.name = "CCTV_LensBarrel"
    lens_barrel.data.materials.append(mat_black)

    # Cristal de la lente frontal
    bpy.ops.mesh.primitive_cylinder_add(radius=0.038, depth=0.01, location=(0.0, 0.485, -0.16), rotation=(math.pi/2, 0, 0))
    lens_glass = bpy.context.active_object
    lens_glass.name = "CCTV_LensGlass"
    lens_glass.data.materials.append(mat_lens)

    # LED rojo indicador analógico de grabación
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.012, location=(-0.055, 0.43, -0.12))
    rec_led = bpy.context.active_object
    rec_led.name = "CCTV_RecordLED"
    rec_led.data.materials.append(mat_led)

    # 3. Collision shape (-colonly para Godot)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.24, -0.12))
    col = bpy.context.active_object
    col.name = "CCTV_Camera-colonly"
    col.scale = (0.22, 0.48, 0.26)
    bpy.ops.object.transform_apply(scale=True)

    # Exportar GLB
    out_path = os.path.join(OUT_DIR, "cctv_camera_84.glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print(f"Exported {out_path} successfully!")

def build_museum_display_case():
    clear_scene()
    print("Building Museum Display Case '84...")

    # Materiales
    mat_wood = create_pbr_mat("Mat_Vitrine_Wood", (0.14, 0.07, 0.04, 1.0), roughness=0.35, metallic=0.0) # Caoba oscura barnizada
    mat_velvet = create_pbr_mat("Mat_Vitrine_Velvet", (0.42, 0.04, 0.07, 1.0), roughness=0.85, metallic=0.0) # Terciopelo carmesí
    mat_brass = create_pbr_mat("Mat_Vitrine_Brass", (0.95, 0.78, 0.25, 1.0), roughness=0.20, metallic=0.90) # Latón dorado
    mat_glass = create_pbr_mat("Mat_Vitrine_Glass", (0.85, 0.92, 0.95, 1.0), roughness=0.05, metallic=0.1, alpha=0.35) # Cristal

    # 1. Pedestal de madera noble (0.8m x 0.8m x 0.85m alto)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.425))
    base = bpy.context.active_object
    base.name = "DisplayCase_Base"
    base.scale = (0.80, 0.80, 0.85)
    bpy.ops.object.transform_apply(scale=True)
    base.data.materials.append(mat_wood)

    # Moldura zócalo inferior
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.06))
    trim_bottom = bpy.context.active_object
    trim_bottom.name = "DisplayCase_TrimBottom"
    trim_bottom.scale = (0.86, 0.86, 0.12)
    bpy.ops.object.transform_apply(scale=True)
    trim_bottom.data.materials.append(mat_wood)

    # Moldura superior cornisa
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.85))
    trim_top = bpy.context.active_object
    trim_top.name = "DisplayCase_TrimTop"
    trim_top.scale = (0.84, 0.84, 0.06)
    bpy.ops.object.transform_apply(scale=True)
    trim_top.data.materials.append(mat_wood)

    # Cojín de terciopelo interior sobre el que reposa el objeto de valor
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.89))
    cushion = bpy.context.active_object
    cushion.name = "DisplayCase_Cushion"
    cushion.scale = (0.68, 0.68, 0.04)
    bpy.ops.object.transform_apply(scale=True)
    cushion.data.materials.append(mat_velvet)

    # Placa conmemorativa de latón en el frontal
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.405, 0.65))
    brass_plaque = bpy.context.active_object
    brass_plaque.name = "DisplayCase_BrassPlaque"
    brass_plaque.scale = (0.24, 0.01, 0.10)
    bpy.ops.object.transform_apply(scale=True)
    brass_plaque.data.materials.append(mat_brass)

    # 2. Campana de cristal transparente (0.72m x 0.72m x 0.65m alto)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 1.205))
    glass = bpy.context.active_object
    glass.name = "DisplayCase_Glass"
    glass.scale = (0.72, 0.72, 0.61)
    bpy.ops.object.transform_apply(scale=True)
    glass.data.materials.append(mat_glass)

    # Perfiles de latón en las 4 esquinas del cristal
    for cx in [-0.355, 0.355]:
        for cy in [-0.355, 0.355]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, 1.205))
            corner = bpy.context.active_object
            corner.name = f"DisplayCase_BrassCorner_{cx}_{cy}"
            corner.scale = (0.02, 0.02, 0.61)
            bpy.ops.object.transform_apply(scale=True)
            corner.data.materials.append(mat_brass)

    # 3. Colisión física del pedestal (-colonly)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.75))
    col = bpy.context.active_object
    col.name = "DisplayCase-colonly"
    col.scale = (0.84, 0.84, 1.50)
    bpy.ops.object.transform_apply(scale=True)

    # Exportar GLB
    out_path = os.path.join(OUT_DIR, "museum_display_case.glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print(f"Exported {out_path} successfully!")

if __name__ == "__main__":
    build_cctv_camera()
    build_museum_display_case()
