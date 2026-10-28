#!/usr/bin/env python3
"""
tools/blender_scripts/gen_heist_art.py
Genera proceduralmente (headless bpy) las obras propias del museo ampliado (FEAT-034):
- codex_book.glb: el Códice iluminado de la Biblioteca de Manuscritos, cerrado, con tapas de
  piel granate, el bloque de páginas y dos cierres de latón.

Regla 02: paleta 'Velvet 84' (lib/palette.py), 1 unidad = 1 m, pivote bottom_center,
transformaciones aplicadas y Bevel horneado.

Uso:
  blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/gen_heist_art.py
"""

import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
LIB_DIR = SCRIPT_DIR / "lib"
for p in [str(SCRIPT_DIR), str(LIB_DIR)]:
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    import bpy
    from lib.palette import create_pbr_material
    from lib.blender_utils import center_by_pivot
except ImportError:
    print("Error: Este script debe ejecutarse dentro de Blender headless (blender -b -P <script.py>).")
    sys.exit(1)

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models"))

# Medidas del códice (m): largo, ancho y grosor de cada parte
COVER = (0.32, 0.24, 0.012)
PAGES = (0.30, 0.226, 0.056)
SPINE = (0.32, 0.016, 0.08)
CLASP = (0.03, 0.05, 0.05)


def box(name, size, location, material):
    """Caja con su material y Bevel horneado (≤ 10 % de la menor medida)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    mod = obj.modifiers.new(name="bevel_mod", type="BEVEL")
    mod.width = min(0.004, min(size) * 0.1)
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier="bevel_mod")
    return obj


def generate_codex_book(filename="codex_book.glb"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    leather = create_pbr_material("CarpetWine", "CarpetWine")
    paper = create_pbr_material("PaperWhite", "PaperWhite")
    brass = create_pbr_material("BrassGold", "BrassGold")
    half_t = COVER[2] * 0.5
    parts = [
        box("CodexBook_CoverBottom", COVER, (0.0, 0.0, half_t), leather),
        box("CodexBook_Pages", PAGES, (0.006, 0.0, COVER[2] + PAGES[2] * 0.5), paper),
        box("CodexBook_CoverTop", COVER, (0.0, 0.0, COVER[2] + PAGES[2] + half_t), leather),
        box("CodexBook_Spine", SPINE, (0.0, -(COVER[1] + SPINE[1]) * 0.5, SPINE[2] * 0.5), leather),
    ]
    clasp_z = COVER[2] + PAGES[2] * 0.5
    for index, x in enumerate((-0.08, 0.08)):
        parts.append(box("CodexBook_Clasp_%d" % index, CLASP, (x, (COVER[1] + CLASP[1]) * 0.5 - 0.02, clasp_z), brass))
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    center_by_pivot(parts, "bottom_center")
    path = os.path.join(OUTPUT_DIR, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True, export_yup=True)
    print(f"[Blender CLI] Asset exportado: {path} ({os.path.getsize(path)} bytes)")


if __name__ == "__main__":
    generate_codex_book()
