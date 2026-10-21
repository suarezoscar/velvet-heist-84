#!/usr/bin/env python3
"""
tools/blender_scripts/render_preview.py
Renderiza vistas previas de assets .glb usando cámara ortográfica isométrica
según la skill /asset y las reglas de arte de Velvet Heist '84.
"""

import math
import os
import sys
from pathlib import Path

try:
    import bpy
    import mathutils
except ImportError:
    print("Debe ejecutarse en Blender headless.")
    sys.exit(1)

OUTPUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "assets", "previews")
)
os.makedirs(OUTPUT_DIR, exist_ok=True)


def render_asset(glb_path: str, out_png: str):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)

    # Configuración de motor de render
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = out_png

    # Calcular bounding box
    mesh_objs = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith("-col") and not o.name.endswith("-colonly")]
    all_corners = []
    for o in mesh_objs:
        all_corners.extend([o.matrix_world @ mathutils.Vector(c) for c in o.bound_box])

    if not all_corners:
        return

    min_x = min(v.x for v in all_corners)
    max_x = max(v.x for v in all_corners)
    min_y = min(v.y for v in all_corners)
    max_y = max(v.y for v in all_corners)
    min_z = min(v.z for v in all_corners)
    max_z = max(v.z for v in all_corners)

    center = mathutils.Vector(((min_x + max_x) / 2.0, (min_y + max_y) / 2.0, (min_z + max_z) / 2.0))
    diag = max(max_x - min_x, max_y - min_y, max_z - min_z, 0.5)

    # Crear cámara ortográfica isométrica
    cam_data = bpy.data.cameras.new(name="IsoCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = diag * 1.8
    cam_obj = bpy.data.objects.new("IsoCam", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    # Posición isométrica: ángulo 54.736° en X, 45° en Z (o (-35.264°, 45°) en Godot)
    dist = 10.0
    rad_x = math.radians(54.736)
    rad_z = math.radians(45.0)
    cam_obj.rotation_euler = (rad_x, 0.0, rad_z)
    offset = mathutils.Vector((
        -dist * math.cos(rad_x) * math.sin(rad_z),
        -dist * math.cos(rad_x) * math.cos(rad_z),
        dist * math.sin(rad_x)
    ))
    cam_obj.location = center + offset

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
    print(f"Renderizado: {out_png}")


def main():
    assets = [
        "safe_box_84.glb",
        "time_clock_84.glb",
        "rotary_phone_84.glb",
        "thief_pawn.glb",
        "guard_pawn.glb",
        "wall_mahogany.glb",
        "floor_carpet.glb",
        "escape_car_84.glb",
    ]
    models_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models"))
    for a in assets:
        glb = os.path.join(models_dir, a)
        if os.path.exists(glb):
            png = os.path.join(OUTPUT_DIR, a.replace(".glb", "_iso.png"))
            render_asset(glb, png)


if __name__ == "__main__":
    main()
