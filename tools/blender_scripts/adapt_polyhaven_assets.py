#!/usr/bin/env python3
"""tools/blender_scripts/adapt_polyhaven_assets.py.

Adapta los assets CC0 de Poly Haven (FEAT-010; coffee_cart en FEAT-029; obras y decorado del
museo ampliado en FEAT-034):
- Conserva copia intacta en assets/models/raw/polyhaven/<name>.glb
- Elimina armatures, icospheres auxiliares y colisiones heredadas
- Aplica transformaciones
- Reduce con Decimate (COLLAPSE) al presupuesto (2000 o 5000 triángulos)
- Centra según tipo de pivote (bottom_center, top_center, back_center)
- Genera colisión <name>-colonly si la ficha lo requiere
- Exporta a assets/models/<name>.glb

Uso:
  blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/adapt_polyhaven_assets.py -- [<name> ...]
"""

import shutil
import sys
from pathlib import Path
from typing import Any, Dict

SCRIPT_DIR = Path(__file__).resolve().parent
LIB_DIR = SCRIPT_DIR / "lib"
for p in [str(SCRIPT_DIR), str(LIB_DIR)]:
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    import bpy
    from lib.blender_utils import (
        add_box_collision,
        center_by_pivot,
        count_mesh_triangles,
        decimate_to_budget,
        is_collision_object,
    )
except ImportError as e:
    print(f"Error importando dependencias en Blender: {e}", file=sys.stderr)
    sys.exit(1)

WORKSPACE_DIR = SCRIPT_DIR.parent.parent
MODELS_DIR = WORKSPACE_DIR / "assets" / "models"
RAW_DIR = MODELS_DIR / "raw" / "polyhaven"

ASSETS: Dict[str, Dict[str, Any]] = {
    "ceramic_vase": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": True,
    },
    "chandelier": {
        "pivot": "top_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "grandfather_clock": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": True,
    },
    "marble_bust": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": True,
    },
    "metal_office_desk": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": True,
    },
    "picture_frame": {
        "pivot": "back_center",
        "max_triangles": 2000,
        "collision": False,
    },
    "coffee_cart": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": True,
    },
    "security_tv": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": True,
    },
    # FEAT-034: obras del museo ampliado y decorado (piezas ≤ 5000, decorado ≤ 2000)
    "pocket_watch": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "antique_vase": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "brass_vase": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "gothic_statue": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "katana_stand": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "horse_statue": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "cat_statue": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "horse_head": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "bull_head": {
        "pivot": "bottom_center",
        "max_triangles": 5000,
        "collision": False,
    },
    "museum_bench": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": False,
    },
    "planter": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": False,
    },
    "chinese_screen": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": False,
    },
    "wall_clock": {
        "pivot": "back_center",
        "max_triangles": 2000,
        "collision": False,
    },
    "fluorescent_light": {
        "pivot": "top_center",
        "max_triangles": 2000,
        "collision": False,
    },
    "wooden_elephant": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": False,
    },
    "chinese_cabinet": {
        "pivot": "bottom_center",
        "max_triangles": 2000,
        "collision": False,
    },
}


def clean_scene_hierarchy():
    """Separa hijos de armatures manteniendo transformaciones y elimina armatures."""
    for obj in list(bpy.data.objects):
        if obj.type == "ARMATURE":
            for child in list(obj.children):
                child.select_set(True)
                bpy.context.view_layer.objects.active = child
                bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
                child.select_set(False)
            bpy.data.objects.remove(obj, do_unlink=True)

    # Eliminar modificadores Armature de las mallas
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            for mod in list(obj.modifiers):
                if mod.type == "ARMATURE":
                    obj.modifiers.remove(mod)
            # Las shape keys impiden aplicar Decimate (horse_statue): se queda la forma base
            if obj.data.shape_keys is not None:
                obj.shape_key_clear()

    # Eliminar cualquier objeto que no sea malla visual (armatures, icospheres, colisiones)
    for obj in list(bpy.data.objects):
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
        elif "icosphere" in obj.name.lower():
            bpy.data.objects.remove(obj, do_unlink=True)
        elif is_collision_object(obj):
            bpy.data.objects.remove(obj, do_unlink=True)


def adapt_asset(name: str, config: Dict[str, Any]) -> int:
    """Adapta un asset Poly Haven y devuelve su número final de triángulos."""
    dest_glb = MODELS_DIR / f"{name}.glb"
    raw_glb = RAW_DIR / f"{name}.glb"

    RAW_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Copia intacta en raw/ si no existe
    if not raw_glb.is_file():
        if not dest_glb.is_file():
            raise FileNotFoundError(f"No existe ni la fuente {raw_glb} ni el modelo {dest_glb}")
        shutil.copy2(str(dest_glb), str(raw_glb))
        print(f"[{name}] Copiado a raw: {raw_glb}")

    # 2. Importar la copia intacta
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(raw_glb))

    # Limpiar jerarquía (armatures, icospheres, colisiones)
    clean_scene_hierarchy()

    # 3. Aplicar transformaciones a mallas visuales
    visual_objs = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    for obj in visual_objs:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.select_set(False)

    # Reducir al presupuesto
    final_tris = decimate_to_budget(visual_objs, config["max_triangles"])

    # Centrar y colocar pivote
    center_by_pivot(visual_objs, config["pivot"])

    # Añadir colisión si la ficha lo requiere
    if config["collision"]:
        add_box_collision(visual_objs, name)

    # 4. Exportar
    bpy.ops.export_scene.gltf(
        filepath=str(dest_glb),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
    )

    print(f"ADAPT {name}: {final_tris} triángulos (max {config['max_triangles']}) -> {dest_glb.name}")
    return final_tris


def main():
    argv = sys.argv
    targets = []
    if "--" in argv:
        targets = argv[argv.index("--") + 1:]

    names = [t[:-4] if t.endswith(".glb") else t for t in targets]
    if not names:
        names = list(ASSETS.keys())

    has_error = False
    results = {}
    for name in names:
        if name not in ASSETS:
            print(f"Error: Asset desconocido '{name}'", file=sys.stderr)
            has_error = True
            continue

        config = ASSETS[name]
        try:
            tris = adapt_asset(name, config)
            results[name] = tris
            if tris > config["max_triangles"]:
                print(
                    f"Error: {name} excede presupuesto: {tris} > {config['max_triangles']}",
                    file=sys.stderr,
                )
                has_error = True
        except Exception as e:
            print(f"Error adaptando {name}: {e}", file=sys.stderr)
            has_error = True

    if has_error:
        sys.exit(1)


if __name__ == "__main__":
    main()
