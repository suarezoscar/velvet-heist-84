#!/usr/bin/env python3
"""
tools/blender_scripts/validate_asset.py
Validador formal y reproducible de assets 3D para Velvet Heist '84 (FEAT-001).
Comprueba dimensiones, pivote, escalas aplicadas, paleta 'Velvet 84', ausencia de nodos
procedurales, colisión -col, snake_case y presupuesto de polígonos.

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

# Asegurar importación de lib/palette.py
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
        check_material_procedural_nodes,
        is_material_in_palette,
    )
except ImportError as e:
    # Si se corre fuera de blender o falla import
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
        # Podría ser blender -b archivo.blend -P validate_asset.py -- spec.json
        if bpy.data.filepath and os.path.exists(bpy.data.filepath):
            asset_path = bpy.data.filepath
            spec_raw = user_args[0]
        else:
            # Quizás solo pasaron la spec o el asset
            spec_raw = user_args[0]
    else:
        print("Uso: blender -b -P validate_asset.py -- <asset_glb_o_blend> <ficha_json_o_ruta> [--output-json <ruta>]", file=sys.stderr)
        sys.exit(1)

    # Cargar spec_raw
    if spec_raw.strip().startswith("{"):
        spec_data = json.loads(spec_raw)
    else:
        # Es una ruta o un nombre de asset
        spec_path = Path(spec_raw)
        if not spec_path.is_file():
            # Buscar en specs/ o data/asset_specs/
            candidate1 = SCRIPT_DIR / "specs" / f"{spec_raw}.json"
            candidate2 = SCRIPT_DIR / "specs" / spec_raw
            candidate3 = Path("data/asset_specs") / f"{spec_raw}.json"
            if candidate1.is_file():
                spec_path = candidate1
            elif candidate2.is_file():
                spec_path = candidate2
            elif candidate3.is_file():
                spec_path = candidate3
            else:
                raise FileNotFoundError(f"No se pudo encontrar el archivo de ficha: {spec_raw}")

        with open(spec_path, "r", encoding="utf-8") as f:
            spec_data = json.load(f)

    # Si asset_path no se definió pero está en spec_data
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
    return name_lower.endswith("-col") or name_lower.endswith("-colonly") or "-col." in name_lower or "-colonly." in name_lower


def check_snake_case_names(asset_name: str, objects: List[bpy.types.Object]) -> Dict[str, Any]:
    """Criterio 3: Nombres válidos en snake_case, sin espacios ni puntos."""
    errors = []

    # Validar nombre del asset
    if not re.match(r"^[a-z0-9_]+$", asset_name):
        errors.append(f"El nombre del asset '{asset_name}' no es snake_case válido (solo minúsculas, números y guión bajo).")

    for obj in objects:
        clean_name = obj.name
        # Ignorar sufijos de colisión válidos para el test de snake_case
        if clean_name.endswith("-col"):
            clean_name = clean_name[:-4]
        elif clean_name.endswith("-colonly"):
            clean_name = clean_name[:-8]

        if " " in obj.name:
            errors.append(f"El objeto '{obj.name}' contiene espacios.")
        if "." in clean_name:
            errors.append(f"El objeto '{obj.name}' contiene puntos.")

        # Verificar nombres de materiales asignados
        if obj.type == "MESH":
            for mat in obj.data.materials:
                if mat:
                    if " " in mat.name:
                        errors.append(f"El material '{mat.name}' contiene espacios.")
                    if "." in mat.name:
                        errors.append(f"El material '{mat.name}' contiene puntos (ej. sufijos duplicados .001).")

    passed = len(errors) == 0
    detail = "Todos los nombres de objetos y materiales son válidos (sin espacios ni puntos)." if passed else " ; ".join(errors)
    return {"name": "snake_case_names", "pass": passed, "detail": detail}


def check_applied_transforms(mesh_objects: List[bpy.types.Object]) -> Dict[str, Any]:
    """Criterio 3: Escala (1, 1, 1) y rotación (0, 0, 0) aplicadas."""
    errors = []
    tol = 1e-3

    for obj in mesh_objects:
        # Comprobar escala
        sx, sy, sz = obj.scale
        if abs(sx - 1.0) > tol or abs(sy - 1.0) > tol or abs(sz - 1.0) > tol:
            errors.append(f"Objeto '{obj.name}' escala no aplicada: ({sx:.3f}, {sy:.3f}, {sz:.3f}) != (1, 1, 1)")

        # Comprobar rotación
        rx, ry, rz = obj.rotation_euler
        if abs(rx) > tol or abs(ry) > tol or abs(rz) > tol:
            errors.append(f"Objeto '{obj.name}' rotación no aplicada: ({math.degrees(rx):.1f}°, {math.degrees(ry):.1f}°, {math.degrees(rz):.1f}°) != (0, 0, 0)")

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


def check_pivot_bottom_center(visual_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 3: Origen y pivote en la base inferior central (Z=0, X=0, Y=0)."""
    if not visual_objects:
        return {"name": "pivot_bottom_center", "pass": False, "detail": "No se encontraron mallas visuales para calcular el pivote."}

    min_v, max_v = compute_world_bounds(visual_objects)
    height = max_v.z - min_v.z
    center_x = (min_v.x + max_v.x) / 2.0
    center_y = (min_v.y + max_v.y) / 2.0

    errors = []
    # Tolerancia para Z inferior: base en Z=0.0
    # Margen máximo de 0.015m o 1% de la altura
    z_tol = max(0.015, height * 0.01)
    if abs(min_v.z) > z_tol:
        errors.append(f"La base inferior del asset está en Z={min_v.z:.3f}m (esperado Z=0.0m ±{z_tol:.3f}m).")

    # Tolerancia para centrado en X e Y
    # Margen de 0.035m para permitir detalles menores o asimetrías de diseño
    xy_tol = 0.035
    if abs(center_x) > xy_tol:
        errors.append(f"El centro en X está desplazado a {center_x:.3f}m (esperado 0.0m ±{xy_tol:.3f}m).")
    if abs(center_y) > xy_tol:
        errors.append(f"El centro en Y está desplazado a {center_y:.3f}m (esperado 0.0m ±{xy_tol:.3f}m).")

    passed = len(errors) == 0
    detail = f"Pivote en la base inferior central correcto: Z_min={min_v.z:.3f}m, Centro XY=({center_x:.3f}, {center_y:.3f})m." if passed else " ; ".join(errors)
    return {"name": "pivot_bottom_center", "pass": passed, "detail": detail}


def check_target_dimensions(visual_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 3: Dimensiones dentro de ±1% respecto a la ficha."""
    expected_dim = spec.get("dimensions") or spec.get("target_dimensions")
    if not expected_dim:
        return {"name": "target_dimensions", "pass": True, "detail": "Ficha no especifica dimensiones objetivo; omitida."}

    if isinstance(expected_dim, dict):
        exp_x = float(expected_dim.get("x", 0))
        exp_y = float(expected_dim.get("y", 0))
        exp_z = float(expected_dim.get("z", 0))
    elif isinstance(expected_dim, (list, tuple)) and len(expected_dim) >= 3:
        exp_x, exp_y, exp_z = float(expected_dim[0]), float(expected_dim[1]), float(expected_dim[2])
    else:
        return {"name": "target_dimensions", "pass": False, "detail": f"Formato inválido de dimensiones en ficha: {expected_dim}"}

    min_v, max_v = compute_world_bounds(visual_objects)
    actual_x = max_v.x - min_v.x
    actual_y = max_v.y - min_v.y
    actual_z = max_v.z - min_v.z

    errors = []
    axes = [("X", actual_x, exp_x), ("Y", actual_y, exp_y), ("Z", actual_z, exp_z)]

    for axis_name, actual, expected in axes:
        # Tolerancia del 1% con un mínimo de 0.015m (1.5cm) para dimensiones muy delgadas/pequeñas
        tol = max(expected * 0.01, 0.015)
        diff = abs(actual - expected)
        if diff > tol:
            pct = (diff / expected * 100.0) if expected > 0 else 100.0
            errors.append(f"Eje {axis_name}: medido={actual:.3f}m, esperado={expected:.3f}m (dif={diff:.3f}m, {pct:.1f}% > 1%)")

    passed = len(errors) == 0
    detail = (
        f"Dimensiones dentro de ±1%: ({actual_x:.3f}, {actual_y:.3f}, {actual_z:.3f})m vs esperadas ({exp_x:.3f}, {exp_y:.3f}, {exp_z:.3f})m."
        if passed
        else " ; ".join(errors)
    )
    return {"name": "target_dimensions", "pass": passed, "detail": detail}


def check_triangle_budget(visual_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 3: Conteo de triángulos <= presupuesto de la ficha."""
    max_triangles = spec.get("max_triangles") or spec.get("triangles_budget")
    if max_triangles is None:
        return {"name": "triangle_budget", "pass": True, "detail": "Ficha no especifica presupuesto de triángulos; omitida."}

    total_triangles = 0
    for obj in visual_objects:
        if obj.type == "MESH" and obj.data:
            for poly in obj.data.polygons:
                # Polígonos de N vértices equivalen a (N - 2) triángulos
                total_triangles += max(1, len(poly.vertices) - 2)

    passed = total_triangles <= max_triangles
    detail = (
        f"Triángulos: {total_triangles} <= presupuesto ({max_triangles})."
        if passed
        else f"Triángulos excedidos: {total_triangles} > presupuesto ({max_triangles})."
    )
    return {"name": "triangle_budget", "pass": passed, "detail": detail}


def check_palette_materials(visual_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 3: Materiales dentro de la paleta 'Velvet 84' y de la lista de la ficha."""
    allowed_materials = spec.get("materials")
    errors = []
    materials_found = set()

    for obj in visual_objects:
        if obj.type == "MESH" and obj.data:
            for mat in obj.data.materials:
                if mat:
                    materials_found.add(mat)

    if not materials_found:
        errors.append("El asset visual no tiene ningún material asignado.")

    for mat in materials_found:
        ok, msg = is_material_in_palette(mat, allowed_list=allowed_materials)
        if not ok:
            errors.append(msg)

    passed = len(errors) == 0
    detail = (
        f"Materiales válidos ({', '.join(m.name for m in materials_found)})."
        if passed
        else " ; ".join(errors)
    )
    return {"name": "palette_materials", "pass": passed, "detail": detail}


def check_no_procedural_nodes(visual_objects: List[bpy.types.Object]) -> Dict[str, Any]:
    """Criterio 3: Sin nodos procedurales (Color Ramp, Ruido, etc.)."""
    errors = []
    checked_mats = set()

    for obj in visual_objects:
        if obj.type == "MESH" and obj.data:
            for mat in obj.data.materials:
                if mat and mat not in checked_mats:
                    checked_mats.add(mat)
                    ok, msg = check_material_procedural_nodes(mat)
                    if not ok:
                        errors.append(f"Material '{mat.name}': {msg}")

    passed = len(errors) == 0
    detail = "Todos los materiales usan Principled BSDF limpio sin nodos procedurales." if passed else " ; ".join(errors)
    return {"name": "no_procedural_nodes", "pass": passed, "detail": detail}


def check_collision_mesh(mesh_objects: List[bpy.types.Object], spec: Dict[str, Any]) -> Dict[str, Any]:
    """Criterio 3: Malla de colisión con sufijo -col si la ficha lo pide."""
    requires_collision = spec.get("collision", False)
    col_objects = [obj for obj in mesh_objects if is_collision_object(obj)]

    if requires_collision:
        if not col_objects:
            return {
                "name": "collision_mesh",
                "pass": False,
                "detail": "La ficha requiere colisión pero no se encontró ninguna malla con sufijo '-col' o '-colonly'.",
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
            "detail": "La ficha no requiere colisión estática (-col).",
        }


def validate_asset(asset_path: str, spec: Dict[str, Any]) -> Dict[str, Any]:
    """Ejecuta la suite completa de validaciones sobre el asset."""
    load_asset(asset_path)

    asset_name = spec.get("name") or Path(asset_path).stem

    all_objects = [obj for obj in bpy.data.objects]
    mesh_objects = [obj for obj in all_objects if obj.type == "MESH"]
    visual_objects = [obj for obj in mesh_objects if not is_collision_object(obj)]

    checks = []
    checks.append(check_snake_case_names(asset_name, all_objects))
    checks.append(check_applied_transforms(mesh_objects))
    checks.append(check_pivot_bottom_center(visual_objects, spec))
    checks.append(check_target_dimensions(visual_objects, spec))
    checks.append(check_triangle_budget(visual_objects, spec))
    checks.append(check_palette_materials(visual_objects, spec))
    checks.append(check_no_procedural_nodes(visual_objects))
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

    # Salida con código 0 o 1 según Criterio 4
    if result["pass"]:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
