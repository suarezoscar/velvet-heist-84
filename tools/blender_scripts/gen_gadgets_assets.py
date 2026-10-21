#!/usr/bin/env python3
"""
tools/blender_scripts/gen_gadgets_assets.py
Genera proceduralmente (headless bpy) los 5 assets de gadgets analógicos de 1984 para Velvet Heist '84 (FEAT-004):
- alarm_clock.glb
- wood_wedge.glb
- stethoscope.glb
- inspection_mirror.glb
- tripwire_bell.glb

Cumple estrictamente con la regla 02 y FEAT-004:
- Paleta unificada PBR 'Velvet 84' desde lib/palette.py (sin nodos procedurales)
- Escala métrica 1 unidad = 1 metro
- Pivote en la base inferior central (Z=0.0, Centro XY=(0,0))
- Transformaciones aplicadas (escala 1,1,1 y rotación 0,0,0)
- Convención de colisión '-col' para Godot 4
- Nombres estrictamente en snake_case sin espacios ni puntos
- Modificador Bevel horneado
- Presupuestos de polígonos estrictamente respetados (todos <= presupuesto de ficha)
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
    import mathutils
    from lib.palette import PALETTE, create_pbr_material
except ImportError:
    print("Error: Este script debe ejecutarse dentro de Blender headless (blender -b -P <script.py>).")
    sys.exit(1)

OUTPUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
)
os.makedirs(OUTPUT_DIR, exist_ok=True)


def clear_scene():
    """Limpia todos los bloques de datos y objetos de la escena."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_glb(filename: str):
    """Exporta la escena activa a .glb aplicando transformaciones y coordenadas Y-up."""
    filepath = os.path.join(OUTPUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
    )
    print(f"[Blender CLI] Asset exportado con éxito: {filepath} ({os.path.getsize(filepath)} bytes)")


def apply_bevel(obj, width=0.01, segments=1):
    """Aplica modificador Bevel y hornea la geometría para bordes redondeados analógicos."""
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new(name="bevel_mod", type="BEVEL")
    mod.width = width
    mod.segments = segments
    bpy.ops.object.modifier_apply(modifier="bevel_mod")


def compute_visual_bounds(visual_objects):
    """Calcula la caja delimitadora AABB de una lista de objetos visuales."""
    all_corners = []
    for obj in visual_objects:
        if obj.type == "MESH" and obj.bound_box:
            for corner in obj.bound_box:
                world_corner = obj.matrix_world @ mathutils.Vector(corner)
                all_corners.append(world_corner)

    if not all_corners:
        return mathutils.Vector((0, 0, 0)), mathutils.Vector((0, 0, 0))

    min_v = mathutils.Vector((
        min(v.x for v in all_corners),
        min(v.y for v in all_corners),
        min(v.z for v in all_corners),
    ))
    max_v = mathutils.Vector((
        max(v.x for v in all_corners),
        max(v.y for v in all_corners),
        max(v.z for v in all_corners),
    ))
    return min_v, max_v


def normalize_and_apply_visuals(visual_objects, exp_x: float, exp_y: float, exp_z: float):
    """
    Ajusta con precisión milimétrica la escala y posición de los objetos visuales para
    cumplir exactamente la ficha técnica:
    - Base inferior en Z = 0.0
    - Centrado perfecto en XY = (0.0, 0.0)
    - Dimensiones totales exactas (exp_x, exp_y, exp_z)
    - Escala (1, 1, 1) y rotación (0, 0, 0) aplicadas
    """
    # 1. Aplicar transformaciones previas a nivel de objeto
    for obj in visual_objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.select_set(False)

    # 2. Medir bounding box actual
    min_v, max_v = compute_visual_bounds(visual_objects)
    curr_w = max_v.x - min_v.x
    curr_d = max_v.y - min_v.y
    curr_h = max_v.z - min_v.z

    scale_x = exp_x / curr_w if curr_w > 1e-5 else 1.0
    scale_y = exp_y / curr_d if curr_d > 1e-5 else 1.0
    scale_z = exp_z / curr_h if curr_h > 1e-5 else 1.0

    curr_cx = (min_v.x + max_v.x) / 2.0
    curr_cy = (min_v.y + max_v.y) / 2.0
    curr_min_z = min_v.z

    # 3. Transformar vértices de cada malla directamente
    for obj in visual_objects:
        if obj.type == "MESH" and obj.data:
            mesh = obj.data
            for v in mesh.vertices:
                v.co.x = (v.co.x - curr_cx) * scale_x
                v.co.y = (v.co.y - curr_cy) * scale_y
                v.co.z = (v.co.z - curr_min_z) * scale_z
            mesh.update()
            obj.location = (0.0, 0.0, 0.0)
            obj.rotation_euler = (0.0, 0.0, 0.0)
            obj.scale = (1.0, 1.0, 1.0)


# =============================================================================
# 1. Despertador Mecánico Vintage (alarm_clock.glb)
# Dimensiones: (0.18, 0.12, 0.22) m | Materiales: BrassGold, BakeliteBlack, Steel80s
# Colisión: alarm_clock-col | Presupuesto: 800 tris
# =============================================================================
def generate_alarm_clock(filename: str = "alarm_clock.glb"):
    clear_scene()
    mat_brass = create_pbr_material("BrassGold", "BrassGold")
    mat_bakelite = create_pbr_material("BakeliteBlack", "BakeliteBlack")
    mat_steel = create_pbr_material("Steel80s", "Steel80s")

    visual_objects = []

    # Cuerpo cilíndrico principal (orientado en eje Y, mirando al frente +Y)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.065, depth=0.065, location=(0.0, 0.0, 0.11), rotation=(1.5708, 0.0, 0.0)
    )
    casing = bpy.context.active_object
    casing.name = "alarm_clock_casing"
    casing.data.materials.append(mat_steel)
    apply_bevel(casing, width=0.006, segments=1)
    visual_objects.append(casing)

    # Bisel dorado frontal
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.068, depth=0.015, location=(0.0, 0.038, 0.11), rotation=(1.5708, 0.0, 0.0)
    )
    bezel = bpy.context.active_object
    bezel.name = "alarm_clock_bezel"
    bezel.data.materials.append(mat_brass)
    apply_bevel(bezel, width=0.003, segments=1)
    visual_objects.append(bezel)

    # Dial frontal analógico
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.060, depth=0.005, location=(0.0, 0.046, 0.11), rotation=(1.5708, 0.0, 0.0)
    )
    dial = bpy.context.active_object
    dial.name = "alarm_clock_dial"
    dial.data.materials.append(mat_bakelite)
    visual_objects.append(dial)

    # Agujas horaria y minutera doradas
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.050, 0.125), scale=(0.005, 0.003, 0.035)
    )
    hand_min = bpy.context.active_object
    hand_min.name = "alarm_clock_hand_min"
    hand_min.data.materials.append(mat_brass)
    visual_objects.append(hand_min)

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.010, 0.049, 0.110), scale=(0.024, 0.003, 0.005)
    )
    hand_hr = bpy.context.active_object
    hand_hr.name = "alarm_clock_hand_hr"
    hand_hr.data.materials.append(mat_brass)
    visual_objects.append(hand_hr)

    # 2 Campanas superiores de latón (izquierda y derecha)
    for side, sign in [("l", -1.0), ("r", 1.0)]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=10, radius=0.032, depth=0.025,
            location=(sign * 0.055, 0.0, 0.190),
            rotation=(0.0, sign * 0.40, 0.0)
        )
        bell = bpy.context.active_object
        bell.name = f"alarm_clock_bell_{side}"
        bell.data.materials.append(mat_brass)
        apply_bevel(bell, width=0.004, segments=1)
        visual_objects.append(bell)

        # Poste de soporte de la campana
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.005, depth=0.030,
            location=(sign * 0.045, 0.0, 0.170),
            rotation=(0.0, sign * 0.35, 0.0)
        )
        stem = bpy.context.active_object
        stem.name = f"alarm_clock_stem_{side}"
        stem.data.materials.append(mat_steel)
        visual_objects.append(stem)

    # Martillo central oscilante
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.004, depth=0.030, location=(0.0, 0.0, 0.180)
    )
    hammer_stem = bpy.context.active_object
    hammer_stem.name = "alarm_clock_hammer_stem"
    hammer_stem.data.materials.append(mat_steel)
    visual_objects.append(hammer_stem)

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.008, depth=0.016, location=(0.0, 0.0, 0.196), rotation=(0.0, 1.5708, 0.0)
    )
    hammer_head = bpy.context.active_object
    hammer_head.name = "alarm_clock_hammer_head"
    hammer_head.data.materials.append(mat_steel)
    visual_objects.append(hammer_head)

    # Asa superior de alambre
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.215), scale=(0.070, 0.006, 0.008)
    )
    handle = bpy.context.active_object
    handle.name = "alarm_clock_handle"
    handle.data.materials.append(mat_brass)
    visual_objects.append(handle)

    # Patas esféricas de apoyo delanteras y pata de soporte trasera
    for side, sign in [("l", -1.0), ("r", 1.0)]:
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=6, ring_count=5, radius=0.012,
            location=(sign * 0.050, 0.030, 0.012)
        )
        foot = bpy.context.active_object
        foot.name = f"alarm_clock_foot_{side}"
        foot.data.materials.append(mat_brass)
        visual_objects.append(foot)

    # Pata trasera
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.006, depth=0.040,
        location=(0.0, -0.040, 0.018), rotation=(0.50, 0.0, 0.0)
    )
    rear_foot = bpy.context.active_object
    rear_foot.name = "alarm_clock_foot_rear"
    rear_foot.data.materials.append(mat_brass)
    visual_objects.append(rear_foot)

    # Normalizar dimensiones visuales exactamente a la ficha
    normalize_and_apply_visuals(visual_objects, exp_x=0.18, exp_y=0.12, exp_z=0.22)

    # Malla de colisión estática para Godot
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.11), scale=(0.18, 0.12, 0.22)
    )
    col = bpy.context.active_object
    col.name = "alarm_clock-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# =============================================================================
# 2. Cuña de Madera para Puertas (wood_wedge.glb)
# Dimensiones: (0.25, 0.08, 0.08) m | Material: MahoganyWood
# Colisión: wood_wedge-col | Presupuesto: 300 tris
# =============================================================================
def generate_wood_wedge(filename: str = "wood_wedge.glb"):
    clear_scene()
    mat_wood = create_pbr_material("MahoganyWood", "MahoganyWood")

    visual_objects = []

    # Construir geometría de cuña biselada usando bmesh
    import bmesh
    me = bpy.data.meshes.new("wood_wedge_mesh")
    bm = bmesh.new()

    # Vértices de la cuña: largo en X (-0.125 a +0.125), ancho en Y (-0.04 a +0.04), alto en Z (0.0 a 0.08)
    # Extremo trasero (X = -0.125): altura completa Z = 0.08
    # Extremo delantero (X = +0.125): punta con entrada fina Z = 0.005
    w_half = 0.04
    steps = [
        (-0.125, 0.080),
        (-0.040, 0.052),
        (-0.040, 0.046),
        ( 0.040, 0.024),
        ( 0.040, 0.018),
        ( 0.125, 0.005),
    ]

    top_left = []
    top_right = []
    bot_left = []
    bot_right = []

    for x_val, z_val in steps:
        tl = bm.verts.new((x_val, -w_half, z_val))
        tr = bm.verts.new((x_val,  w_half, z_val))
        bl = bm.verts.new((x_val, -w_half, 0.0))
        br = bm.verts.new((x_val,  w_half, 0.0))
        top_left.append(tl)
        top_right.append(tr)
        bot_left.append(bl)
        bot_right.append(br)

    bm.verts.ensure_lookup_table()

    for i in range(len(steps) - 1):
        # Cara superior
        bm.faces.new((top_left[i], top_left[i+1], top_right[i+1], top_right[i]))
        # Cara inferior
        bm.faces.new((bot_left[i], bot_right[i], bot_right[i+1], bot_left[i+1]))
        # Lados
        bm.faces.new((bot_left[i], bot_left[i+1], top_left[i+1], top_left[i]))
        bm.faces.new((bot_right[i], top_right[i], top_right[i+1], bot_right[i+1]))

    # Cara trasera
    bm.faces.new((bot_left[0], top_left[0], top_right[0], bot_right[0]))
    # Cara delantera
    bm.faces.new((bot_left[-1], bot_right[-1], top_right[-1], top_left[-1]))

    bm.to_mesh(me)
    bm.free()

    obj = bpy.data.objects.new("wood_wedge_body", me)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat_wood)
    apply_bevel(obj, width=0.003, segments=1)
    visual_objects.append(obj)

    # Normalizar dimensiones visuales exactamente a la ficha
    normalize_and_apply_visuals(visual_objects, exp_x=0.25, exp_y=0.08, exp_z=0.08)

    # Malla de colisión estática para Godot
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.04), scale=(0.25, 0.08, 0.08)
    )
    col = bpy.context.active_object
    col.name = "wood_wedge-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# =============================================================================
# 3. Estetoscopio Analógico (stethoscope.glb)
# Dimensiones: (0.26, 0.32, 0.05) m | Materiales: BakeliteBlack, Steel80s, BrassGold
# Colisión: No | Presupuesto: 800 tris
# =============================================================================
def generate_stethoscope(filename: str = "stethoscope.glb"):
    clear_scene()
    mat_bakelite = create_pbr_material("BakeliteBlack", "BakeliteBlack")
    mat_steel = create_pbr_material("Steel80s", "Steel80s")
    mat_brass = create_pbr_material("BrassGold", "BrassGold")

    visual_objects = []

    # Auriculares metálicos binaurales (Steel80s) en curva V
    for side, sign in [("l", -1.0), ("r", 1.0)]:
        # Segmento inferior del tubo
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.005, depth=0.10,
            location=(sign * 0.045, 0.08, 0.025),
            rotation=(0.0, 0.0, sign * 0.65)
        )
        tube_low = bpy.context.active_object
        tube_low.name = f"stethoscope_tube_low_{side}"
        tube_low.data.materials.append(mat_steel)
        visual_objects.append(tube_low)

        # Segmento superior del tubo
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.005, depth=0.10,
            location=(sign * 0.095, 0.14, 0.025),
            rotation=(0.0, 0.0, sign * 0.30)
        )
        tube_up = bpy.context.active_object
        tube_up.name = f"stethoscope_tube_up_{side}"
        tube_up.data.materials.append(mat_steel)
        visual_objects.append(tube_up)

        # Olivas auriculares de baquelita (BakeliteBlack)
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=6, ring_count=4, radius=0.010,
            location=(sign * 0.125, 0.155, 0.025)
        )
        earpiece = bpy.context.active_object
        earpiece.name = f"stethoscope_earpiece_{side}"
        earpiece.data.materials.append(mat_bakelite)
        visual_objects.append(earpiece)

    # Muelle transversal de tensión entre tubos (Steel80s)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.10, 0.025), scale=(0.11, 0.004, 0.004)
    )
    spring = bpy.context.active_object
    spring.name = "stethoscope_spring"
    spring.data.materials.append(mat_steel)
    visual_objects.append(spring)

    # Conector metálico en Y (BrassGold)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.008, depth=0.025,
        location=(0.0, 0.035, 0.025), rotation=(1.5708, 0.0, 0.0)
    )
    y_connector = bpy.context.active_object
    y_connector.name = "stethoscope_connector"
    y_connector.data.materials.append(mat_brass)
    apply_bevel(y_connector, width=0.002, segments=1)
    visual_objects.append(y_connector)

    # Manguera flexible en Y de goma (BakeliteBlack)
    hose_points = [
        (0.000,  0.015, 0.025),
        (0.020, -0.020, 0.020),
        (0.010, -0.060, 0.018),
        (-0.015, -0.090, 0.016),
        (0.000, -0.115, 0.015),
    ]
    for i in range(len(hose_points) - 1):
        p1 = mathutils.Vector(hose_points[i])
        p2 = mathutils.Vector(hose_points[i+1])
        mid = (p1 + p2) / 2.0
        vec = p2 - p1
        length = vec.length

        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.007, depth=length, location=mid
        )
        h_seg = bpy.context.active_object
        h_seg.name = f"stethoscope_hose_seg_{i}"
        h_seg.data.materials.append(mat_bakelite)
        direction = vec.normalized()
        up = mathutils.Vector((0, 0, 1))
        rot_quat = up.rotation_difference(direction)
        h_seg.rotation_mode = "QUATERNION"
        h_seg.rotation_quaternion = rot_quat
        h_seg.rotation_mode = "XYZ"
        visual_objects.append(h_seg)

    # Campana de auscultación redonda (Steel80s con anillo BrassGold)
    # Cuerpo principal de acero
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.026, depth=0.022, location=(0.0, -0.138, 0.020)
    )
    bell_body = bpy.context.active_object
    bell_body.name = "stethoscope_bell_body"
    bell_body.data.materials.append(mat_steel)
    apply_bevel(bell_body, width=0.003, segments=1)
    visual_objects.append(bell_body)

    # Anillo exterior de latón dorado
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.028, depth=0.006, location=(0.0, -0.138, 0.010)
    )
    bell_ring = bpy.context.active_object
    bell_ring.name = "stethoscope_bell_ring"
    bell_ring.data.materials.append(mat_brass)
    apply_bevel(bell_ring, width=0.002, segments=1)
    visual_objects.append(bell_ring)

    # Vástago de conexión de la campana
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.006, depth=0.018,
        location=(0.0, -0.120, 0.020), rotation=(1.5708, 0.0, 0.0)
    )
    bell_stem = bpy.context.active_object
    bell_stem.name = "stethoscope_bell_stem"
    bell_stem.data.materials.append(mat_brass)
    visual_objects.append(bell_stem)

    # Normalizar dimensiones visuales exactamente a la ficha
    normalize_and_apply_visuals(visual_objects, exp_x=0.26, exp_y=0.32, exp_z=0.05)

    export_glb(filename)


# =============================================================================
# 4. Espejo Telescópico de Inspección (inspection_mirror.glb)
# Dimensiones: (0.10, 0.38, 0.04) m | Materiales: Steel80s, ChromeTrim
# Colisión: No | Presupuesto: 500 tris
# =============================================================================
def generate_inspection_mirror(filename: str = "inspection_mirror.glb"):
    clear_scene()
    mat_steel = create_pbr_material("Steel80s", "Steel80s")
    mat_chrome = create_pbr_material("ChromeTrim", "ChromeTrim")

    visual_objects = []

    # Mango acanalado ergonómico de acero oscuro (Steel80s)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10, radius=0.010, depth=0.12,
        location=(0.0, -0.13, 0.020), rotation=(1.5708, 0.0, 0.0)
    )
    handle = bpy.context.active_object
    handle.name = "inspection_mirror_handle"
    handle.data.materials.append(mat_steel)
    apply_bevel(handle, width=0.003, segments=1)
    visual_objects.append(handle)

    # Tapón de extremo con anilla
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.011, depth=0.010,
        location=(0.0, -0.185, 0.020), rotation=(1.5708, 0.0, 0.0)
    )
    cap = bpy.context.active_object
    cap.name = "inspection_mirror_cap"
    cap.data.materials.append(mat_steel)
    visual_objects.append(cap)

    # Secciones telescópicas concéntricas de acero (Steel80s)
    sections = [
        (-0.045, 0.07, 0.008),
        ( 0.015, 0.06, 0.006),
        ( 0.065, 0.05, 0.004),
    ]
    for idx, (y_pos, length, r) in enumerate(sections):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=r, depth=length,
            location=(0.0, y_pos, 0.020), rotation=(1.5708, 0.0, 0.0)
        )
        shaft = bpy.context.active_object
        shaft.name = f"inspection_mirror_shaft_{idx}"
        shaft.data.materials.append(mat_steel)
        visual_objects.append(shaft)

    # Rótula orientable (rótula doble de bola)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=6, ring_count=5, radius=0.007, location=(0.0, 0.095, 0.020)
    )
    ball1 = bpy.context.active_object
    ball1.name = "inspection_mirror_swivel_ball"
    ball1.data.materials.append(mat_steel)
    visual_objects.append(ball1)

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.004, depth=0.015,
        location=(0.0, 0.105, 0.022), rotation=(0.35, 0.0, 0.0)
    )
    joint_stem = bpy.context.active_object
    joint_stem.name = "inspection_mirror_joint_stem"
    joint_stem.data.materials.append(mat_steel)
    visual_objects.append(joint_stem)

    # Marco circular del espejo en cromo (ChromeTrim)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.048, depth=0.008,
        location=(0.0, 0.142, 0.020), rotation=(0.20, 0.0, 0.0)
    )
    mirror_frame = bpy.context.active_object
    mirror_frame.name = "inspection_mirror_frame"
    mirror_frame.data.materials.append(mat_chrome)
    apply_bevel(mirror_frame, width=0.002, segments=1)
    visual_objects.append(mirror_frame)

    # Superficie reflectante cromada interior
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.043, depth=0.003,
        location=(0.0, 0.142, 0.023), rotation=(0.20, 0.0, 0.0)
    )
    mirror_surface = bpy.context.active_object
    mirror_surface.name = "inspection_mirror_surface"
    mirror_surface.data.materials.append(mat_chrome)
    visual_objects.append(mirror_surface)

    # Normalizar dimensiones visuales exactamente a la ficha
    normalize_and_apply_visuals(visual_objects, exp_x=0.10, exp_y=0.38, exp_z=0.04)

    export_glb(filename)


# =============================================================================
# 5. Campanilla de Cable Trampa (tripwire_bell.glb)
# Dimensiones: (0.12, 0.14, 0.18) m | Materiales: BrassGold, Steel80s
# Colisión: tripwire_bell-col | Presupuesto: 600 tris
# =============================================================================
def generate_tripwire_bell(filename: str = "tripwire_bell.glb"):
    clear_scene()
    mat_brass = create_pbr_material("BrassGold", "BrassGold")
    mat_steel = create_pbr_material("Steel80s", "Steel80s")

    visual_objects = []

    # Placa de montaje angular para pared / marco (Steel80s)
    # Espaldar vertical
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, -0.055, 0.090), scale=(0.10, 0.012, 0.16)
    )
    backplate = bpy.context.active_object
    backplate.name = "tripwire_bell_backplate"
    backplate.data.materials.append(mat_steel)
    apply_bevel(backplate, width=0.003, segments=1)
    visual_objects.append(backplate)

    # Soporte saliente horizontal
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, -0.010, 0.040), scale=(0.06, 0.08, 0.012)
    )
    bracket_arm = bpy.context.active_object
    bracket_arm.name = "tripwire_bell_bracket_arm"
    bracket_arm.data.materials.append(mat_steel)
    apply_bevel(bracket_arm, width=0.003, segments=1)
    visual_objects.append(bracket_arm)

    # Poste central de montaje de la campana
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.008, depth=0.090, location=(0.0, 0.010, 0.085)
    )
    post = bpy.context.active_object
    post.name = "tripwire_bell_post"
    post.data.materials.append(mat_steel)
    visual_objects.append(post)

    # Campana semiesférica de bronce (BrassGold)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=0.046, depth=0.038,
        location=(0.0, 0.010, 0.125), rotation=(0.0, 0.0, 0.0)
    )
    dome = bpy.context.active_object
    dome.name = "tripwire_bell_dome"
    dome.data.materials.append(mat_brass)
    apply_bevel(dome, width=0.008, segments=1)
    visual_objects.append(dome)

    # Tuerca ciega superior de latón
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.012, depth=0.015, location=(0.0, 0.010, 0.155)
    )
    acorn_nut = bpy.context.active_object
    acorn_nut.name = "tripwire_bell_nut"
    acorn_nut.data.materials.append(mat_brass)
    visual_objects.append(acorn_nut)

    # Resorte espiral de acero
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.014, depth=0.040, location=(-0.035, -0.015, 0.075)
    )
    spring = bpy.context.active_object
    spring.name = "tripwire_bell_spring"
    spring.data.materials.append(mat_steel)
    visual_objects.append(spring)

    # Brazo percutor oscilante (Steel80s)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(-0.015, 0.020, 0.110), scale=(0.006, 0.060, 0.006)
    )
    clapper_arm = bpy.context.active_object
    clapper_arm.name = "tripwire_bell_clapper_arm"
    clapper_arm.data.materials.append(mat_steel)
    visual_objects.append(clapper_arm)

    # Cabeza del percutor
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=6, ring_count=5, radius=0.008, location=(-0.035, 0.045, 0.110)
    )
    clapper_head = bpy.context.active_object
    clapper_head.name = "tripwire_bell_clapper_head"
    clapper_head.data.materials.append(mat_brass)
    visual_objects.append(clapper_head)

    # Clavija de disparo con anilla de tiro frontal para cable (BrassGold)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.004, depth=0.050,
        location=(0.0, 0.045, 0.040), rotation=(1.5708, 0.0, 0.0)
    )
    trip_pin = bpy.context.active_object
    trip_pin.name = "tripwire_bell_pin"
    trip_pin.data.materials.append(mat_steel)
    visual_objects.append(trip_pin)

    # Anilla frontal para enganche del cable trampa
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=0.012, depth=0.004,
        location=(0.0, 0.065, 0.040), rotation=(0.0, 1.5708, 0.0)
    )
    pull_ring = bpy.context.active_object
    pull_ring.name = "tripwire_bell_ring"
    pull_ring.data.materials.append(mat_brass)
    visual_objects.append(pull_ring)

    # Normalizar dimensiones visuales exactamente a la ficha
    normalize_and_apply_visuals(visual_objects, exp_x=0.12, exp_y=0.14, exp_z=0.18)

    # Malla de colisión estática para Godot
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.09), scale=(0.12, 0.14, 0.18)
    )
    col = bpy.context.active_object
    col.name = "tripwire_bell-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


def main():
    print("=== [Blender CLI] Generando 5 gadgets analógicos 1984 (FEAT-004) ===")
    generate_alarm_clock("alarm_clock.glb")
    generate_wood_wedge("wood_wedge.glb")
    generate_stethoscope("stethoscope.glb")
    generate_inspection_mirror("inspection_mirror.glb")
    generate_tripwire_bell("tripwire_bell.glb")
    print("=== [Blender CLI] Generación de gadgets completada con éxito ===")


if __name__ == "__main__":
    main()
