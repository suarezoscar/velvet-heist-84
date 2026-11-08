"""
gen_museum_props.py
Muebles de cobertura del museo (#178, fase 3): sustituyen a las cajas de color. Low-poly, de
cajas biseladas y sin texturas, con la paleta corta de materiales (dos maderas, acero, mármol,
pintura de servicio y cartón). Cada uno se hace con la medida más común de su tipo en el nivel
y MuseumPropFit lo estira a la caja de colisión exacta de cada ejemplar: el juego no cambia.

Todo con pivote bottom_center, eje X a lo ancho, Y (Blender) de fondo y Z de alto.
Uso: blender -b -P tools/blender_scripts/gen_museum_props.py
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
BEVEL = 0.008


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(key):
    return create_pbr_material(key, key)


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


def prop_shelf():
    """Estantería de archivo 2,0 × 0,5 × 2,2, abierta por los dos lados (se lee desde cualquier
    lado): costados, baldas, un montante central y cajas de cartón con huecos."""
    clear_scene()
    wood, paper = mat("ParquetWood"), mat("ArchivePaper")
    w, d, h = 2.0, 0.5, 2.2
    objs = [
        box("SideL", (0.05, d, h), (-w / 2 + 0.025, 0, h / 2), wood),
        box("SideR", (0.05, d, h), (w / 2 - 0.025, 0, h / 2), wood),
        box("Mid", (0.04, d, h - 0.1), (0, 0, h / 2), wood),
    ]
    levels = [0.08, 0.6, 1.12, 1.64, 2.17]
    for i, z in enumerate(levels):
        objs.append(box(f"Shelf{i}", (w - 0.1, d, 0.04), (0, 0, z), wood))
    # Cajas de archivo en las cuatro primeras baldas, alternando huecos
    for i, z in enumerate(levels[:4]):
        for j, x in enumerate((-0.72, -0.3, 0.3, 0.72)):
            if (i + j) % 3 == 1:
                continue
            objs.append(box(f"Box{i}{j}", (0.34, 0.4, 0.3), (x, 0, z + 0.17), paper))
    export(objs, "prop_shelf")


def prop_crate():
    """Caja de embalaje 1,0 × 1,0 × 1,0 con cantoneras de madera oscura."""
    clear_scene()
    light, dark = mat("ParquetWood"), mat("MahoganyWood")
    s = 1.0
    objs = [box("Body", (s - 0.04, s - 0.04, s - 0.04), (0, 0, s / 2), light)]
    for x in (-1, 1):
        for y in (-1, 1):
            objs.append(box(f"Post{x}{y}", (0.08, 0.08, s), (x * 0.46, y * 0.46, s / 2), dark))
    for z in (0.04, s - 0.04):
        objs.append(box(f"RimX{z}", (s, 0.08, 0.08), (0, 0.46, z), dark))
        objs.append(box(f"RimXb{z}", (s, 0.08, 0.08), (0, -0.46, z), dark))
        objs.append(box(f"RimY{z}", (0.08, s, 0.08), (0.46, 0, z), dark))
        objs.append(box(f"RimYb{z}", (0.08, s, 0.08), (-0.46, 0, z), dark))
    export(objs, "prop_crate")


def prop_statue():
    """Estatua 0,8 × 0,8 × 2,0: peana de mármol y figura sencilla de bloques."""
    clear_scene()
    marble = mat("MarbleWhite")
    objs = [
        box("Plinth", (0.8, 0.8, 0.9), (0, 0, 0.45), marble),
        box("PlinthCap", (0.86, 0.86, 0.06), (0, 0, 0.93), marble),
        box("Legs", (0.34, 0.22, 0.45), (0, 0, 1.185), marble),
        box("Torso", (0.42, 0.26, 0.42), (0, 0, 1.62), marble),
        box("ArmL", (0.1, 0.12, 0.4), (-0.27, 0, 1.6), marble),
        box("ArmR", (0.1, 0.12, 0.4), (0.27, 0.04, 1.62), marble),
        box("Head", (0.2, 0.2, 0.22), (0, 0, 1.92), marble),
    ]
    export(objs, "prop_statue")


def prop_cabinet():
    """Armario 1,0 × 0,5 × 1,8 de caoba con dos puertas, zócalo y tiradores de latón."""
    clear_scene()
    wood, brass = mat("MahoganyWood"), mat("BrassGold")
    w, d, h = 1.0, 0.5, 1.8
    objs = [
        box("Body", (w, d, h - 0.1), (0, 0, (h - 0.1) / 2 + 0.1), wood),
        box("Plinth", (w - 0.06, d - 0.06, 0.1), (0, 0, 0.05), wood),
        box("Crown", (w + 0.04, d + 0.04, 0.05), (0, 0, h - 0.025), wood),
    ]
    for x in (-0.245, 0.245):
        objs.append(box(f"Door{x}", (0.45, 0.02, 1.5), (x, -d / 2 - 0.01, 0.95), wood))
        objs.append(box(f"Knob{x}", (0.03, 0.03, 0.12), (x * 0.25, -d / 2 - 0.03, 1.0), brass))
    export(objs, "prop_cabinet")


def prop_table():
    """Mesa 1,6 × 0,9 × 0,78 de caoba: tablero, faldón y patas."""
    clear_scene()
    wood = mat("MahoganyWood")
    w, d, h = 1.6, 0.9, 0.78
    objs = [
        box("Top", (w, d, 0.05), (0, 0, h - 0.025), wood),
        box("ApronX", (w - 0.12, 0.03, 0.1), (0, d / 2 - 0.07, h - 0.1), wood),
        box("ApronXb", (w - 0.12, 0.03, 0.1), (0, -d / 2 + 0.07, h - 0.1), wood),
    ]
    for x in (-1, 1):
        for y in (-1, 1):
            leg = (x * (w / 2 - 0.07), y * (d / 2 - 0.07), (h - 0.05) / 2)
            objs.append(box(f"Leg{x}{y}", (0.07, 0.07, h - 0.05), leg, wood))
    export(objs, "prop_table")


def prop_locker():
    """Fila de tres taquillas 1,6 × 0,5 × 1,9 de chapa pintada, con rejillas y tiradores."""
    clear_scene()
    paint, steel = mat("ServicePaint"), mat("Steel80s")
    w, d, h = 1.6, 0.5, 1.9
    objs = [
        box("Body", (w, d, h - 0.08), (0, 0, (h - 0.08) / 2 + 0.08), paint),
        box("Base", (w - 0.04, d - 0.04, 0.08), (0, 0, 0.04), steel),
    ]
    door_w = w / 3
    for i in range(3):
        x = -w / 2 + door_w * (i + 0.5)
        objs.append(box(f"Door{i}", (door_w - 0.03, 0.02, h - 0.16), (x, -d / 2 - 0.01, h / 2 + 0.04), paint))
        objs.append(box(f"Handle{i}", (0.03, 0.03, 0.14), (x + door_w * 0.32, -d / 2 - 0.03, 1.0), steel))
        for k in range(3):
            objs.append(box(f"Vent{i}{k}", (door_w * 0.5, 0.01, 0.025), (x, -d / 2 - 0.022, 1.6 + k * 0.06), steel))
    export(objs, "prop_locker")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    prop_shelf()
    prop_crate()
    prop_statue()
    prop_cabinet()
    prop_table()
    prop_locker()


if __name__ == "__main__":
    main()
