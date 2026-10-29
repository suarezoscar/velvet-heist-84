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
    from lib.palette import PALETTE, create_pbr_material
    from lib.blender_utils import center_by_pivot
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





# 3. Caja Fuerte Años 80 (safe_box_84.glb)
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
    col.name = "SafeBox-colonly"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    center_by_pivot(list(bpy.data.objects), "bottom_center")
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
    col.name = "RotaryPhone-colonly"
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
    col.name = "TimeClock-colonly"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

    center_by_pivot(list(bpy.data.objects), "bottom_center")
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
    col.name = "Car-colonly"
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


GENERATORS = {
    "safe_box_84": lambda: generate_safe_box("safe_box_84.glb"),
    "rotary_phone_84": lambda: generate_rotary_phone("rotary_phone_84.glb"),
    "time_clock_84": lambda: generate_time_clock("time_clock_84.glb"),
    "escape_car_84": lambda: generate_escape_car("escape_car_84.glb"),
    "loot_cash": lambda: generate_loot_cash("loot_cash.glb"),
}


def main():
    argv = sys.argv
    targets = []
    if "--" in argv:
        targets = argv[argv.index("--") + 1:]

    normalized_targets = [t[:-4] if t.endswith(".glb") else t for t in targets]

    if normalized_targets:
        for t in normalized_targets:
            if t in GENERATORS:
                print(f"=== Generando {t} ===")
                GENERATORS[t]()
            else:
                print(f"Aviso: Generador desconocido para '{t}'", file=sys.stderr)
                sys.exit(1)
    else:
        print("=== [Blender CLI] Generando assets núcleo Velvet '84 ===")
        for name, gen_fn in GENERATORS.items():
            print(f"=== Generando {name} ===")
            gen_fn()
        print("=== [Blender CLI] Generación completada con éxito ===")


if __name__ == "__main__":
    main()
