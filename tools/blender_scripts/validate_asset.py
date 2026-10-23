#!/usr/bin/env python3
"""tools/blender_scripts/validate_asset.py.

Validador formal y reproducible de assets 3D para Velvet Heist '84 (FEAT-001 y FEAT-009).
Comprueba esquema de ficha, nombres, transformaciones, pivote, dimensiones,
presupuesto de triángulos, paleta 'Velvet 84', ausencia de nodos procedurales y colisión.

Uso:
  blender -b -P tools/blender_scripts/validate_asset.py -- <asset_glb_o_blend> <ficha_json_o_ruta> [--output-json <ruta>]
  blender -b <archivo_blend> -P tools/blender_scripts/validate_asset.py -- <ficha_json_o_ruta>
"""

import json
import math
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Constantes del validador según FEAT-009 y FEAT-010
DIM_TOL_REL: float = 0.01
DIM_TOL_MIN: float = 0.001
PIVOT_Z_TOL: float = 0.002
PIVOT_XY_TOL_REL: float = 0.01
PIVOT_XY_TOL_MIN: float = 0.005
PBR_TOL: float = 0.01
ASSET_NAME_RE: str = r"^[a-z0-9_]+$"
OBJECT_NAME_RE: str = r"^[A-Za-z0-9_]+(-col|-colonly)?$"
MATERIAL_NAME_RE: str = r"^[A-Za-z0-9_]+$"
SOURCE_ORIGINS: Tuple[str, ...] = ("procedural", "polyhaven", "mixamo", "otro")
PIVOT_TYPES: Tuple[str, ...] = ("bottom_center", "top_center", "back_center")

SCRIPT_DIR = Path(__file__).resolve().parent
LIB_DIR = SCRIPT_DIR / "lib"
for p in [str(SCRIPT_DIR), str(LIB_DIR)]:
    if p not in sys.path:
        sys.path.insert(0, p)

BLENDER_VERSION_ENV: Path = SCRIPT_DIR.parent.parent / "tools" / "ci" / "blender_version.env"

try:
    import bpy
    import mathutils
    from lib.palette import (
        PALETTE,
        check_material_against_palette,
        check_material_procedural_nodes,
    )
except ImportError as e:
    print(f"Error importando dependencias: {e}", file=sys.stderr)
    sys.exit(1)


def check_blender_version(env_path: Path) -> Tuple[bool, str]:
    """Comprueba que la versión de Blender coincida con la fijada en env_path."""
    path = Path(env_path)
    if not path.is_file():
        return False, f"Archivo no encontrado: {path}"

    pinned_version = None
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("BLENDER_VERSION="):
                    pinned_version = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break
    except OSError as e:
        return False, f"Error al leer archivo {path}: {e}"

    if not pinned_version:
        return False, f"Variable BLENDER_VERSION no encontrada en {path}"

    actual_version = ".".join(str(n) for n in bpy.app.version)
    if actual_version != pinned_version:
        return False, f"Blender {actual_version}, se esperaba {pinned_version} (tools/ci/blender_version.env)"

    return True, ""


def parse_arguments() -> Tuple[str, Dict[str, Any], Optional[str]]:
    """Parsea los argumentos pasados tras '--' a Blender."""
    argv = sys.argv
    user_args = []
    if "--" in argv:
        user_args = argv[argv.index("--") + 1 :]

    output_json_path = None
    if "--output-json" in user_args:
        idx = user_args.index("--output-json")
        if idx + 1 < len(user_args):
            output_json_path = user_args[idx + 1]
            user_args = user_args[:idx] + user_args[idx + 2 :]

    asset_path = ""
    spec_data = {}

    if len(user_args) >= 2:
        asset_path = user_args[0]
        spec_raw = user_args[1]
    elif len(user_args) == 1:
        if bpy.data.filepath and os.path.exists(bpy.data.filepath):
            asset_path = bpy.data.filepath
            spec_raw = user_args[0]
        else:
            spec_raw = user_args[0]
    else:
        print(
            "Uso: blender -b -P validate_asset.py -- <asset_glb_o_blend> <ficha_json_o_ruta> [--output-json <ruta>]",
            file=sys.stderr,
        )
        sys.exit(1)

    if spec_raw.strip().startswith("{"):
        spec_data = json.loads(spec_raw)
    else:
        spec_path = Path(spec_raw)
        if not spec_path.is_file():
            candidate1 = SCRIPT_DIR / "specs" / f"{spec_raw}.json"
            candidate2 = SCRIPT_DIR / "specs" / spec_raw
            if candidate1.is_file():
                spec_path = candidate1
            elif candidate2.is_file():
                spec_path = candidate2
            else:
                raise FileNotFoundError(f"No se pudo encontrar el archivo de ficha: {spec_raw}")

        with open(spec_path, "r", encoding="utf-8") as f:
            spec_data = json.load(f)

    if not asset_path and "name" in spec_data:
        asset_candidate = Path("assets/models") / f"{spec_data['name']}.glb"
        if asset_candidate.is_file():
            asset_path = str(asset_candidate)

    return asset_path, spec_data, output_json_path


def load_asset(asset_path: str):
    """Carga el asset .glb, .gltf o .blend en Blender."""
    if not os.path.exists(asset_path):
        raise FileNotFoundError(f"El archivo del asset no existe: {asset_path}")

    ext = os.path.splitext(asset_path)[1].lower()
    if ext in [".glb", ".gltf"]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(asset_path))
    elif ext == ".blend":
        if os.path.abspath(bpy.data.filepath) != os.path.abspath(asset_path):
            bpy.ops.wm.open_mainfile(filepath=os.path.abspath(asset_path))
    else:
        raise ValueError(f"Formato no soportado: {ext}. Solo .glb, .gltf o .blend.")


def is_collision_object(obj: bpy.types.Object) -> bool:
    """Verifica si un objeto es una malla de colisión (sufijo -col o -colonly)."""
    name_lower = obj.name.lower()
    return name_lower.endswith("-col") or name_lower.endswith("-colonly")


def check_spec_schema(spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 1: Validación estricta del esquema de la ficha."""
    errors = []

    name = spec.get("name")
    if not isinstance(name, str) or not re.match(ASSET_NAME_RE, name):
        errors.append(f"Campo 'name' ausente o no cumple {ASSET_NAME_RE}: {name!r}")

    dims = spec.get("dimensions")
    if (
        not isinstance(dims, (list, tuple))
        or len(dims) != 3
        or not all(isinstance(x, (int, float)) and not isinstance(x, bool) and x > 0 for x in dims)
    ):
        errors.append(f"Campo 'dimensions' debe ser una lista de 3 números > 0: {dims!r}")

    pivot = spec.get("pivot")
    if pivot not in PIVOT_TYPES:
        errors.append(f"Campo 'pivot' debe ser uno de {PIVOT_TYPES}: {pivot!r}")

    max_tri = spec.get("max_triangles")
    if not isinstance(max_tri, int) or isinstance(max_tri, bool) or max_tri <= 0:
        errors.append(f"Campo 'max_triangles' debe ser un entero > 0: {max_tri!r}")

    mats = spec.get("materials")
    if (
        not isinstance(mats, (list, tuple))
        or len(mats) == 0
        or not all(isinstance(x, str) and len(x) > 0 for x in mats)
    ):
        errors.append(f"Campo 'materials' debe ser una lista no vacía de strings: {mats!r}")

    col = spec.get("collision")
    if not isinstance(col, bool):
        errors.append(f"Campo 'collision' debe ser un booleano: {col!r}")

    source = spec.get("source")
    if not isinstance(source, dict):
        errors.append(f"Campo 'source' ausente o no es un diccionario: {source!r}")
    else:
        origin = source.get("origin")
        if origin not in SOURCE_ORIGINS:
            errors.append(f"Campo 'source.origin' debe ser uno de {SOURCE_ORIGINS}: {origin!r}")
        for field in ("url", "license", "author"):
            val = source.get(field)
            if not isinstance(val, str) or not val.strip():
                errors.append(f"Campo 'source.{field}' debe ser un string no vacío: {val!r}")

    passed = len(errors) == 0
    detail = "Esquema de ficha válido." if passed else " ; ".join(errors)
    return {"name": "spec_schema", "pass": passed, "detail": detail}


def check_snake_case_names(asset_name: str, objects: List[bpy.types.Object]) -> Dict[str, Any]:
    """Criterio 5: Nombres válidos según regexes de FEAT-009."""
    errors = []

    if not re.match(ASSET_NAME_RE, asset_name):
        errors.append(f"El nombre del asset '{asset_name}' no cumple '{ASSET_NAME_RE}'.")

    for obj in objects:
        if not re.match(OBJECT_NAME_RE, obj.name):
            errors.append(f"El objeto '{obj.name}' no cumple '{OBJECT_NAME_RE}'.")

        if obj.type == "MESH" and not is_collision_object(obj) and obj.data:
            for mat in obj.data.materials:
                if mat and not re.match(MATERIAL_NAME_RE, mat.name):
                    errors.append(f"El material '{mat.name}' no cumple '{MATERIAL_NAME_RE}'.")

    passed = len(errors) == 0
    detail = "Todos los nombres de objetos y materiales son válidos." if passed else " ; ".join(errors)
    return {"name": "snake_case_names", "pass": passed, "detail": detail}


def check_applied_transforms(mesh_objects: List[bpy.types.Object]) -> Dict[str, Any]:
    """Escala (1, 1, 1) y rotación (0, 0, 0) aplicadas."""
    errors = []
    tol = 1e-3

    for obj in mesh_objects:
        sx, sy, sz = obj.scale
        if abs(sx - 1.0) > tol or abs(sy - 1.0) > tol or abs(sz - 1.0) > tol:
            errors.append(f"Objeto '{obj.name}' escala no aplicada: ({sx:.3f}, {sy:.3f}, {sz:.3f}) != (1, 1, 1)")

        rx, ry, rz = obj.rotation_euler
        if abs(rx) > tol or abs(ry) > tol or abs(rz) > tol:
            errors.append(
                f"Objeto '{obj.name}' rotación no aplicada: ({math.degrees(rx):.1f}°, {math.degrees(ry):.1f}°, {math.degrees(rz):.1f}°) != (0, 0, 0)"
            )

    passed = len(errors) == 0
    detail = "Escala (1, 1, 1) y rotación (0, 0, 0) aplicadas en todas las mallas." if passed else " ; ".join(errors)
    return {"name": "applied_transforms", "pass": passed, "detail": detail}


def compute_world_bounds(objects: List[bpy.types.Object]) -> Tuple[mathutils.Vector, mathutils.Vector]:
    """Calcula el bounding box global (AABB) de una lista de objetos."""
    all_corners = []
    for obj in objects:
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


def check_pivot_position(visual_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 3: Posición del pivote según tipo ('bottom_center', 'top_center', 'back_center')."""
    if not visual_objects:
        return {"name": "pivot_position", "pass": False, "detail": "No se encontraron mallas visuales para calcular el pivote."}

    pivot = spec.get("pivot", "bottom_center")
    dims = spec.get("dimensions")
    if (
        not isinstance(dims, (list, tuple))
        or len(dims) < 3
        or not all(isinstance(x, (int, float)) and not isinstance(x, bool) and x > 0 for x in dims[:3])
    ):
        return {"name": "pivot_position", "pass": False, "detail": "Campo 'dimensions' ausente o formato inválido en la ficha para calcular tolerancias de centrado."}

    exp_x = float(dims[0])
    exp_y = float(dims[1])
    exp_z = float(dims[2])

    min_v, max_v = compute_world_bounds(visual_objects)
    center_x = (min_v.x + max_v.x) / 2.0
    center_y = (min_v.y + max_v.y) / 2.0
    center_z = (min_v.z + max_v.z) / 2.0

    errors = []
    x_tol = max(PIVOT_XY_TOL_REL * exp_x, PIVOT_XY_TOL_MIN)
    y_tol = max(PIVOT_XY_TOL_REL * exp_y, PIVOT_XY_TOL_MIN)
    z_tol = max(PIVOT_XY_TOL_REL * exp_z, PIVOT_XY_TOL_MIN)

    if pivot == "bottom_center":
        if abs(min_v.z) > PIVOT_Z_TOL:
            errors.append(f"La base inferior del asset está en Z={min_v.z:.4f}m (esperado Z=0.0m ±{PIVOT_Z_TOL:.4f}m).")
        if abs(center_x) > x_tol:
            errors.append(f"El centro en X está desplazado a {center_x:.4f}m (esperado 0.0m ±{x_tol:.4f}m).")
        if abs(center_y) > y_tol:
            errors.append(f"El centro en Y está desplazado a {center_y:.4f}m (esperado 0.0m ±{y_tol:.4f}m).")
    elif pivot == "top_center":
        if abs(max_v.z) > PIVOT_Z_TOL:
            errors.append(f"La parte superior del asset está en Z={max_v.z:.4f}m (esperado Z=0.0m ±{PIVOT_Z_TOL:.4f}m).")
        if abs(center_x) > x_tol:
            errors.append(f"El centro en X está desplazado a {center_x:.4f}m (esperado 0.0m ±{x_tol:.4f}m).")
        if abs(center_y) > y_tol:
            errors.append(f"El centro en Y está desplazado a {center_y:.4f}m (esperado 0.0m ±{y_tol:.4f}m).")
    elif pivot == "back_center":
        min_dist_y = min(abs(min_v.y), abs(max_v.y))
        if min_dist_y > PIVOT_Z_TOL:
            errors.append(f"La cara trasera no está en el plano Y=0 (min(|min_y|, |max_y|) = {min_dist_y:.4f}m > ±{PIVOT_Z_TOL:.4f}m).")
        if abs(center_x) > x_tol:
            errors.append(f"El centro en X está desplazado a {center_x:.4f}m (esperado 0.0m ±{x_tol:.4f}m).")
        if abs(center_z) > z_tol:
            errors.append(f"El centro en Z está desplazado a {center_z:.4f}m (esperado 0.0m ±{z_tol:.4f}m).")
    else:
        errors.append(f"Tipo de pivote desconocido: {pivot!r}")

    passed = len(errors) == 0
    detail = (
        f"Pivote {pivot} correcto."
        if passed
        else " ; ".join(errors)
    )
    return {"name": "pivot_position", "pass": passed, "detail": detail}


def check_target_dimensions(visual_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 2: Dimensiones dentro de tolerancia respecto a la ficha."""
    expected_dim = spec.get("dimensions")
    if (
        not isinstance(expected_dim, (list, tuple))
        or len(expected_dim) < 3
        or not all(isinstance(x, (int, float)) and not isinstance(x, bool) and x > 0 for x in expected_dim[:3])
    ):
        return {"name": "target_dimensions", "pass": False, "detail": f"Formato inválido o ausente de dimensiones en ficha: {expected_dim}"}

    exp_x, exp_y, exp_z = float(expected_dim[0]), float(expected_dim[1]), float(expected_dim[2])

    min_v, max_v = compute_world_bounds(visual_objects)
    actual_x = max_v.x - min_v.x
    actual_y = max_v.y - min_v.y
    actual_z = max_v.z - min_v.z

    errors = []
    axes = [("X", actual_x, exp_x), ("Y", actual_y, exp_y), ("Z", actual_z, exp_z)]

    for axis_name, actual, expected in axes:
        tol = max(expected * DIM_TOL_REL, DIM_TOL_MIN)
        diff = abs(actual - expected)
        if diff > tol:
            pct = (diff / expected * 100.0) if expected > 0 else 100.0
            errors.append(f"Eje {axis_name}: medido={actual:.4f}m, esperado={expected:.4f}m (dif={diff:.4f}m, {pct:.2f}% > tol {tol:.4f}m)")

    passed = len(errors) == 0
    detail = (
        f"Dimensiones dentro de tolerancia: ({actual_x:.4f}, {actual_y:.4f}, {actual_z:.4f})m vs esperadas ({exp_x:.4f}, {exp_y:.4f}, {exp_z:.4f})m."
        if passed
        else " ; ".join(errors)
    )
    return {"name": "target_dimensions", "pass": passed, "detail": detail}


def check_triangle_budget(visual_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Conteo de triángulos <= presupuesto de la ficha."""
    max_triangles = spec.get("max_triangles")
    if not isinstance(max_triangles, int) or isinstance(max_triangles, bool) or max_triangles <= 0:
        return {"name": "triangle_budget", "pass": False, "detail": f"Ficha no especifica max_triangles válido: {max_triangles}"}

    total_triangles = 0
    for obj in visual_objects:
        if obj.type == "MESH" and obj.data:
            for poly in obj.data.polygons:
                total_triangles += max(1, len(poly.vertices) - 2)

    passed = total_triangles <= max_triangles
    detail = (
        f"Triángulos: {total_triangles} <= presupuesto ({max_triangles})."
        if passed
        else f"Triángulos excedidos: {total_triangles} > presupuesto ({max_triangles})."
    )
    return {"name": "triangle_budget", "pass": passed, "detail": detail}


def check_palette_materials(visual_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 4: Materiales dentro de la paleta 'Velvet 84' y de la lista de la ficha."""
    allowed_materials = spec.get("materials")
    if (
        not isinstance(allowed_materials, (list, tuple))
        or len(allowed_materials) == 0
        or not all(isinstance(x, str) and len(x) > 0 for x in allowed_materials)
    ):
        return {"name": "palette_materials", "pass": False, "detail": "Campo 'materials' ausente o formato inválido en la ficha."}

    errors = []
    materials_found = set()

    for obj in visual_objects:
        if obj.type == "MESH" and obj.data:
            for mat in obj.data.materials:
                if mat:
                    materials_found.add(mat)

    if not materials_found:
        errors.append("El asset visual no tiene ningún material asignado.")

    source = spec.get("source")
    origin = source.get("origin") if isinstance(source, dict) else "procedural"
    is_procedural = origin == "procedural"

    for mat in sorted(materials_found, key=lambda m: m.name):
        if mat.name not in allowed_materials:
            errors.append(f"El material '{mat.name}' no está en la lista 'materials' de la ficha.")
            continue

        if is_procedural:
            if mat.name not in PALETTE:
                errors.append(f"El material '{mat.name}' no es clave exacta de PALETTE en asset procedural.")
            else:
                ok, msg = check_material_against_palette(mat, mat.name, tol=PBR_TOL)
                if not ok:
                    errors.append(f"Material '{mat.name}': {msg}")

    passed = len(errors) == 0
    detail = (
        f"Materiales válidos ({', '.join(sorted(m.name for m in materials_found))})."
        if passed
        else " ; ".join(errors)
    )
    return {"name": "palette_materials", "pass": passed, "detail": detail}


def check_no_procedural_nodes(visual_objects: List[bpy.types.Object], spec: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Sin nodos procedurales (Color Ramp, Ruido, etc.)."""
    errors = []
    checked_mats = set()

    source = spec.get("source") if isinstance(spec, dict) else {}
    origin = source.get("origin", "procedural") if isinstance(source, dict) else "procedural"
    is_procedural = origin == "procedural"

    forbidden_procedural = {
        "ShaderNodeTexNoise", "TEX_NOISE",
        "ShaderNodeTexVoronoi", "TEX_VORONOI",
        "ShaderNodeValToRGB", "VALTORGB",
        "ShaderNodeTexWave", "TEX_WAVE",
        "ShaderNodeTexMusgrave", "TEX_MUSGRAVE",
        "ShaderNodeTexMagic", "TEX_MAGIC",
        "ShaderNodeTexGradient", "TEX_GRADIENT",
        "ShaderNodeTexChecker", "TEX_CHECKER",
        "ShaderNodeTexBrick", "TEX_BRICK",
    }

    for obj in visual_objects:
        if obj.type == "MESH" and obj.data:
            for mat in obj.data.materials:
                if mat and mat not in checked_mats:
                    checked_mats.add(mat)
                    if is_procedural:
                        ok, msg = check_material_procedural_nodes(mat)
                        if not ok:
                            errors.append(f"Material '{mat.name}': {msg}")
                    else:
                        if mat.use_nodes and mat.node_tree:
                            for node in mat.node_tree.nodes:
                                n_type = getattr(node, "type", "")
                                bl_id = getattr(node, "bl_idname", "")
                                if n_type in forbidden_procedural or bl_id in forbidden_procedural:
                                    errors.append(
                                        f"Material '{mat.name}': Usa nodo procedural prohibido: '{bl_id or n_type}' ({node.name})."
                                    )

    passed = len(errors) == 0
    detail = "Todos los materiales usan Principled BSDF limpio sin nodos procedurales." if passed else " ; ".join(errors)
    return {"name": "no_procedural_nodes", "pass": passed, "detail": detail}


def check_collision_mesh(mesh_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Malla de colisión con sufijo -colonly si la ficha lo pide.

    Falla si existe cualquier objeto con sufijo '-col' (visible en Godot).
    """
    col_visible = [obj for obj in mesh_objects if obj.name.lower().endswith("-col")]
    if col_visible:
        names = ", ".join(obj.name for obj in col_visible)
        return {
            "name": "collision_mesh",
            "pass": False,
            "detail": f"Objeto '{names}' usa '-col' (visible en Godot); renombra a '-colonly'.",
        }

    requires_collision = spec.get("collision")
    if not isinstance(requires_collision, bool):
        return {
            "name": "collision_mesh",
            "pass": False,
            "detail": "Campo 'collision' ausente o no booleano en la ficha.",
        }

    col_objects = [obj for obj in mesh_objects if obj.name.lower().endswith("-colonly")]

    if requires_collision:
        if not col_objects:
            return {
                "name": "collision_mesh",
                "pass": False,
                "detail": "La ficha requiere colisión pero no se encontró ninguna malla con sufijo '-colonly'.",
            }
        col_names = ", ".join(obj.name for obj in col_objects)
        return {
            "name": "collision_mesh",
            "pass": True,
            "detail": f"Malla de colisión presente: {col_names}.",
        }
    else:
        return {
            "name": "collision_mesh",
            "pass": True,
            "detail": "La ficha no requiere colisión estática (-colonly).",
        }


def validate_asset(asset_path: str, spec: Dict[str, Any]) -> Dict[str, Any]:
    """Ejecuta la suite completa de validaciones sobre el asset."""
    load_asset(asset_path)

    asset_name = spec.get("name") or Path(asset_path).stem

    all_objects = [obj for obj in bpy.data.objects]
    mesh_objects = [obj for obj in all_objects if obj.type == "MESH"]
    visual_objects = [obj for obj in mesh_objects if not is_collision_object(obj)]

    checks = []
    checks.append(check_spec_schema(spec))
    checks.append(check_snake_case_names(asset_name, all_objects))
    checks.append(check_applied_transforms(mesh_objects))
    checks.append(check_pivot_position(visual_objects, spec))
    checks.append(check_target_dimensions(visual_objects, spec))
    checks.append(check_triangle_budget(visual_objects, spec))
    checks.append(check_palette_materials(visual_objects, spec))
    checks.append(check_no_procedural_nodes(visual_objects, spec))
    checks.append(check_collision_mesh(mesh_objects, spec))

    pass_global = all(c["pass"] for c in checks)

    return {
        "asset": asset_name,
        "checks": checks,
        "pass": pass_global,
    }


def main():
    ok, msg = check_blender_version(BLENDER_VERSION_ENV)
    if not ok:
        print(f"Error: {msg}", file=sys.stderr)
        sys.exit(2)

    try:
        asset_path, spec_data, output_json_path = parse_arguments()
    except Exception as e:
        print(f"Error parseando argumentos: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        result = validate_asset(asset_path, spec_data)
    except Exception as e:
        result = {
            "asset": spec_data.get("name", Path(asset_path).stem if asset_path else "unknown"),
            "checks": [{"name": "execution", "pass": False, "detail": f"Excepción durante validación: {str(e)}"}],
            "pass": False,
        }

    json_str = json.dumps(result, indent=2, ensure_ascii=False)
    print("\n--- VALIDATION REPORT BEGIN ---")
    print(json_str)
    print("--- VALIDATION REPORT END ---\n")

    if output_json_path:
        os.makedirs(os.path.dirname(os.path.abspath(output_json_path)), exist_ok=True)
        with open(output_json_path, "w", encoding="utf-8") as f:
            f.write(json_str)
        print(f"Reporte guardado en: {output_json_path}")

    if result["pass"]:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
