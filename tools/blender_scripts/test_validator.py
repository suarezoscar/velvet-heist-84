#!/usr/bin/env python3
"""
tools/blender_scripts/test_validator.py
Suite de tests unitarios para validate_asset.py (FEAT-001 Criterios 3 y 4).
Demuestra empíricamente que el validador rechaza cada tipo de infracción individual:
1. snake_case_names (espacios o puntos)
2. applied_transforms (escala o rotación no aplicadas)
3. pivot_bottom_center (origen no en Z=0.0 o descentrado)
4. target_dimensions (dimensiones fuera de ±1%)
5. triangle_budget (triángulos excedidos)
6. palette_materials (material no perteneciente a la paleta Velvet '84)
7. no_procedural_nodes (uso de nodos procedurales como Noise Texture o Color Ramp)
8. collision_mesh (falta de malla -col requerida)
9. exit code != 0 cuando alguna comprobación falla
"""

import json
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
    from validate_asset import validate_asset
except ImportError as e:
    print(f"Error importando dependencias para test: {e}", file=sys.stderr)
    sys.exit(1)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def run_test_suite():
    print("=== [TEST SUITE] Iniciando pruebas unitarias de validate_asset.py ===")
    tests_passed = 0
    tests_total = 0

    def assert_check_fails(check_name: str, test_title: str, setup_fn, spec: dict):
        nonlocal tests_passed, tests_total
        tests_total += 1
        print(f"\n--- Test {tests_total}: {test_title} ---")
        clear_scene()
        temp_blend = str(SCRIPT_DIR / "temp_broken_asset.blend")
        setup_fn()
        bpy.ops.wm.save_as_mainfile(filepath=temp_blend)

        result = validate_asset(temp_blend, spec)
        if os.path.exists(temp_blend):
            os.remove(temp_blend)

        global_pass = result["pass"]
        check_result = next((c for c in result["checks"] if c["name"] == check_name), None)

        print(f"  Resultado global: {'PASS' if global_pass else 'FAIL (esperado)'}")
        if check_result:
            print(f"  Check '{check_name}': pass={check_result['pass']}, detalle={check_result['detail']}")

        if not global_pass and check_result and not check_result["pass"]:
            print(f"  ==> OK: El validador detectó y rechazó la infracción correctamente.")
            tests_passed += 1
            return result
        else:
            print(f"  ==> ERROR: El validador NO detectó la infracción en '{check_name}'")
            return None

    # 1. Test Fallo de Nombres (espacios y puntos)
    def setup_broken_names():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "Bad Mesh.001"
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_names = {
        "name": "broken_names",
        "dimensions": [1.0, 1.0, 1.0],
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": False,
    }
    assert_check_fails("snake_case_names", "Rechazar nombres con espacios o puntos", setup_broken_names, spec_names)

    # 2. Test Fallo de Escala no aplicada
    def setup_unapplied_scale():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "unapplied_scale_mesh"
        obj.scale = (2.0, 1.0, 1.0)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_scale = {
        "name": "broken_scale",
        "dimensions": [2.0, 1.0, 1.0],
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": False,
    }
    assert_check_fails("applied_transforms", "Rechazar escala sin aplicar (scale=(2, 1, 1))", setup_unapplied_scale, spec_scale)

    # 3. Test Fallo de Rotación no aplicada
    def setup_unapplied_rotation():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5), rotation=(0.785, 0, 0))
        obj = bpy.context.active_object
        obj.name = "unapplied_rot_mesh"
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_rot = {
        "name": "broken_rot",
        "dimensions": [1.0, 1.0, 1.0],
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": False,
    }
    assert_check_fails("applied_transforms", "Rechazar rotación sin aplicar (rot=(45°, 0, 0))", setup_unapplied_rotation, spec_rot)

    # 4. Test Fallo de Pivote inferior (base en Z=0.5m en vez de Z=0.0m)
    def setup_offset_pivot():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.0))
        obj = bpy.context.active_object
        obj.name = "offset_pivot_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_pivot = {
        "name": "broken_pivot",
        "dimensions": [1.0, 1.0, 1.0],
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": False,
    }
    assert_check_fails("pivot_bottom_center", "Rechazar base inferior en Z=0.5m (esperado Z=0.0m)", setup_offset_pivot, spec_pivot)

    # 5. Test Fallo de Dimensiones fuera de ±1%
    def setup_wrong_dimensions():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5), scale=(1.25, 1.0, 1.0))
        obj = bpy.context.active_object
        obj.name = "wrong_dim_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_dim = {
        "name": "broken_dim",
        "dimensions": [1.0, 1.0, 1.0],  # 1.25m vs 1.0m (+25% de error)
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": False,
    }
    assert_check_fails("target_dimensions", "Rechazar dimensiones fuera de ±1% (1.25m vs 1.0m esperado)", setup_wrong_dimensions, spec_dim)

    # 6. Test Fallo de Presupuesto de Triángulos
    def setup_high_poly():
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=0.5, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "high_poly_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_tri = {
        "name": "broken_poly",
        "dimensions": [1.0, 1.0, 1.0],
        "max_triangles": 200,  # UV sphere 64x32 tiene ~4000 triángulos
        "materials": ["Steel80s"],
        "collision": False,
    }
    assert_check_fails("triangle_budget", "Rechazar exceso de polígonos (~4000 > max 200)", setup_high_poly, spec_tri)

    # 7. Test Fallo de Material no perteneciente a la paleta Velvet '84
    def setup_non_palette_material():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "alien_material_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        # Material inventado no en la paleta
        mat = bpy.data.materials.new(name="NeonCyberpunkPink")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (1.0, 0.05, 0.8, 1.0)
        obj.data.materials.append(mat)

    spec_mat = {
        "name": "broken_mat",
        "dimensions": [1.0, 1.0, 1.0],
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": False,
    }
    assert_check_fails("palette_materials", "Rechazar material no perteneciente a la paleta ('NeonCyberpunkPink')", setup_non_palette_material, spec_mat)

    # 8. Test Fallo de Nodos Procedurales (Noise Texture / Color Ramp)
    def setup_procedural_nodes():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "procedural_node_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        # Inyectar nodo procedural ShaderNodeTexNoise
        noise = mat.node_tree.nodes.new("ShaderNodeTexNoise")
        mat.node_tree.links.new(noise.outputs["Fac"], mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"])
        obj.data.materials.append(mat)

    spec_proc = {
        "name": "broken_proc",
        "dimensions": [1.0, 1.0, 1.0],
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": False,
    }
    assert_check_fails("no_procedural_nodes", "Rechazar uso de nodo procedural ('ShaderNodeTexNoise')", setup_procedural_nodes, spec_proc)

    # 9. Test Fallo de Malla de Colisión requerida pero ausente
    def setup_missing_collision():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "visual_only_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_col = {
        "name": "broken_collision",
        "dimensions": [1.0, 1.0, 1.0],
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": True,  # Ficha exige colisión -col
    }
    assert_check_fails("collision_mesh", "Rechazar ausencia de malla de colisión '-col' requerida", setup_missing_collision, spec_col)

    print(f"\n==========================================")
    print(f"Resumen de tests de validación: {tests_passed}/{tests_total} pasados.")
    print(f"==========================================")

    if tests_passed == tests_total:
        print("==> Todos los tests unitarios del validador pasaron con éxito.")
        sys.exit(0)
    else:
        print(f"==> Fallaron {tests_total - tests_passed} tests.")
        sys.exit(1)


if __name__ == "__main__":
    run_test_suite()
