"""
gen_museum_level.py
Genera la estructura arquitectónica completa, continua y sólida del Museo Metropolitano 1984
para Velvet Heist 84 con orientación y escala arquitectónica correcta (Y-Up en Godot).

Estructura:
- Calzada de asfalto exterior y acera con bordillo.
- Fachada perimetral continua y muros interiores.
- Gran Galería Central (Mármol), Ala de Reliquias (Parqué), Garita (Linóleo) y Bóveda (Velvet).
- Ventana de observación blindada entre garita y galería.
- Vano de bóveda acorazada con pilares de latón.
- Contenedor de acero y palés en el callejón.
"""

import bpy
import math
import os

OUT_PATH = "/home/oscar/Workspace/velvet-heist-84/assets/models/museum_building_84.glb"
MODELS_DIR = "/home/oscar/Workspace/velvet-heist-84/assets/models"

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_pbr_material(name, base_color, roughness=0.5, metallic=0.0, texture_diffuse=None):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = [n for n in nodes if n.type == 'BSDF_PRINCIPLED'][0]
    bsdf.inputs['Base Color'].default_value = base_color
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic

    if texture_diffuse and os.path.exists(texture_diffuse):
        tex_node = nodes.new('ShaderNodeTexImage')
        tex_node.image = bpy.data.images.load(texture_diffuse)
        mat.node_tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
    return mat

def to_blender_pos(x_g, y_g, z_g):
    # Godot: X=right, Y=up, Z=south/forward
    # Blender: X=right, Y=north/forward (-Z_godot), Z=up (Y_godot)
    return (x_g, -z_g, y_g)

def to_blender_size(sx_g, sy_g, sz_g):
    # sx=width, sy=height, sz=depth
    return (sx_g, sz_g, sy_g)

def add_box(name, size_godot, pos_godot, mat=None):
    b_size = to_blender_size(*size_godot)
    b_pos = to_blender_pos(*pos_godot)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=b_pos)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = b_size
    bpy.ops.object.transform_apply(location=False, scale=True)

    # UV Cube projection con escala métrica limpia
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=2.0)
    bpy.ops.object.mode_set(mode='OBJECT')

    if mat:
        obj.data.materials.append(mat)
    return obj

def add_column(name, radius, height, pos_godot, mat=None):
    b_pos = to_blender_pos(*pos_godot)
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=height, location=b_pos)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    return obj

def build_museum_architecture():
    clear_scene()
    print("Building Solid Contiguous 1984 Museum Architecture...")

    # --- MATERIALES PBR ---
    tex_marble = os.path.join(MODELS_DIR, "floor_marble_floor_tiles_06_Diffuse_1k.jpg")
    tex_parquet = os.path.join(MODELS_DIR, "floor_parquet_wood_floor_Diffuse_1k.jpg")
    tex_velvet = os.path.join(MODELS_DIR, "floor_carpet_velour_velvet_Diffuse_1k.jpg")
    tex_wall_wood = os.path.join(MODELS_DIR, "wall_mahogany_wooden_panels_Diffuse_1k.jpg")

    mat_asphalt = create_pbr_material("Mat_Asphalt_Road", (0.07, 0.08, 0.10, 1.0), roughness=0.18, metallic=0.15)
    mat_sidewalk = create_pbr_material("Mat_Sidewalk_Curb", (0.42, 0.43, 0.45, 1.0), roughness=0.75, metallic=0.05)
    mat_marble = create_pbr_material("Mat_Floor_Marble", (0.85, 0.85, 0.88, 1.0), roughness=0.20, metallic=0.05, texture_diffuse=tex_marble)
    mat_parquet = create_pbr_material("Mat_Floor_Parquet", (0.62, 0.44, 0.28, 1.0), roughness=0.35, metallic=0.0, texture_diffuse=tex_parquet)
    mat_linoleum = create_pbr_material("Mat_Floor_Linoleum", (0.28, 0.32, 0.36, 1.0), roughness=0.45, metallic=0.1)
    mat_velvet = create_pbr_material("Mat_Floor_Velvet", (0.55, 0.05, 0.12, 1.0), roughness=0.85, metallic=0.0, texture_diffuse=tex_velvet)

    mat_ext_brick = create_pbr_material("Mat_Ext_Brick", (0.26, 0.14, 0.12, 1.0), roughness=0.80, metallic=0.05)
    mat_int_wall = create_pbr_material("Mat_Int_Mahogany", (0.35, 0.22, 0.14, 1.0), roughness=0.40, metallic=0.05, texture_diffuse=tex_wall_wood)
    mat_vault_steel = create_pbr_material("Mat_Vault_Steel", (0.22, 0.24, 0.26, 1.0), roughness=0.30, metallic=0.85)
    mat_trim_brass = create_pbr_material("Mat_Trim_Brass", (0.85, 0.70, 0.25, 1.0), roughness=0.25, metallic=0.90)
    mat_glass = create_pbr_material("Mat_Glass_Reinforced", (0.2, 0.3, 0.35, 0.4), roughness=0.08, metallic=0.1)
    mat_dumpster = create_pbr_material("Mat_Dumpster_Steel", (0.12, 0.25, 0.15, 1.0), roughness=0.55, metallic=0.6)

    # =========================================================================
    # 1. SUELOS Y CALZADA (Totalmente continuos en Y=0)
    # =========================================================================
    # Calzada del Callejón (Asfalto húmedo): Z de 4.5 a 12.0 (profundidad 7.5m, ancho 26m)
    add_box("Floor_Alley_Road", (26.0, 0.20, 7.5), (0.0, -0.10, 8.25), mat_asphalt)

    # Acera perimetral con bordillo (+0.15m elevado): Z de 3.0 a 4.5 (ancho 26m)
    add_box("Sidewalk_Curb", (26.0, 0.15, 1.5), (0.0, 0.075, 3.75), mat_sidewalk)

    # Suelo Gran Galería Central (Mármol Damero): X: -4.5 a 4.5, Z: -3.5 a 3.0
    add_box("Floor_Great_Gallery", (9.0, 0.20, 6.5), (0.0, 0.05, -0.25), mat_marble)

    # Suelo Ala de Reliquias (Parqué): X: -11.5 a -4.5, Z: -3.5 a 3.0
    add_box("Floor_Relic_Wing", (7.0, 0.20, 6.5), (-8.0, 0.05, -0.25), mat_parquet)

    # Suelo Garita de Seguridad (Linóleo): X: 4.5 a 11.5, Z: -3.5 a 3.0
    add_box("Floor_Security_Lair", (7.0, 0.20, 6.5), (8.0, 0.05, -0.25), mat_linoleum)

    # Suelo Cámara Acorazada (Velvet Carmesí): X: -5.5 a 5.5, Z: -9.5 a -3.5
    add_box("Floor_Vault", (11.0, 0.20, 6.0), (0.0, 0.05, -6.5), mat_velvet)

    # =========================================================================
    # 2. FACHADA EXTERIOR Y MUROS PERIMETRALES
    # Altura estándar de muro = 3.2m (Y: 0.15 a 3.35)
    # Altura de muro frontal sur recortada a 1.3m para visibilidad isométrica
    # =========================================================================
    WALL_H = 3.2
    WALL_Y = WALL_H * 0.5 + 0.15 # 1.75
    FRONT_H = 1.3
    FRONT_Y = FRONT_H * 0.5 + 0.15 # 0.80

    # Fachada Sur (Frontal) - Muro recortado a 1.3m para permitir visibilidad limpia de cámara isométrica
    # Tramo izquierdo: X de -11.5 a 5.8 (longitud 17.3m)
    add_box("Wall_South_Facade_Left", (17.3, FRONT_H, 0.35), (-2.85, FRONT_Y, 3.0), mat_ext_brick)
    # Puerta de Servicio: X de 5.8 a 7.2 (vano de 1.4m)
    # Dintel sobre la puerta de servicio (altura completa 2.6m)
    add_box("Wall_South_Facade_Lintel", (1.4, 0.6, 0.35), (6.5, 2.3, 3.0), mat_ext_brick)
    # Marcos metálicos de la puerta de servicio
    add_box("Frame_Service_Door_L", (0.08, 2.0, 0.38), (5.8, 1.0 + 0.15, 3.0), mat_vault_steel)
    add_box("Frame_Service_Door_R", (0.08, 2.0, 0.38), (7.2, 1.0 + 0.15, 3.0), mat_vault_steel)
    # Tramo derecho de fachada sur: X de 7.2 a 11.5 (longitud 4.3m)
    add_box("Wall_South_Facade_Right", (4.3, FRONT_H, 0.35), (9.35, FRONT_Y, 3.0), mat_ext_brick)

    # Muro Oeste Exterior (X = -11.5, Z: -3.5 a 3.0)
    add_box("Wall_West_Facade", (0.40, WALL_H, 6.85), (-11.5, WALL_Y, -0.25), mat_ext_brick)

    # Muro Este Exterior (X = 11.5, Z: -3.5 a 3.0)
    add_box("Wall_East_Facade", (0.40, WALL_H, 6.85), (11.5, WALL_Y, -0.25), mat_ext_brick)

    # Muros Norte de las alas laterales (Z = -3.5)
    # Tramo Norte Ala Reliquias (X: -11.5 a -5.5)
    add_box("Wall_North_Relics", (6.0, WALL_H, 0.40), (-8.5, WALL_Y, -3.5), mat_ext_brick)
    # Tramo Norte Ala Garita (X: 5.5 a 11.5)
    add_box("Wall_North_Security", (6.0, WALL_H, 0.40), (8.5, WALL_Y, -3.5), mat_ext_brick)

    # =========================================================================
    # 3. LA CÁMARA ACORAZADA (BÓVEDA)
    # =========================================================================
    # Muro Norte Bóveda (Z = -9.5, X: -5.5 a 5.5)
    add_box("Wall_Vault_North", (11.4, WALL_H, 0.50), (0.0, WALL_Y, -9.5), mat_vault_steel)
    # Muro Oeste Bóveda (X = -5.5, Z: -9.5 a -3.5)
    add_box("Wall_Vault_West", (0.50, WALL_H, 6.0), (-5.5, WALL_Y, -6.5), mat_vault_steel)
    # Muro Este Bóveda (X = 5.5, Z: -9.5 a -3.5)
    add_box("Wall_Vault_East", (0.50, WALL_H, 6.0), (5.5, WALL_Y, -6.5), mat_vault_steel)

    # Muro Sur Bóveda / División con Gran Galería (Z = -3.5, con vano de 2.4m en el centro)
    add_box("Wall_Vault_South_L", (4.3, WALL_H, 0.45), (-3.35, WALL_Y, -3.5), mat_vault_steel)
    add_box("Wall_Vault_South_Lintel", (2.4, 0.8, 0.45), (0.0, WALL_H - 0.40 + 0.15, -3.5), mat_vault_steel)
    add_box("Wall_Vault_South_R", (4.3, WALL_H, 0.45), (3.35, WALL_Y, -3.5), mat_vault_steel)

    # Pilares de latón en la entrada acorazada
    add_box("Vault_Pillar_L", (0.25, 2.6, 0.50), (-1.2, 1.3 + 0.15, -3.5), mat_trim_brass)
    add_box("Vault_Pillar_R", (0.25, 2.6, 0.50), (1.2, 1.3 + 0.15, -3.5), mat_trim_brass)

    # =========================================================================
    # 4. TABIQUES INTERIORES Y VENTANA VIGÍA
    # =========================================================================
    # 4.1 Tabique Oeste (Entre Galería y Ala de Reliquias, X = -4.5)
    # Arco clásico de paso (ancho 2.4m en Z = -0.25)
    add_box("Wall_Gallery_Relics_S", (0.25, WALL_H, 2.0), (-4.5, WALL_Y, 2.0), mat_int_wall)
    add_box("Wall_Gallery_Relics_Lintel", (0.25, 0.8, 2.5), (-4.5, WALL_H - 0.40 + 0.15, -0.25), mat_int_wall)
    add_box("Wall_Gallery_Relics_N", (0.25, WALL_H, 2.0), (-4.5, WALL_Y, -2.5), mat_int_wall)

    # 4.2 Tabique Este (Entre Galería y Garita de Seguridad, X = 4.5)
    # Ventana de Observación (ancho 2.0m en Z: -1.0 a 1.0) y Puerta (ancho 1.2m en Z: 1.8 a 3.0)
    add_box("Wall_Security_North", (0.25, WALL_H, 2.5), (4.5, WALL_Y, -2.25), mat_int_wall)
    # Antepecho bajo la ventana (altura 1.0m)
    add_box("Wall_Security_Window_Sill", (0.25, 1.0, 2.0), (4.5, 0.50 + 0.15, 0.0), mat_int_wall)
    # Dintel sobre la ventana
    add_box("Wall_Security_Window_Top", (0.25, 0.8, 2.0), (4.5, WALL_H - 0.40 + 0.15, 0.0), mat_int_wall)
    # Cristal blindado
    add_box("Window_Security_Glass", (0.06, 1.4, 1.96), (4.5, 1.70 + 0.15, 0.0), mat_glass)
    # Dintel sobre la puerta interior de la garita
    add_box("Wall_Security_Door_Lintel", (0.25, 0.9, 1.4), (4.5, WALL_H - 0.45 + 0.15, 2.3), mat_int_wall)

    # =========================================================================
    # 5. DETALLES ARQUITECTÓNICOS Y PROPS ESTRUCTURALES
    # =========================================================================
    # Columnas Neoclásicas en la Galería Central (3 pares a los lados)
    for col_z in [-2.2, -0.25, 1.8]:
        for col_x in [-4.1, 4.1]:
            add_column(f"Column_Pillar_{col_x}_{col_z}", radius=0.22, height=3.2, pos_godot=(col_x, 1.6 + 0.15, col_z), mat=mat_marble)

    # Contenedor de acero pesado en el callejón
    add_box("Exterior_Dumpster", (1.8, 1.2, 1.1), (-6.5, 0.60, 7.2), mat_dumpster)
    add_box("Exterior_Dumpster_Lid", (1.85, 0.10, 1.15), (-6.5, 1.25, 7.2), mat_vault_steel)

    # Palés de madera apilados junto al muro
    add_box("Alley_Pallet_1", (1.2, 0.16, 1.0), (3.0, 0.08 + 0.15, 4.3), mat_parquet)
    add_box("Alley_Pallet_2", (1.2, 0.16, 1.0), (3.0, 0.24 + 0.15, 4.3), mat_parquet)

    # =========================================================================
    # 6. EXPORTAR A GLB
    # =========================================================================
    print("Exporting contiguous museum building to:", OUT_PATH)
    bpy.ops.export_scene.gltf(
        filepath=OUT_PATH,
        export_format='GLB',
        use_selection=False,
        export_apply=True
    )
    print("Export completed successfully!")

if __name__ == "__main__":
    build_museum_architecture()
