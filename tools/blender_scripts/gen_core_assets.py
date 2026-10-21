#!/usr/bin/env python3
"""
tools/blender_scripts/gen_core_assets.py
Genera de manera procedural (headless bpy) los assets .glb de Velvet Heist '84.
Cumple estrictamente con la regla 02 y FEAT-001:
- Paleta unificada desde lib.palette (sin nodos procedurales)
- Escala métrica 1 unidad = 1 metro
- Pivotes en la base inferior central (Z_min=0.0, Centro XY=(0,0))
- Transformaciones aplicadas (escala 1,1,1 y rotación 0,0,0)
- Convención de colisión '-col' para Godot 4
- Nombres en snake_case
"""

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
    print("Error: Este script debe ejecutarse dentro del contexto de Blender (blender -b -P <script.py>).")
    sys.exit(1)

OUTPUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
)
os.makedirs(OUTPUT_DIR, exist_ok=True)


def clear_scene():
    """Limpia todos los objetos y bloques de datos de la escena."""
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


def apply_bevel(obj, width=0.02, segments=2):
    """Aplica modificador Bevel y hornea la geometría para bordes redondeados analógicos."""
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    bpy.ops.object.modifier_apply(modifier="Bevel")


# 1. Suelos modulares (2.0m x 2.0m x 0.1m, pivote en Z=0.0)
def generate_floor(filename: str, mat_name: str, prefix: str):
    clear_scene()
    mat = create_pbr_material(mat_name, mat_name)

    # Malla visual: 2.0 x 2.0 x 0.1, centrada en XY, base en Z=0.0 (centro Z=0.05)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.05), scale=(2.0, 2.0, 0.1)
    )
    visual = bpy.context.active_object
    visual.name = f"{prefix}_Visual"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    visual.data.materials.append(mat)
    apply_bevel(visual, width=0.01, segments=1)

    # Malla de colisión estática
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.05), scale=(2.0, 2.0, 0.1)
    )
    col = bpy.context.active_object
    col.name = f"{prefix}-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 2. Muro Modular Caoba (2.0m ancho x 0.2m grosor x 3.0m alto, pivote en Z=0.0)
def generate_wall(filename: str):
    clear_scene()
    mat = create_pbr_material("MahoganyWood", "MahoganyWood")

    # Malla visual: base en Z=0.0 (centro Z=1.5)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 1.5), scale=(2.0, 0.2, 3.0)
    )
    visual = bpy.context.active_object
    visual.name = "Wall_Mahogany"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    visual.data.materials.append(mat)
    apply_bevel(visual, width=0.02, segments=2)

    # Malla de colisión estática
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 1.5), scale=(2.0, 0.2, 3.0)
    )
    col = bpy.context.active_object
    col.name = "Wall_Mahogany-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 3. Cápsula Ladrón (0.8m diámetro x 1.8m alto, base en Z=0.0)
def generate_thief_pawn(filename: str):
    clear_scene()
    mat_suit = create_pbr_material("VelvetBlack", "VelvetBlack")
    mat_accent = create_pbr_material("BrassGold", "BrassGold")

    # Cuerpo cilíndrico: radio=0.40m, altura=1.30m, base en Z=0.00 (centro Z=0.65)
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.40, depth=1.30, location=(0.0, 0.0, 0.65)
    )
    body = bpy.context.active_object
    body.name = "Thief_Body"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    body.data.materials.append(mat_suit)
    apply_bevel(body, width=0.02, segments=2)

    # Cabeza: esfera en la parte superior, radio=0.25m, centro en Z=1.55 (va de 1.30 a 1.80m)
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.25, location=(0.0, 0.0, 1.55)
    )
    head = bpy.context.active_object
    head.name = "Thief_Head"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    head.data.materials.append(mat_suit)

    # Antifaz dorado ochentero en el frontal (centrado en XY)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.22, 1.56), scale=(0.32, 0.08, 0.08)
    )
    mask = bpy.context.active_object
    mask.name = "Thief_Mask"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    mask.data.materials.append(mat_accent)

    export_glb(filename)


# 4. Cápsula Guardia con Linterna Maglite (0.8m diámetro base x 1.8m alto)
def generate_guard_pawn(filename: str):
    clear_scene()
    mat_uniform = create_pbr_material("GuardNavy", "GuardNavy")
    mat_maglite = create_pbr_material("BakeliteBlack", "BakeliteBlack")
    mat_brass = create_pbr_material("BrassGold", "BrassGold")

    # Cuerpo cilíndrico: radio=0.40m, altura=1.35m, base en Z=0.00 (centro Z=0.675)
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.40, depth=1.35, location=(0.0, 0.0, 0.675)
    )
    body = bpy.context.active_object
    body.name = "Guard_Body"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    body.data.materials.append(mat_uniform)
    apply_bevel(body, width=0.02, segments=2)

    # Cabeza cilíndrica / cuello: radio=0.28m, altura=0.30m, centro en Z=1.50 (va de 1.35 a 1.65m)
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.28, depth=0.30, location=(0.0, 0.0, 1.50)
    )
    head = bpy.context.active_object
    head.name = "Guard_Head"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    head.data.materials.append(mat_uniform)

    # Gorra de guardia con visera: radio=0.34m, altura=0.15m, centro en Z=1.725 (va de 1.65 a 1.80m)
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.34, depth=0.15, location=(0.0, 0.0, 1.725)
    )
    cap = bpy.context.active_object
    cap.name = "Guard_Cap"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    cap.data.materials.append(mat_uniform)

    # Linterna Maglite en la mano (lado derecho hacia adelante)
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.035, depth=0.30, location=(0.36, 0.20, 0.85), rotation=(1.5708, 0.0, 0.0)
    )
    torch = bpy.context.active_object
    torch.name = "Maglite_Torch"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    torch.data.materials.append(mat_maglite)

    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.055, depth=0.08, location=(0.36, 0.38, 0.85), rotation=(1.5708, 0.0, 0.0)
    )
    torch_head = bpy.context.active_object
    torch_head.name = "Maglite_Head"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    torch_head.data.materials.append(mat_brass)

    export_glb(filename)


# 5. Caja Fuerte Años 80 (safe_box_84.glb)
def generate_safe_box(filename: str):
    clear_scene()
    mat_steel = create_pbr_material("Steel80s", "Steel80s")
    mat_brass = create_pbr_material("BrassGold", "BrassGold")

    # Malla principal del cuerpo de la caja
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.55), scale=(0.90, 0.90, 1.10)
    )
    box = bpy.context.active_object
    box.name = "SafeBox_Mesh"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    box.data.materials.append(mat_steel)
    apply_bevel(box, width=0.02, segments=2)

    # Dial giratorio frontal
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.15, depth=0.06, location=(0.0, 0.48, 0.65), rotation=(1.5708, 0.0, 0.0)
    )
    dial = bpy.context.active_object
    dial.name = "SafeBox_Dial"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    dial.data.materials.append(mat_brass)

    # Manilla de apertura
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.03, depth=0.25, location=(0.25, 0.48, 0.65), rotation=(0.0, 1.5708, 0.0)
    )
    handle = bpy.context.active_object
    handle.name = "SafeBox_Handle"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    handle.data.materials.append(mat_brass)

    # Malla de colisión estática
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.55), scale=(0.90, 0.90, 1.10)
    )
    col = bpy.context.active_object
    col.name = "SafeBox-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 6. Teléfono fijo de disco (rotary_phone_84.glb)
def generate_rotary_phone(filename: str):
    clear_scene()
    mat_bakelite = create_pbr_material("BakeliteBlack", "BakeliteBlack")
    mat_brass = create_pbr_material("BrassGold", "BrassGold")

    # Base trapezoidal
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.08), scale=(0.32, 0.32, 0.16)
    )
    base = bpy.context.active_object
    base.name = "RotaryPhone_Base"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    base.data.materials.append(mat_bakelite)
    apply_bevel(base, width=0.02, segments=2)

    # Disco selector analógico
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.10, depth=0.02, location=(0.0, -0.04, 0.17)
    )
    dial = bpy.context.active_object
    dial.name = "RotaryPhone_Dial"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    dial.data.materials.append(mat_brass)

    # Auricular analógico horizontal
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.04, depth=0.38, location=(0.0, 0.06, 0.22), rotation=(0.0, 1.5708, 0.0)
    )
    handset = bpy.context.active_object
    handset.name = "RotaryPhone_Handset"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    handset.data.materials.append(mat_bakelite)

    # Colisión estática
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.13), scale=(0.38, 0.32, 0.26)
    )
    col = bpy.context.active_object
    col.name = "RotaryPhone-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 7. Reloj Mecánico de Fichar (time_clock_84.glb)
def generate_time_clock(filename: str):
    clear_scene()
    mat_steel = create_pbr_material("Steel80s", "Steel80s")
    mat_brass = create_pbr_material("BrassGold", "BrassGold")
    mat_white = create_pbr_material("PaperWhite", "PaperWhite")

    # Carcasa de pared (0.4m ancho x 0.22m prof x 0.6m alto)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.30), scale=(0.40, 0.22, 0.60)
    )
    body = bpy.context.active_object
    body.name = "TimeClock_Body"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    body.data.materials.append(mat_steel)
    apply_bevel(body, width=0.015, segments=2)

    # Esfera analógica
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.13, depth=0.03, location=(0.0, 0.12, 0.44), rotation=(1.5708, 0.0, 0.0)
    )
    face = bpy.context.active_object
    face.name = "TimeClock_Dial"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    face.data.materials.append(mat_white)

    # Bisel de latón
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.14, depth=0.02, location=(0.0, 0.115, 0.44), rotation=(1.5708, 0.0, 0.0)
    )
    ring = bpy.context.active_object
    ring.name = "TimeClock_Ring"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    ring.data.materials.append(mat_brass)

    # Ranura de fichaje
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.12, 0.18), scale=(0.26, 0.04, 0.03)
    )
    slot = bpy.context.active_object
    slot.name = "TimeClock_Slot"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    slot.data.materials.append(mat_brass)

    # Palanca lateral de perforación
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.02, depth=0.25, location=(0.22, 0.05, 0.25), rotation=(0.5, 0.0, 0.0)
    )
    lever = bpy.context.active_object
    lever.name = "TimeClock_Lever"
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    lever.data.materials.append(mat_brass)

    # Colisión centrada en el volumen combinado de carcasa y palanca
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.02, 0.015, 0.30), scale=(0.44, 0.25, 0.60)
    )
    col = bpy.context.active_object
    col.name = "TimeClock-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 8. Coche de Fuga 1984 (escape_car_84.glb)
def generate_escape_car(filename: str):
    clear_scene()
    mat_car = create_pbr_material("BurgundyCar", "BurgundyCar")
    mat_chrome = create_pbr_material("ChromeTrim", "ChromeTrim")
    mat_rubber = create_pbr_material("BakeliteBlack", "BakeliteBlack")
    mat_light = create_pbr_material("GlassAmber", "GlassAmber")

    # Chasis inferior (base sobre el asfalto en Z=0.0, centro en Z=0.45)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.45), scale=(1.80, 4.20, 0.60)
    )
    chassis = bpy.context.active_object
    chassis.name = "Car_Chassis"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    chassis.data.materials.append(mat_car)
    apply_bevel(chassis, width=0.03, segments=2)

    # Habitáculo coupé
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, -0.20, 0.95), scale=(1.50, 2.20, 0.50)
    )
    cabin = bpy.context.active_object
    cabin.name = "Car_Cabin"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    cabin.data.materials.append(mat_car)
    apply_bevel(cabin, width=0.02, segments=2)

    # Parachoques cromados
    for y_pos in [-2.15, 2.15]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0, location=(0.0, y_pos, 0.35), scale=(1.84, 0.16, 0.18)
        )
        bumper = bpy.context.active_object
        bumper.name = f"Car_Bumper_{'Front' if y_pos > 0 else 'Rear'}"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        bumper.data.materials.append(mat_chrome)

    # Faros delanteros ámbar
    for x_pos in [-0.65, 0.65]:
        bpy.ops.mesh.primitive_cube_add(
            size=1.0, location=(x_pos, 2.12, 0.52), scale=(0.35, 0.08, 0.16)
        )
        light = bpy.context.active_object
        light.name = f"Car_Headlight_{'L' if x_pos < 0 else 'R'}"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        light.data.materials.append(mat_light)

    # Ruedas (4 ruedas, radio 0.35m, apoyadas en Z=0.00 con centro en Z=0.35m)
    wheel_coords = [(-0.95, -1.30, 0.35), (0.95, -1.30, 0.35), (-0.95, 1.30, 0.35), (0.95, 1.30, 0.35)]
    for idx, (wx, wy, wz) in enumerate(wheel_coords):
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.35, depth=0.25, location=(wx, wy, wz), rotation=(0.0, 1.5708, 0.0)
        )
        wheel = bpy.context.active_object
        wheel.name = f"Wheel_{idx}"
        bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
        wheel.data.materials.append(mat_rubber)

    # Portón del maletero
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, -1.65, 0.82), scale=(1.40, 0.80, 0.08)
    )
    trunk_lid = bpy.context.active_object
    trunk_lid.name = "Car_TrunkLid"
    trunk_lid.rotation_euler = (0.45, 0.0, 0.0)
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    trunk_lid.data.materials.append(mat_car)

    # Colisión estática para Godot
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.60), scale=(2.15, 4.46, 1.20)
    )
    col = bpy.context.active_object
    col.name = "Car-col"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    export_glb(filename)


# 9. Botín Ligero: Fajo de Billetes (loot_cash.glb)
def generate_loot_cash(filename: str):
    clear_scene()
    mat_cash = create_pbr_material("CashGreen", "CashGreen")
    mat_band = create_pbr_material("PaperWhite", "PaperWhite")

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.03), scale=(0.22, 0.12, 0.06)
    )
    cash = bpy.context.active_object
    cash.name = "LootCash_Stack"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    cash.data.materials.append(mat_cash)
    apply_bevel(cash, width=0.005, segments=1)

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.031), scale=(0.05, 0.125, 0.063)
    )
    band = bpy.context.active_object
    band.name = "LootCash_Band"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    band.data.materials.append(mat_band)

    export_glb(filename)


# 10. Botín Pesado: Pieza Maestra (loot_masterpiece.glb)
def generate_loot_masterpiece(filename: str):
    clear_scene()
    mat_frame = create_pbr_material("BrassGold", "BrassGold")
    mat_canvas = create_pbr_material("CanvasOil", "CanvasOil")

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.0, 0.50), scale=(0.80, 0.08, 1.00)
    )
    frame = bpy.context.active_object
    frame.name = "Masterpiece_Frame"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    frame.data.materials.append(mat_frame)
    apply_bevel(frame, width=0.025, segments=2)

    bpy.ops.mesh.primitive_cube_add(
        size=1.0, location=(0.0, 0.015, 0.50), scale=(0.66, 0.06, 0.86)
    )
    canvas = bpy.context.active_object
    canvas.name = "Masterpiece_Canvas"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    canvas.data.materials.append(mat_canvas)

    export_glb(filename)


def main():
    print("=== [Blender CLI] Generando assets núcleo Velvet '84 (Fase 1 y 2) ===")
    generate_floor("floor_carpet.glb", "CarpetWine", "Floor_Carpet")
    generate_floor("floor_parquet.glb", "ParquetWood", "Floor_Parquet")
    generate_floor("floor_marble.glb", "MarbleWhite", "Floor_Marble")
    generate_wall("wall_mahogany.glb")
    generate_thief_pawn("thief_pawn.glb")
    generate_guard_pawn("guard_pawn.glb")
    generate_safe_box("safe_box_84.glb")
    generate_rotary_phone("rotary_phone_84.glb")
    generate_time_clock("time_clock_84.glb")
    generate_escape_car("escape_car_84.glb")
    generate_loot_cash("loot_cash.glb")
    generate_loot_masterpiece("loot_masterpiece.glb")
    print("=== [Blender CLI] Generación completada con éxito ===")


if __name__ == "__main__":
    main()
