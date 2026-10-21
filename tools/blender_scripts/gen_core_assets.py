#!/usr/bin/env python3
"""
tools/blender_scripts/gen_core_assets.py
Genera de manera procedural (headless bpy) los assets .glb de la Fase 1 y Fase 2 para 'Velvet Heist 84'.
Sigue las especificaciones PBR 'Velvet 84', convención de sufijo '-col' para Godot 4,
escala 1 unidad = 1 metro y pivotes en la base inferior central.
"""

import os
import sys

try:
    import bpy
    import mathutils
except ImportError:
    print("Error: Este script debe ejecutarse dentro del contexto de Blender (blender -b -P <script.py>).")
    sys.exit(1)

OUTPUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
)
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Paleta PBR Velvet '84 en RGB lineal
PALETTE = {
    "MahoganyWood": {"hex": "#3B1E14", "roughness": 0.35, "metallic": 0.0},
    "BrassGold": {"hex": "#D4AF37", "roughness": 0.20, "metallic": 0.90},
    "Steel80s": {"hex": "#2B2D42", "roughness": 0.40, "metallic": 0.80},
    "VelvetBlack": {"hex": "#16161A", "roughness": 0.85, "metallic": 0.0},
    "GuardNavy": {"hex": "#1B263B", "roughness": 0.65, "metallic": 0.10},
    "BakeliteBlack": {"hex": "#111113", "roughness": 0.15, "metallic": 0.05},
    "CarpetWine": {"hex": "#4A121A", "roughness": 0.90, "metallic": 0.0},
    "ParquetWood": {"hex": "#6F4E37", "roughness": 0.45, "metallic": 0.0},
    "MarbleWhite": {"hex": "#ECEBE4", "roughness": 0.25, "metallic": 0.05},
    "BurgundyCar": {"hex": "#3A0D14", "roughness": 0.20, "metallic": 0.35},
    "ChromeTrim": {"hex": "#D8D8E0", "roughness": 0.10, "metallic": 0.95},
    "GlassAmber": {"hex": "#FFAA22", "roughness": 0.10, "metallic": 0.0},
    "CashGreen": {"hex": "#2E5D34", "roughness": 0.85, "metallic": 0.0},
    "PaperWhite": {"hex": "#F0EAD6", "roughness": 0.90, "metallic": 0.0},
    "CanvasOil": {"hex": "#5C4033", "roughness": 0.70, "metallic": 0.0},
}


def hex_to_linear_rgb(hex_code: str):
    hex_code = hex_code.lstrip("#")
    srgb = [int(hex_code[i : i + 2], 16) / 255.0 for i in (0, 2, 4)]

    def to_linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    linear = [to_linear(c) for c in srgb]
    return (linear[0], linear[1], linear[2], 1.0)


def create_pbr_material(name: str, prop_data: dict):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = hex_to_linear_rgb(prop_data["hex"])
        bsdf.inputs["Roughness"].default_value = prop_data["roughness"]
        bsdf.inputs["Metallic"].default_value = prop_data["metallic"]
    return mat


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_glb(filename: str):
    filepath = os.path.join(OUTPUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
    )
    print(f"[Blender MCP] Asset exportado con exito: {filepath}")


def apply_bevel(obj, width=0.02, segments=2):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    bpy.ops.object.modifier_apply(modifier="Bevel")


# 1. Suelos modulares (2m x 2m x 0.1m, pivote en Z=0)
def generate_floor(filename: str, mat_name: str):
    clear_scene()
    mat = create_pbr_material(mat_name, PALETTE[mat_name])

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.05), scale=(2.0, 2.0, 0.1)
    )
    visual = bpy.context.active_object
    visual.name = f"{mat_name}_Floor"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    visual.data.materials.append(mat)
    apply_bevel(visual, width=0.01, segments=1)

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.05), scale=(2.0, 2.0, 0.1)
    )
    col = bpy.context.active_object
    col.name = f"{visual.name}-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 2. Muro Modular Caoba (2m ancho x 3m alto x 0.2m grosor, pivote en Z=0)
def generate_wall(filename: str):
    clear_scene()
    mat = create_pbr_material("MahoganyWood", PALETTE["MahoganyWood"])

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 1.5), scale=(2.0, 0.2, 3.0)
    )
    visual = bpy.context.active_object
    visual.name = "Wall_Mahogany"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    visual.data.materials.append(mat)
    apply_bevel(visual, width=0.02, segments=2)

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 1.5), scale=(2.0, 0.2, 3.0)
    )
    col = bpy.context.active_object
    col.name = "Wall_Mahogany-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 3. Cápsula Ladrón (0.8m diametro x 1.8m alto)
def generate_thief_pawn(filename: str):
    clear_scene()
    mat_suit = create_pbr_material("VelvetBlack", PALETTE["VelvetBlack"])
    mat_accent = create_pbr_material("BrassGold", PALETTE["BrassGold"])

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.4, depth=1.4, location=(0.0, 0.0, 0.9)
    )
    body = bpy.context.active_object
    body.name = "Thief_Body"
    body.data.materials.append(mat_suit)
    apply_bevel(body, width=0.02, segments=2)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.32, location=(0.0, 0.0, 1.6)
    )
    head = bpy.context.active_object
    head.name = "Thief_Head"
    head.data.materials.append(mat_suit)

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.3, 1.62), scale=(0.35, 0.12, 0.08)
    )
    mask = bpy.context.active_object
    mask.name = "Thief_Mask"
    mask.data.materials.append(mat_accent)

    export_glb(filename)


# 4. Cápsula Guardia con Linterna Maglite
def generate_guard_pawn(filename: str):
    clear_scene()
    mat_uniform = create_pbr_material("GuardNavy", PALETTE["GuardNavy"])
    mat_maglite = create_pbr_material("BakeliteBlack", PALETTE["BakeliteBlack"])
    mat_brass = create_pbr_material("BrassGold", PALETTE["BrassGold"])

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.42, depth=1.4, location=(0.0, 0.0, 0.9)
    )
    body = bpy.context.active_object
    body.name = "Guard_Body"
    body.data.materials.append(mat_uniform)
    apply_bevel(body, width=0.02, segments=2)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.35, depth=0.15, location=(0.0, 0.0, 1.7)
    )
    cap = bpy.context.active_object
    cap.name = "Guard_Cap"
    cap.data.materials.append(mat_uniform)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.04, depth=0.35, location=(0.35, 0.25, 0.95), rotation=(1.5708, 0.0, 0.0)
    )
    torch = bpy.context.active_object
    torch.name = "Maglite_Torch"
    torch.data.materials.append(mat_maglite)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.065, depth=0.10, location=(0.35, 0.43, 0.95), rotation=(1.5708, 0.0, 0.0)
    )
    head = bpy.context.active_object
    head.name = "Maglite_Head"
    head.data.materials.append(mat_brass)

    export_glb(filename)


# 5. Caja Fuerte Años 80 (safe_box_84.glb)
def generate_safe_box(filename: str):
    clear_scene()
    mat_steel = create_pbr_material("Steel80s", PALETTE["Steel80s"])
    mat_brass = create_pbr_material("BrassGold", PALETTE["BrassGold"])

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.55), scale=(0.9, 0.9, 1.1)
    )
    box = bpy.context.active_object
    box.name = "SafeBox_Mesh"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    box.data.materials.append(mat_steel)
    apply_bevel(box, width=0.02, segments=2)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.15, depth=0.06, location=(0.0, 0.48, 0.65), rotation=(1.5708, 0.0, 0.0)
    )
    dial = bpy.context.active_object
    dial.name = "SafeBox_Dial"
    dial.data.materials.append(mat_brass)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.03, depth=0.25, location=(0.25, 0.48, 0.65), rotation=(0.0, 1.5708, 0.0)
    )
    handle = bpy.context.active_object
    handle.name = "SafeBox_Handle"
    handle.data.materials.append(mat_brass)

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.55), scale=(0.9, 0.9, 1.1)
    )
    col = bpy.context.active_object
    col.name = "SafeBox-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 6. Teléfono fijo de disco (rotary_phone_84.glb)
def generate_rotary_phone(filename: str):
    clear_scene()
    mat_bakelite = create_pbr_material("BakeliteBlack", PALETTE["BakeliteBlack"])
    mat_brass = create_pbr_material("BrassGold", PALETTE["BrassGold"])

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.08), scale=(0.32, 0.32, 0.16)
    )
    base = bpy.context.active_object
    base.name = "RotaryPhone_Base"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    base.data.materials.append(mat_bakelite)
    apply_bevel(base, width=0.02, segments=2)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.10, depth=0.02, location=(0.0, -0.04, 0.17)
    )
    dial = bpy.context.active_object
    dial.name = "RotaryPhone_Dial"
    dial.data.materials.append(mat_brass)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.04, depth=0.38, location=(0.0, 0.06, 0.22), rotation=(0.0, 1.5708, 0.0)
    )
    handset = bpy.context.active_object
    handset.name = "RotaryPhone_Handset"
    handset.data.materials.append(mat_bakelite)

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.12), scale=(0.35, 0.35, 0.24)
    )
    col = bpy.context.active_object
    col.name = "RotaryPhone-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 7. Reloj Mecánico de Fichar (time_clock_84.glb) - Fase 2
def generate_time_clock(filename: str):
    clear_scene()
    mat_steel = create_pbr_material("Steel80s", PALETTE["Steel80s"])
    mat_brass = create_pbr_material("BrassGold", PALETTE["BrassGold"])
    mat_white = create_pbr_material("PaperWhite", PALETTE["PaperWhite"])

    # Carcasa de pared (0.4m ancho x 0.2m prof x 0.6m alto)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.3), scale=(0.4, 0.22, 0.6)
    )
    body = bpy.context.active_object
    body.name = "TimeClock_Body"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    body.data.materials.append(mat_steel)
    apply_bevel(body, width=0.015, segments=2)

    # Esfera analógica superior
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.13, depth=0.03, location=(0.0, 0.12, 0.44), rotation=(1.5708, 0.0, 0.0)
    )
    face = bpy.context.active_object
    face.name = "TimeClock_Dial"
    face.data.materials.append(mat_white)

    # Manecillas / bisel de bronce
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.14, depth=0.02, location=(0.0, 0.115, 0.44), rotation=(1.5708, 0.0, 0.0)
    )
    ring = bpy.context.active_object
    ring.name = "TimeClock_Ring"
    ring.data.materials.append(mat_brass)

    # Ranura y palanca de fichar inferior
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.12, 0.18), scale=(0.26, 0.04, 0.03)
    )
    slot = bpy.context.active_object
    slot.name = "TimeClock_Slot"
    slot.data.materials.append(mat_brass)

    # Palanca lateral de perforación
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.02, depth=0.25, location=(0.22, 0.05, 0.25), rotation=(0.5, 0.0, 0.0)
    )
    lever = bpy.context.active_object
    lever.name = "TimeClock_Lever"
    lever.data.materials.append(mat_brass)

    # Colisión
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.3), scale=(0.42, 0.24, 0.62)
    )
    col = bpy.context.active_object
    col.name = "TimeClock-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 8. Coche de Fuga 1984 (escape_car_84.glb) - Fase 2
def generate_escape_car(filename: str):
    clear_scene()
    mat_car = create_pbr_material("BurgundyCar", PALETTE["BurgundyCar"])
    mat_chrome = create_pbr_material("ChromeTrim", PALETTE["ChromeTrim"])
    mat_rubber = create_pbr_material("BakeliteBlack", PALETTE["BakeliteBlack"])
    mat_light = create_pbr_material("GlassAmber", PALETTE["GlassAmber"])

    # Carrocería baja estilizada (1.9m ancho x 4.4m largo x 1.25m alto)
    # Chasis inferior
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.45), scale=(1.8, 4.2, 0.6)
    )
    chassis = bpy.context.active_object
    chassis.name = "Car_Chassis"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    chassis.data.materials.append(mat_car)
    apply_bevel(chassis, width=0.03, segments=2)

    # Habitáculo / Techo coupé
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, -0.2, 0.95), scale=(1.5, 2.2, 0.5)
    )
    cabin = bpy.context.active_object
    cabin.name = "Car_Cabin"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    cabin.data.materials.append(mat_car)
    apply_bevel(cabin, width=0.02, segments=2)

    # Parachoques cromados frontal y trasero
    for y_pos in [-2.15, 2.15]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0, location=(0.0, y_pos, 0.35), scale=(1.84, 0.16, 0.18)
        )
        bumper = bpy.context.active_object
        bumper.name = f"Car_Bumper_{'Front' if y_pos>0 else 'Rear'}"
        bumper.data.materials.append(mat_chrome)

    # Faros delanteros ámbar
    for x_pos in [-0.65, 0.65]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0, location=(x_pos, 2.12, 0.52), scale=(0.35, 0.08, 0.16)
        )
        light = bpy.context.active_object
        light.name = f"Car_Headlight_{'L' if x_pos<0 else 'R'}"
        light.data.materials.append(mat_light)

    # Ruedas (4 ruedas con neumáticos negros y llantas cromadas)
    wheel_coords = [(-0.95, -1.3, 0.35), (0.95, -1.3, 0.35), (-0.95, 1.3, 0.35), (0.95, 1.3, 0.35)]
    for idx, (wx, wy, wz) in enumerate(wheel_coords):
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.35, depth=0.25, location=(wx, wy, wz), rotation=(0.0, 1.5708, 0.0)
        )
        wheel = bpy.context.active_object
        wheel.name = f"Wheel_{idx}"
        wheel.data.materials.append(mat_rubber)

    # Maletero abierto / Zona de depósito de botín (en la parte trasera Y < -1.5)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, -1.65, 0.82), scale=(1.4, 0.8, 0.08)
    )
    trunk_lid = bpy.context.active_object
    trunk_lid.name = "Car_TrunkLid"
    trunk_lid.rotation_euler = (0.45, 0.0, 0.0)
    trunk_lid.data.materials.append(mat_car)

    # Colisión para Godot
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.65), scale=(2.0, 4.4, 1.1)
    )
    col = bpy.context.active_object
    col.name = "Car-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 9. Botín Ligero: Fajo de Billetes (loot_cash.glb) - Fase 2
def generate_loot_cash(filename: str):
    clear_scene()
    mat_cash = create_pbr_material("CashGreen", PALETTE["CashGreen"])
    mat_band = create_pbr_material("PaperWhite", PALETTE["PaperWhite"])

    # Fajo de billetes (0.22m x 0.12m x 0.06m)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.03), scale=(0.22, 0.12, 0.06)
    )
    cash = bpy.context.active_object
    cash.name = "LootCash_Stack"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    cash.data.materials.append(mat_cash)
    apply_bevel(cash, width=0.005, segments=1)

    # Faja de papel central
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.031), scale=(0.05, 0.125, 0.063)
    )
    band = bpy.context.active_object
    band.name = "LootCash_Band"
    band.data.materials.append(mat_band)

    export_glb(filename)


# 10. Botín Pesado: Pieza Maestra (loot_masterpiece.glb) - Fase 2
def generate_loot_masterpiece(filename: str):
    clear_scene()
    mat_frame = create_pbr_material("BrassGold", PALETTE["BrassGold"])
    mat_canvas = create_pbr_material("CanvasOil", PALETTE["CanvasOil"])

    # Marco dorado ornamentado (0.8m ancho x 0.1m grosor x 1.0m alto)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.5), scale=(0.8, 0.08, 1.0)
    )
    frame = bpy.context.active_object
    frame.name = "Masterpiece_Frame"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    frame.data.materials.append(mat_frame)
    apply_bevel(frame, width=0.025, segments=2)

    # Lienzo interior
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.015, 0.5), scale=(0.66, 0.06, 0.86)
    )
    canvas = bpy.context.active_object
    canvas.name = "Masterpiece_Canvas"
    canvas.data.materials.append(mat_canvas)

    export_glb(filename)


def main():
    print("=== [Blender MCP] Generando assets nucleo Velvet '84 (Fase 1 y 2) ===")
    generate_floor("floor_carpet.glb", "CarpetWine")
    generate_floor("floor_parquet.glb", "ParquetWood")
    generate_floor("floor_marble.glb", "MarbleWhite")
    generate_wall("wall_mahogany.glb")
    generate_thief_pawn("thief_pawn.glb")
    generate_guard_pawn("guard_pawn.glb")
    generate_safe_box("safe_box_84.glb")
    generate_rotary_phone("rotary_phone_84.glb")
    # Fase 2
    generate_time_clock("time_clock_84.glb")
    generate_escape_car("escape_car_84.glb")
    generate_loot_cash("loot_cash.glb")
    generate_loot_masterpiece("loot_masterpiece.glb")
    print("=== [Blender MCP] Generacion completada con exito ===")


if __name__ == "__main__":
    main()
