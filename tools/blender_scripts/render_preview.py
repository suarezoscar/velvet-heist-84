#!/usr/bin/env python3
"""
tools/blender_scripts/render_preview.py
Renderiza vistas previas de assets .glb usando cámara ortográfica isométrica
según la skill /asset y las reglas de arte de Velvet Heist '84 (FEAT-009).
"""

import json
import math
import os
import sys
from pathlib import Path
from typing import List

PREVIEW_ALPHA_MIN: float = 0.01
PREVIEW_MIN_COVERAGE: float = 0.02

try:
    import bpy
    import mathutils
except ImportError:
    print("Debe ejecutarse en Blender headless.", file=sys.stderr)
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_DIR = SCRIPT_DIR.parent.parent
OUTPUT_DIR = WORKSPACE_DIR / "assets" / "previews"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def compute_coverage(png_path: str) -> float:
    """Calcula la cobertura de píxeles con canal alfa > PREVIEW_ALPHA_MIN."""
    img = bpy.data.images.load(png_path)
    try:
        try:
            import numpy as np
            arr = np.array(img.pixels)
            total = len(arr) // 4
            if total == 0:
                return 0.0
            count = int(np.count_nonzero(arr[3::4] > PREVIEW_ALPHA_MIN))
            return count / float(total)
        except Exception:
            pixels = img.pixels[:]
            total = len(pixels) // 4
            if total == 0:
                return 0.0
            count = sum(1 for a in pixels[3::4] if a > PREVIEW_ALPHA_MIN)
            return count / float(total)
    finally:
        bpy.data.images.remove(img)


def render_asset(glb_path: str, out_png: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)

    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except Exception:
        pass
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = out_png

    # Calcular bounding box visual (sin mallas de colisión)
    mesh_objs = [
        o for o in bpy.data.objects
        if o.type == "MESH"
        and not o.name.lower().endswith("-col")
        and not o.name.lower().endswith("-colonly")
    ]
    all_corners = []
    for o in mesh_objs:
        all_corners.extend([o.matrix_world @ mathutils.Vector(c) for c in o.bound_box])

    if not all_corners:
        return

    for o in bpy.data.objects:
        if o.type == "MESH" and o not in mesh_objs:
            o.hide_render = True

    min_x = min(v.x for v in all_corners)
    max_x = max(v.x for v in all_corners)
    min_y = min(v.y for v in all_corners)
    max_y = max(v.y for v in all_corners)
    min_z = min(v.z for v in all_corners)
    max_z = max(v.z for v in all_corners)

    center = mathutils.Vector(((min_x + max_x) / 2.0, (min_y + max_y) / 2.0, (min_z + max_z) / 2.0))
    diag = max(max_x - min_x, max_y - min_y, max_z - min_z, 0.01)

    # Crear cámara ortográfica isométrica
    cam_data = bpy.data.cameras.new(name="IsoCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = diag * 1.6
    cam_obj = bpy.data.objects.new("IsoCam", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    # Posición isométrica: ángulo 54.736° en X, 45° en Z
    dist = 10.0
    rad_x = math.radians(54.736)
    rad_z = math.radians(45.0)
    cam_obj.rotation_euler = (rad_x, 0.0, rad_z)
    forward = cam_obj.rotation_euler.to_matrix() @ mathutils.Vector((0, 0, -1))
    cam_obj.location = center - forward * dist

    # Luces de estudio suaves de tres puntos
    light_key = bpy.data.lights.new(name="KeyLight", type="SUN")
    light_key.energy = 3.5
    light_key.color = (1.0, 0.98, 0.94)
    key_obj = bpy.data.objects.new("KeyLight", light_key)
    key_obj.rotation_euler = (math.radians(45), math.radians(15), math.radians(30))
    scene.collection.objects.link(key_obj)

    light_fill = bpy.data.lights.new(name="FillLight", type="SUN")
    light_fill.energy = 1.2
    light_fill.color = (0.85, 0.90, 1.0)
    fill_obj = bpy.data.objects.new("FillLight", light_fill)
    fill_obj.rotation_euler = (math.radians(60), math.radians(-30), math.radians(-135))
    scene.collection.objects.link(fill_obj)

    bpy.ops.render.render(write_still=True)


def get_spec_names(specs_dir: Path) -> List[str]:
    names = []
    for p in sorted(specs_dir.glob("*.json")):
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
                name = data.get("name")
                if name:
                    names.append(name)
                else:
                    names.append(p.stem)
        except Exception:
            names.append(p.stem)
    return names


def main():
    argv = sys.argv
    user_args = []
    if "--" in argv:
        user_args = argv[argv.index("--") + 1 :]

    specs_dir = SCRIPT_DIR / "specs"
    models_dir = WORKSPACE_DIR / "assets" / "models"

    if user_args:
        names = [a[:-4] if a.endswith(".glb") else a for a in user_args]
    else:
        names = get_spec_names(specs_dir)

    has_failure = False
    for name in names:
        glb_path = models_dir / f"{name}.glb"
        if not glb_path.is_file():
            print(f"Error: No existe el modelo GLB para '{name}': {glb_path}", file=sys.stderr)
            has_failure = True
            continue

        png_path = OUTPUT_DIR / f"{name}_iso.png"
        render_asset(str(glb_path), str(png_path))
        cov = compute_coverage(str(png_path))
        print(f"PREVIEW {name} {cov * 100:.1f}%")
        if cov < PREVIEW_MIN_COVERAGE:
            print(
                f"Error: Cobertura insuficiente para '{name}': {cov * 100:.1f}% < {PREVIEW_MIN_COVERAGE * 100:.1f}%",
                file=sys.stderr,
            )
            has_failure = True

    if has_failure:
        sys.exit(1)


if __name__ == "__main__":
    main()
