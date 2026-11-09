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


def beam(name, a, b, t, material):
    """Listón de sección t × t entre los puntos a y b (para patas inclinadas)."""
    from mathutils import Vector

    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (t, t, d.length), (a + b) / 2, material)
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def tilt_x(obj, degrees):
    """Inclina el objeto alrededor de su centro en el eje X."""
    from math import radians

    obj.rotation_euler = (radians(degrees), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)


def prop_armchair():
    """Butaca 0,7 × 0,7 × 1,0: asiento y respaldo de granate, brazos y patas cortas de caoba."""
    clear_scene()
    wood, wine = mat("MahoganyWood"), mat("CarpetWine")
    objs = []
    for x in (-1, 1):
        for y in (-1, 1):
            objs.append(box(f"Leg{x}{y}", (0.06, 0.06, 0.15), (x * 0.29, y * 0.29, 0.075), wood))
        objs.append(box(f"Arm{x}", (0.1, 0.7, 0.4), (x * 0.3, 0, 0.35), wood))
    objs += [
        box("Seat", (0.5, 0.58, 0.2), (0, -0.06, 0.25), wine),
        box("Cushion", (0.48, 0.54, 0.08), (0, -0.06, 0.39), wine),
        box("Back", (0.7, 0.12, 0.85), (0, 0.29, 0.575), wine),
    ]
    export(objs, "prop_armchair")


def prop_boiler():
    """Caldera 1,2 × 1,2 × 2,0: cuerpo de pintura de servicio sobre base de acero, con tres
    tubos verticales y una placa de latón."""
    clear_scene()
    paint, steel, brass = mat("ServicePaint"), mat("Steel80s"), mat("BrassGold")
    objs = [
        box("Base", (1.2, 1.2, 0.2), (0, 0, 0.1), steel),
        box("Body", (1.0, 1.0, 1.75), (0, 0, 1.075), paint),
        box("Cap", (0.7, 0.7, 0.05), (0, 0, 1.975), paint),
        box("Plate", (0.3, 0.02, 0.2), (0, -0.51, 1.4), brass),
    ]
    for i, (x, y) in enumerate(((-0.4, -0.54), (0.4, -0.54), (0.0, 0.54))):
        objs.append(box(f"Pipe{i}", (0.08, 0.08, 1.7), (x, y, 1.05), steel))
    export(objs, "prop_boiler")


def prop_chair():
    """Silla de madera 0,5 × 0,5 × 1,0: cuatro patas, asiento a 0,45 m y respaldo hasta 1,0 m."""
    clear_scene()
    wood = mat("MahoganyWood")
    objs = [box("Seat", (0.5, 0.5, 0.04), (0, 0, 0.43), wood)]
    for x in (-1, 1):
        objs.append(box(f"LegF{x}", (0.05, 0.05, 0.41), (x * 0.225, -0.225, 0.205), wood))
        objs.append(box(f"LegB{x}", (0.05, 0.05, 1.0), (x * 0.225, 0.225, 0.5), wood))
    objs.append(box("Slat1", (0.4, 0.03, 0.12), (0, 0.225, 0.62), wood))
    objs.append(box("Slat2", (0.4, 0.03, 0.12), (0, 0.225, 0.85), wood))
    export(objs, "prop_chair")


def prop_container():
    """Contenedor de mercancía 1,8 × 1,0 × 1,3: cuerpo de pintura de servicio con nervios
    verticales de acero cada 0,3 m en las caras largas."""
    clear_scene()
    paint, steel = mat("ServicePaint"), mat("Steel80s")
    objs = [box("Body", (1.8, 0.96, 1.3), (0, 0, 0.65), paint)]
    for i in range(6):
        x = -0.75 + 0.3 * i
        for y in (-1, 1):
            objs.append(box(f"Rib{i}{y}", (0.06, 0.04, 1.2), (x, y * 0.48, 0.65), steel))
    export(objs, "prop_container")


def prop_counter():
    """Mostrador 3,0 × 0,8 × 1,1: cuerpo de caoba, encimera de mármol que sobresale 0,03 m
    y zócalo negro."""
    clear_scene()
    wood, marble, black = mat("MahoganyWood"), mat("MarbleWhite"), mat("BakeliteBlack")
    objs = [
        box("Plinth", (2.9, 0.7, 0.1), (0, 0, 0.05), black),
        box("Body", (2.94, 0.74, 0.96), (0, 0, 0.58), wood),
        box("Top", (3.0, 0.8, 0.04), (0, 0, 1.08), marble),
    ]
    for i, x in enumerate((-0.95, 0, 0.95)):
        objs.append(box(f"Panel{i}", (0.85, 0.02, 0.7), (x, -0.38, 0.58), wood))
    export(objs, "prop_counter")


def prop_desk():
    """Escritorio 1,6 × 0,8 × 0,75 de caoba: tablero, cajonero a un lado, dos patas al otro
    y tiradores de latón."""
    clear_scene()
    wood, brass = mat("MahoganyWood"), mat("BrassGold")
    objs = [
        box("Top", (1.6, 0.8, 0.04), (0, 0, 0.73), wood),
        box("Drawers", (0.4, 0.7, 0.71), (-0.6, 0, 0.355), wood),
        box("Panel", (1.0, 0.02, 0.4), (0.0, 0.33, 0.5), wood),
    ]
    for y in (-0.33, 0.33):
        objs.append(box(f"Leg{y}", (0.05, 0.05, 0.71), (0.75, y, 0.355), wood))
    for i, z in enumerate((0.15, 0.35, 0.55)):
        objs.append(box(f"Pull{i}", (0.12, 0.02, 0.03), (-0.6, -0.36, z), brass))
    export(objs, "prop_desk")


def prop_easel():
    """Caballete 0,8 × 0,8 × 1,8: tres patas inclinadas de parqué con pies planos, travesaño
    y un lienzo de 0,6 × 0,04 × 0,7 apoyado a media altura."""
    clear_scene()
    wood, canvas = mat("ParquetWood"), mat("CanvasOil")
    objs = []
    feet = ((-0.36, -0.36), (0.36, -0.36), (0.0, 0.36))
    tops = ((-0.04, -0.05), (0.04, -0.05), (0.0, 0.05))
    for i, ((fx, fy), (tx, ty)) in enumerate(zip(feet, tops)):
        objs.append(box(f"Foot{i}", (0.08, 0.08, 0.02), (fx, fy, 0.01), wood))
        objs.append(beam(f"Leg{i}", (fx, fy, 0.02), (tx, ty, 1.72), 0.05, wood))
    objs += [
        box("Bar", (0.36, 0.05, 0.04), (0, -0.05, 1.78), wood),
        box("Ledge", (0.6, 0.1, 0.03), (0, -0.25, 0.53), wood),
        box("Canvas", (0.6, 0.04, 0.7), (0, -0.22, 0.915), canvas),
    ]
    export(objs, "prop_easel")


def prop_forklift():
    """Carretilla de mano 0,6 × 0,5 × 1,2: dos largueros y una pala de acero, con dos ruedas
    negras de 0,08 × 0,2 × 0,2."""
    clear_scene()
    steel, black = mat("Steel80s"), mat("BakeliteBlack")
    objs = [
        box("Blade", (0.44, 0.5, 0.03), (0, 0, 0.015), steel),
        box("Handle", (0.44, 0.04, 0.04), (0, 0.2, 1.18), steel),
        box("Rail", (0.44, 0.04, 0.04), (0, 0.2, 0.5), steel),
    ]
    for x in (-1, 1):
        objs.append(box(f"Upright{x}", (0.04, 0.04, 1.2), (x * 0.2, 0.2, 0.6), steel))
        objs.append(box(f"Wheel{x}", (0.08, 0.2, 0.2), (x * 0.26, 0.15, 0.1), black))
    export(objs, "prop_forklift")


def prop_fountain():
    """Fuente 2,0 × 2,0 × 0,8: pila cuadrada de mármol (paredes de 0,12 × 0,6), agua de acero
    a 0,5 m y surtidor central hasta 0,8."""
    clear_scene()
    marble, steel = mat("MarbleWhite"), mat("Steel80s")
    objs = [
        box("Floor", (1.76, 1.76, 0.48), (0, 0, 0.24), marble),
        box("Water", (1.74, 1.74, 0.04), (0, 0, 0.49), steel),
        box("WallN", (2.0, 0.12, 0.6), (0, 0.94, 0.3), marble),
        box("WallS", (2.0, 0.12, 0.6), (0, -0.94, 0.3), marble),
        box("WallE", (0.12, 1.76, 0.6), (0.94, 0, 0.3), marble),
        box("WallW", (0.12, 1.76, 0.6), (-0.94, 0, 0.3), marble),
        box("Spout", (0.2, 0.2, 0.8), (0, 0, 0.4), marble),
        box("Bowl", (0.5, 0.5, 0.06), (0, 0, 0.55), marble),
    ]
    export(objs, "prop_fountain")


def prop_generator():
    """Grupo electrógeno 2,0 × 1,0 × 1,4: cuerpo de pintura de servicio sobre bancada de acero,
    rejilla de cuatro lamas en una cara larga y tapa negra."""
    clear_scene()
    paint, steel, black = mat("ServicePaint"), mat("Steel80s"), mat("BakeliteBlack")
    objs = [
        box("Bed", (2.0, 1.0, 0.15), (0, 0, 0.075), steel),
        box("Body", (1.9, 0.9, 1.1), (0, 0, 0.7), paint),
        box("Lid", (1.94, 0.94, 0.15), (0, 0, 1.325), black),
    ]
    for i in range(4):
        objs.append(box(f"Slat{i}", (1.0, 0.02, 0.04), (0.3, -0.46, 0.45 + 0.15 * i), steel))
    export(objs, "prop_generator")


def prop_jar_pedestal():
    """Peana con jarrón 0,6 × 0,6 × 1,0: peana de mármol de 0,5 × 0,5 × 0,7 con base y cornisa,
    y jarrón de latón de dos cajas (cuerpo y cuello)."""
    clear_scene()
    marble, brass = mat("MarbleWhite"), mat("BrassGold")
    objs = [
        box("Pedestal", (0.5, 0.5, 0.7), (0, 0, 0.35), marble),
        box("Base", (0.6, 0.6, 0.08), (0, 0, 0.04), marble),
        box("Cornice", (0.6, 0.6, 0.06), (0, 0, 0.67), marble),
        box("JarBody", (0.24, 0.24, 0.22), (0, 0, 0.81), brass),
        box("JarNeck", (0.12, 0.12, 0.08), (0, 0, 0.96), brass),
    ]
    export(objs, "prop_jar_pedestal")


def prop_key_cabinet():
    """Armario de llaves 0,8 × 0,4 × 1,8: cuerpo de pintura de servicio, puerta saliente y en
    su cara frontal una placa negra con 3 filas de 4 ganchos de latón."""
    clear_scene()
    paint, black, brass = mat("ServicePaint"), mat("BakeliteBlack"), mat("BrassGold")
    objs = [
        box("Body", (0.8, 0.32, 1.8), (0, 0.04, 0.9), paint),
        box("Door", (0.76, 0.04, 1.7), (0, -0.14, 0.9), paint),
        box("Plate", (0.62, 0.01, 0.95), (0, -0.165, 1.0), black),
    ]
    for r, z in enumerate((1.25, 1.0, 0.75)):
        for c, x in enumerate((-0.21, -0.07, 0.07, 0.21)):
            objs.append(box(f"Hook{r}{c}", (0.03, 0.03, 0.04), (x, -0.185, z), brass))
    export(objs, "prop_key_cabinet")


def prop_pallet():
    """Palé con carga 1,2 × 0,8 × 1,2: palé de parqué de 0,15 (tres tablas y nueve tacos) con
    tres pisos de cajas de cartón y un fleje negro."""
    clear_scene()
    wood, paper, black = mat("ParquetWood"), mat("ArchivePaper"), mat("BakeliteBlack")
    objs = []
    for i, y in enumerate((-0.3, 0, 0.3)):
        objs.append(box(f"Board{i}", (1.2, 0.2, 0.03), (0, y, 0.135), wood))
        for j, x in enumerate((-0.54, 0, 0.54)):
            objs.append(box(f"Block{i}{j}", (0.12, 0.12, 0.12), (x, y, 0.06), wood))
    for k in range(3):
        z = 0.15 + 0.35 * k + 0.175
        for x in (-0.29, 0.29):
            for y in (-0.19, 0.19):
                objs.append(box(f"Carton{k}{x}{y}", (0.56, 0.36, 0.35), (x, y, z), paper))
    for y in (-0.39, 0.39):
        objs.append(box(f"StrapF{y}", (1.18, 0.02, 0.04), (0, y, 0.675), black))
    for x in (-0.59, 0.59):
        objs.append(box(f"StrapS{x}", (0.02, 0.76, 0.04), (x, 0, 0.675), black))
    export(objs, "prop_pallet")


def prop_sarcophagus():
    """Sarcófago egipcio 2,2 × 0,8 × 1,0 sobre tarima de mármol de 0,2: cuerpo de latón en dos
    cajas apiladas (la de arriba más estrecha) y bandas negras."""
    clear_scene()
    marble, brass, black = mat("MarbleWhite"), mat("BrassGold"), mat("BakeliteBlack")
    objs = [
        box("Dais", (2.2, 0.8, 0.2), (0, 0, 0.1), marble),
        box("Lower", (2.0, 0.6, 0.45), (0, 0, 0.425), brass),
        box("Upper", (1.7, 0.45, 0.35), (0, 0, 0.825), brass),
    ]
    for i, x in enumerate((-0.6, 0, 0.6)):
        objs.append(box(f"BandL{i}", (0.08, 0.62, 0.3), (x, 0, 0.425), black))
        objs.append(box(f"BandU{i}", (0.08, 0.47, 0.3), (x, 0, 0.84), black))
    export(objs, "prop_sarcophagus")


def prop_trash_bin():
    """Contenedor de basura 1,8 × 1,0 × 1,3: cuerpo de pintura de servicio, tapa de acero
    inclinada 5° y cuatro ruedas negras."""
    clear_scene()
    paint, steel, black = mat("ServicePaint"), mat("Steel80s"), mat("BakeliteBlack")
    objs = [box("Body", (1.8, 1.0, 1.01), (0, 0, 0.645), paint)]
    lid = box("Lid", (1.8, 0.98, 0.06), (0, 0, 1.2273), steel)
    tilt_x(lid, 5)
    objs.append(lid)
    for x in (-1, 1):
        for y in (-1, 1):
            objs.append(box(f"Wheel{x}{y}", (0.05, 0.12, 0.14), (x * 0.8, y * 0.4, 0.07), black))
    export(objs, "prop_trash_bin")


def prop_wardrobe():
    """Guardarropa 1,8 × 0,6 × 1,8: estructura de caoba con barra arriba y cinco abrigos
    colgados de 0,3 × 0,5 × 1,0 (negro, azul guardia y granate alternados)."""
    clear_scene()
    wood = mat("MahoganyWood")
    coats = [mat("VelvetBlack"), mat("GuardNavy"), mat("CarpetWine")]
    objs = [
        box("Base", (1.8, 0.6, 0.08), (0, 0, 0.04), wood),
        box("Roof", (1.8, 0.6, 0.06), (0, 0, 1.77), wood),
        box("Back", (1.7, 0.02, 1.66), (0, 0.29, 0.91), wood),
        box("Rail", (1.7, 0.03, 0.03), (0, 0, 1.64), wood),
    ]
    for x in (-1, 1):
        objs.append(box(f"Side{x}", (0.05, 0.6, 1.8), (x * 0.875, 0, 0.9), wood))
    for i in range(5):
        x = -0.68 + 0.34 * i
        objs.append(box(f"Coat{i}", (0.3, 0.5, 1.0), (x, 0, 1.12), coats[i % 3]))
    export(objs, "prop_wardrobe")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    prop_shelf()
    prop_crate()
    prop_statue()
    prop_cabinet()
    prop_table()
    prop_locker()
    prop_armchair()
    prop_boiler()
    prop_chair()
    prop_container()
    prop_counter()
    prop_desk()
    prop_easel()
    prop_forklift()
    prop_fountain()
    prop_generator()
    prop_jar_pedestal()
    prop_key_cabinet()
    prop_pallet()
    prop_sarcophagus()
    prop_trash_bin()
    prop_wardrobe()


if __name__ == "__main__":
    main()
