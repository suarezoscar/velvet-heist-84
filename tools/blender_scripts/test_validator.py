#!/usr/bin/env python3
"""
tools/blender_scripts/test_validator.py
Suite de tests unitarios y de aceptación para validate_asset.py (FEAT-009 PKG-QA).
Demuestra empíricamente el cumplimiento de los criterios 1 a 5 de la FEAT-009:
- Criterio 1: test_spec_schema_* (esquema estricto de ficha y source)
- Criterio 2: test_dimensions_tolerance_* (tolerancias relativas y absolutas)
- Criterio 3: test_pivot_tolerance_* (base en Z=0 y centrado XY)
- Criterio 4: test_palette_* (materiales en ficha y paleta PBR Velvet '84)
- Criterio 5: test_names_* (nombres de objeto y materiales)
Más tests de regresión para las reglas existentes de Blender.
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
LIB_DIR = SCRIPT_DIR / "lib"
for p in [str(SCRIPT_DIR), str(LIB_DIR)]:
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    import bpy
    from lib.palette import create_pbr_material
    from validate_asset import BLENDER_VERSION_ENV, check_blender_version, validate_asset
except ImportError as e:
    print(f"Error importando dependencias para test: {e}", file=sys.stderr)
    sys.exit(1)

VALID_SOURCE: Dict[str, Any] = {
    "origin": "procedural",
    "url": "tools/blender_scripts/gen_core_assets.py",
    "license": "propia",
    "author": "velvet-heist-84",
}


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_valid_spec(name: str = "valid_asset", **overrides) -> Dict[str, Any]:
    spec: Dict[str, Any] = {
        "name": name,
        "dimensions": [1.0, 1.0, 1.0],
        "pivot": "bottom_center",
        "max_triangles": 100,
        "materials": ["Steel80s"],
        "collision": False,
        "source": VALID_SOURCE.copy(),
    }
    spec.update(overrides)
    return spec


def setup_valid_cube():
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
    obj = bpy.context.active_object
    obj.name = "valid_cube"
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    mat = create_pbr_material("Steel80s", "Steel80s")
    obj.data.materials.append(mat)


def run_test_suite():
    ok, msg = check_blender_version(BLENDER_VERSION_ENV)
    if not ok:
        print(f"Error: {msg}", file=sys.stderr)
        sys.exit(2)

    print("=== [TEST SUITE] Iniciando pruebas unitarias y de aceptación de validate_asset.py ===")
    tests_passed = 0
    tests_total = 0

    def assert_check_fails(check_name: str, test_title: str, setup_fn, spec: dict):
        nonlocal tests_passed, tests_total
        tests_total += 1
        print(f"\n--- Test {tests_total}: {test_title} ---")
        clear_scene()
        temp_blend = str(SCRIPT_DIR / "temp_broken_asset.blend")
        if setup_fn:
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
            print(f"  ==> OK: El validador detectó y rechazó la infracción correctamente en '{check_name}'.")
            tests_passed += 1
            return result
        else:
            print(f"  ==> ERROR: El validador NO detectó la infracción en '{check_name}'")
            return None

    def assert_check_passes(check_name: str, test_title: str, setup_fn, spec: dict):
        nonlocal tests_passed, tests_total
        tests_total += 1
        print(f"\n--- Test {tests_total}: {test_title} ---")
        clear_scene()
        temp_blend = str(SCRIPT_DIR / "temp_valid_asset.blend")
        if setup_fn:
            setup_fn()
        bpy.ops.wm.save_as_mainfile(filepath=temp_blend)

        result = validate_asset(temp_blend, spec)
        if os.path.exists(temp_blend):
            os.remove(temp_blend)

        global_pass = result["pass"]
        check_result = next((c for c in result["checks"] if c["name"] == check_name), None)

        print(f"  Resultado global: {'PASS' if global_pass else 'FAIL'}")
        if check_result:
            print(f"  Check '{check_name}': pass={check_result['pass']}, detalle={check_result['detail']}")

        if check_result and check_result["pass"]:
            print(f"  ==> OK: El check '{check_name}' pasó correctamente como se esperaba.")
            tests_passed += 1
            return result
        else:
            print(f"  ==> ERROR: El check '{check_name}' NO pasó (se esperaba pass=True).")
            return None

    # =========================================================================
    # Criterio 1: test_spec_schema_*
    # =========================================================================
    print("\n>>> CRITERIO 1: Validación estricta del esquema de ficha (spec_schema)")

    def test_spec_schema_valid():
        spec = make_valid_spec()
        assert_check_passes("spec_schema", "test_spec_schema_valid: Ficha válida pasa spec_schema", setup_valid_cube, spec)

    def test_spec_schema_missing_source():
        spec = make_valid_spec()
        del spec["source"]
        assert_check_fails("spec_schema", "test_spec_schema_missing_source: Falla ficha sin bloque source", setup_valid_cube, spec)

    def test_spec_schema_bad_origin():
        spec = make_valid_spec(source={"origin": "web", "url": "gen.py", "license": "propia", "author": "vh84"})
        assert_check_fails("spec_schema", "test_spec_schema_bad_origin: Falla source.origin='web' fuera de SOURCE_ORIGINS", setup_valid_cube, spec)

    def test_spec_schema_empty_license():
        spec = make_valid_spec(source={"origin": "procedural", "url": "gen.py", "license": "", "author": "vh84"})
        assert_check_fails("spec_schema", "test_spec_schema_empty_license: Falla source.license vacía", setup_valid_cube, spec)

    def test_spec_schema_two_dimensions():
        spec = make_valid_spec(dimensions=[1.0, 1.0])
        assert_check_fails("spec_schema", "test_spec_schema_two_dimensions: Falla dimensions con 2 elementos en vez de 3", setup_valid_cube, spec)

    def test_spec_schema_bad_name():
        spec = make_valid_spec(name="Bad-Name")
        assert_check_fails("spec_schema", "test_spec_schema_bad_name: Falla name='Bad-Name' (no cumple ASSET_NAME_RE)", setup_valid_cube, spec)

    test_spec_schema_valid()
    test_spec_schema_missing_source()
    test_spec_schema_bad_origin()
    test_spec_schema_empty_license()
    test_spec_schema_two_dimensions()
    test_spec_schema_bad_name()

    # =========================================================================
    # Criterio 2: test_dimensions_tolerance_*
    # =========================================================================
    print("\n>>> CRITERIO 2: Tolerancias de dimensiones (target_dimensions)")

    def setup_dim_tol_cube(actual_z: float):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, actual_z / 2.0), scale=(0.08, 0.08, actual_z))
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        obj = bpy.context.active_object
        obj.name = "dim_cube"
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_dim_tol = make_valid_spec(name="dim_tol_test", dimensions=[0.08, 0.08, 0.08])

    def test_dimensions_tolerance_fail():
        # Z real = 0.0812 m (+1.5% de error en pieza de 0.08m > tol 0.001m) -> FALLA
        assert_check_fails(
            "target_dimensions",
            "test_dimensions_tolerance_fail: Falla con error 1.5% (Z=0.0812m vs esperado 0.08m)",
            lambda: setup_dim_tol_cube(0.0812),
            spec_dim_tol,
        )

    def test_dimensions_tolerance_pass():
        # Z real = 0.0804 m (+0.5% de error en pieza de 0.08m <= tol 0.001m) -> PASA
        assert_check_passes(
            "target_dimensions",
            "test_dimensions_tolerance_pass: Pasa con error 0.5% (Z=0.0804m vs esperado 0.08m)",
            lambda: setup_dim_tol_cube(0.0804),
            spec_dim_tol,
        )

    test_dimensions_tolerance_fail()
    test_dimensions_tolerance_pass()

    # =========================================================================
    # Criterio 3: test_pivot_tolerance_*
    # =========================================================================
    print("\n>>> CRITERIO 3: Tolerancias de pivote y centrado (pivot_bottom_center)")

    spec_pivot_tol = make_valid_spec(name="pivot_tol_test", dimensions=[0.25, 0.25, 0.25])

    def setup_pivot_cube(center_x: float, center_y: float, min_z: float):
        actual_size = 0.25
        loc_z = min_z + actual_size / 2.0
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(center_x, center_y, loc_z), scale=(actual_size, actual_size, actual_size))
        bpy.ops.object.transform_apply(scale=True, location=True, rotation=False)
        obj = bpy.context.active_object
        obj.name = "pivot_cube"
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    def test_pivot_tolerance_base_fail():
        # Base a Z=0.003m > PIVOT_Z_TOL (0.002m) -> FALLA
        assert_check_fails(
            "pivot_bottom_center",
            "test_pivot_tolerance_base_fail: Falla con base a Z=0.003m (3 mm)",
            lambda: setup_pivot_cube(0.0, 0.0, 0.003),
            spec_pivot_tol,
        )

    def test_pivot_tolerance_base_pass():
        # Base a Z=0.001m <= PIVOT_Z_TOL (0.002m) -> PASA
        assert_check_passes(
            "pivot_bottom_center",
            "test_pivot_tolerance_base_pass: Pasa con base a Z=0.001m (1 mm)",
            lambda: setup_pivot_cube(0.0, 0.0, 0.001),
            spec_pivot_tol,
        )

    def test_pivot_tolerance_x_fail():
        # Centro X en 0.010m (1 cm) > tol 0.005m -> FALLA
        assert_check_fails(
            "pivot_bottom_center",
            "test_pivot_tolerance_x_fail: Falla con centro X a 0.010m (1 cm)",
            lambda: setup_pivot_cube(0.010, 0.0, 0.0),
            spec_pivot_tol,
        )

    def test_pivot_tolerance_x_pass():
        # Centro X en 0.002m (2 mm) <= tol 0.005m -> PASA
        assert_check_passes(
            "pivot_bottom_center",
            "test_pivot_tolerance_x_pass: Pasa con centro X a 0.002m (2 mm)",
            lambda: setup_pivot_cube(0.002, 0.0, 0.0),
            spec_pivot_tol,
        )

    test_pivot_tolerance_base_fail()
    test_pivot_tolerance_base_pass()
    test_pivot_tolerance_x_fail()
    test_pivot_tolerance_x_pass()

    # =========================================================================
    # Criterio 4: test_palette_*
    # =========================================================================
    print("\n>>> CRITERIO 4: Validación de materiales de paleta (palette_materials)")

    def test_palette_exact_pass():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "steel_mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = create_pbr_material("Steel80s", "Steel80s")
            obj.data.materials.append(mat)

        spec = make_valid_spec(materials=["Steel80s"])
        assert_check_passes("palette_materials", "test_palette_exact_pass: Pasa Steel80s con valores exactos de paleta", setup, spec)

    def test_palette_polyhaven_pass():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "vase_mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = bpy.data.materials.new(name="ceramic_vase_02")
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf is None:
                bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
            bsdf.inputs["Base Color"].default_value = (0.5, 0.4, 0.3, 1.0)
            obj.data.materials.append(mat)

        spec = make_valid_spec(
            name="polyhaven_asset",
            materials=["ceramic_vase_02"],
            source={"origin": "polyhaven", "url": "https://polyhaven.com/a/vase", "license": "CC0", "author": "Poly Haven"},
        )
        assert_check_passes(
            "palette_materials",
            "test_palette_polyhaven_pass: Pasa asset polyhaven con material fuera de paleta pero en materials",
            setup,
            spec,
        )

    def test_palette_roughness_fail():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "rough_mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = create_pbr_material("Steel80s", "Steel80s")
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Roughness"].default_value = 0.42  # Paleta es 0.40, dif=0.02 > tol 0.01
            obj.data.materials.append(mat)

        spec = make_valid_spec(materials=["Steel80s"])
        assert_check_fails("palette_materials", "test_palette_roughness_fail: Falla Steel80s con Roughness 0.42 (esperado 0.40)", setup, spec)

    def test_palette_base_color_fail():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "color_mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = create_pbr_material("Steel80s", "Steel80s")
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            c = list(bsdf.inputs["Base Color"].default_value)
            c[0] += 0.02  # Desplazado 0.02 en canal R > tol 0.01
            bsdf.inputs["Base Color"].default_value = c
            obj.data.materials.append(mat)

        spec = make_valid_spec(materials=["Steel80s"])
        assert_check_fails("palette_materials", "test_palette_base_color_fail: Falla Steel80s con Base Color desplazado 0.02 en R", setup, spec)

    def test_palette_not_in_materials_fail():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "unlisted_mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = create_pbr_material("Steel80s", "Steel80s")
            obj.data.materials.append(mat)

        spec = make_valid_spec(materials=["MahoganyWood"])  # Mesh tiene Steel80s pero la ficha solo lista MahoganyWood
        assert_check_fails("palette_materials", "test_palette_not_in_materials_fail: Falla material no listado en materials de la ficha", setup, spec)

    def test_palette_lowercase_fail():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "lower_mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = bpy.data.materials.new(name="steel80s")
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf is None:
                bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
            obj.data.materials.append(mat)

        spec = make_valid_spec(materials=["steel80s"])
        assert_check_fails(
            "palette_materials",
            "test_palette_lowercase_fail: Falla 'steel80s' en minúsculas en asset procedural (no es clave exacta)",
            setup,
            spec,
        )

    test_palette_exact_pass()
    test_palette_polyhaven_pass()
    test_palette_roughness_fail()
    test_palette_base_color_fail()
    test_palette_not_in_materials_fail()
    test_palette_lowercase_fail()

    # =========================================================================
    # Criterio 5: test_names_*
    # =========================================================================
    print("\n>>> CRITERIO 5: Validación de nombres (snake_case_names)")

    def test_names_bad_mesh_fail():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "Bad Mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = create_pbr_material("Steel80s", "Steel80s")
            obj.data.materials.append(mat)

        assert_check_fails("snake_case_names", "test_names_bad_mesh_fail: Falla objeto con espacio 'Bad Mesh'", setup, make_valid_spec())

    def test_names_mesh_dot_fail():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "Mesh.001"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = create_pbr_material("Steel80s", "Steel80s")
            obj.data.materials.append(mat)

        assert_check_fails("snake_case_names", "test_names_mesh_dot_fail: Falla objeto con punto 'Mesh.001'", setup, make_valid_spec())

    def test_names_mesh_dash_dot_fail():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "mesh-0.3"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = create_pbr_material("Steel80s", "Steel80s")
            obj.data.materials.append(mat)

        assert_check_fails("snake_case_names", "test_names_mesh_dash_dot_fail: Falla objeto con guion y punto 'mesh-0.3'", setup, make_valid_spec())

    def test_names_mat_dot_fail():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "valid_mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = bpy.data.materials.new(name="Steel80s.001")
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf is None:
                bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
            obj.data.materials.append(mat)

        assert_check_fails(
            "snake_case_names",
            "test_names_mat_dot_fail: Falla material con punto 'Steel80s.001'",
            setup,
            make_valid_spec(materials=["Steel80s.001"]),
        )

    def test_names_safebox_pass():
        def setup():
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            vis = bpy.context.active_object
            vis.name = "SafeBox_Mesh"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
            mat = create_pbr_material("Steel80s", "Steel80s")
            vis.data.materials.append(mat)

            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            col = bpy.context.active_object
            col.name = "SafeBox-col"
            bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

        assert_check_passes(
            "snake_case_names",
            "test_names_safebox_pass: Pasa SafeBox_Mesh y SafeBox-col",
            setup,
            make_valid_spec(name="safebox_asset", materials=["Steel80s"], collision=True),
        )

    test_names_bad_mesh_fail()
    test_names_mesh_dot_fail()
    test_names_mesh_dash_dot_fail()
    test_names_mat_dot_fail()
    test_names_safebox_pass()

    # =========================================================================
    # Tests de regresión existentes
    # =========================================================================
    print("\n>>> REGRESIÓN: Comprobaciones existentes de transformaciones, colisión y CLI")

    # Escala no aplicada
    def setup_unapplied_scale():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "unapplied_scale_mesh"
        obj.scale = (2.0, 1.0, 1.0)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_scale = make_valid_spec(name="broken_scale", dimensions=[2.0, 1.0, 1.0])
    assert_check_fails("applied_transforms", "Rechazar escala sin aplicar (scale=(2, 1, 1))", setup_unapplied_scale, spec_scale)

    # Rotación no aplicada
    def setup_unapplied_rotation():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5), rotation=(0.785, 0, 0))
        obj = bpy.context.active_object
        obj.name = "unapplied_rot_mesh"
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_rot = make_valid_spec(name="broken_rot")
    assert_check_fails("applied_transforms", "Rechazar rotación sin aplicar (rot=(45°, 0, 0))", setup_unapplied_rotation, spec_rot)

    # Base en Z=0.5m
    def setup_offset_pivot():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.0))
        obj = bpy.context.active_object
        obj.name = "offset_pivot_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_pivot = make_valid_spec(name="broken_pivot")
    assert_check_fails("pivot_bottom_center", "Rechazar base inferior en Z=0.5m (esperado Z=0.0m)", setup_offset_pivot, spec_pivot)

    # Dimensiones fuera de tolerancia (+25%)
    def setup_wrong_dimensions():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5), scale=(1.25, 1.0, 1.0))
        obj = bpy.context.active_object
        obj.name = "wrong_dim_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_dim = make_valid_spec(name="broken_dim")
    assert_check_fails("target_dimensions", "Rechazar dimensiones fuera de tolerancia (1.25m vs 1.0m esperado)", setup_wrong_dimensions, spec_dim)

    # Presupuesto de triángulos
    def setup_high_poly():
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=0.5, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "high_poly_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_tri = make_valid_spec(name="broken_poly", max_triangles=200)
    assert_check_fails("triangle_budget", "Rechazar exceso de polígonos (~4000 > max 200)", setup_high_poly, spec_tri)

    # Material inventado no en la paleta
    def setup_non_palette_material():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "alien_material_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = bpy.data.materials.new(name="NeonCyberpunkPink")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (1.0, 0.05, 0.8, 1.0)
        obj.data.materials.append(mat)

    spec_mat = make_valid_spec(name="broken_mat", materials=["NeonCyberpunkPink"])
    assert_check_fails("palette_materials", "Rechazar material no perteneciente a la paleta ('NeonCyberpunkPink')", setup_non_palette_material, spec_mat)

    # Nodos procedurales
    def setup_procedural_nodes():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "procedural_node_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        noise = mat.node_tree.nodes.new("ShaderNodeTexNoise")
        mat.node_tree.links.new(noise.outputs["Fac"], mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"])
        obj.data.materials.append(mat)

    spec_proc = make_valid_spec(name="broken_proc")
    assert_check_fails("no_procedural_nodes", "Rechazar uso de nodo procedural ('ShaderNodeTexNoise')", setup_procedural_nodes, spec_proc)

    # Malla de colisión ausente
    def setup_missing_collision():
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
        obj = bpy.context.active_object
        obj.name = "visual_only_mesh"
        bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
        mat = create_pbr_material("Steel80s", "Steel80s")
        obj.data.materials.append(mat)

    spec_col = make_valid_spec(name="broken_collision", collision=True)
    assert_check_fails("collision_mesh", "Rechazar ausencia de malla de colisión '-col' requerida", setup_missing_collision, spec_col)

    # Comprobación de versión de Blender
    def test_blender_version_mismatch():
        nonlocal tests_passed, tests_total
        tests_total += 1
        print(f"\n--- Test {tests_total}: Comprobación de versión de Blender ---")
        current_version = ".".join(str(n) for n in bpy.app.version)
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_env = Path(tmpdir) / "blender_version.env"
            tmp_env.write_text("BLENDER_VERSION=0.0.0\n", encoding="utf-8")

            ok_bad, msg_bad = check_blender_version(tmp_env)
            if ok_bad or "0.0.0" not in msg_bad:
                print(f"  ==> ERROR: Esperado False y '0.0.0' en mensaje, obtenido ok={ok_bad}, msg='{msg_bad}'")
                return

            tmp_env.write_text(f"BLENDER_VERSION={current_version}\n", encoding="utf-8")
            ok_good, msg_good = check_blender_version(tmp_env)
            if not ok_good:
                print(f"  ==> ERROR: Esperado True con versión actual ({current_version}), obtenido ok={ok_good}, msg='{msg_good}'")
                return

            print(f"  ==> OK: check_blender_version rechaza 0.0.0 y acepta {current_version}.")
            tests_passed += 1

    test_blender_version_mismatch()

    # Código de salida CLI ante fallo
    def test_cli_exit_code_fail():
        nonlocal tests_passed, tests_total
        tests_total += 1
        print(f"\n--- Test {tests_total}: Código de salida CLI ante asset inválido (esperado 1) ---")
        with tempfile.TemporaryDirectory() as tmpdir:
            clear_scene()
            setup_bad_mesh = lambda: test_names_bad_mesh_fail  # recrear bad mesh
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
            obj = bpy.context.active_object
            obj.name = "Bad Mesh"
            bad_blend = Path(tmpdir) / "bad.blend"
            bpy.ops.wm.save_as_mainfile(filepath=str(bad_blend))

            spec_file = Path(tmpdir) / "spec.json"
            spec_file.write_text(json.dumps(make_valid_spec(name="cli_fail")), encoding="utf-8")

            cmd = [
                bpy.app.binary_path,
                "-b",
                str(bad_blend),
                "--factory-startup",
                "-P",
                str(SCRIPT_DIR / "validate_asset.py"),
                "--",
                str(spec_file),
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            if res.returncode == 1:
                print("  ==> OK: La CLI devolvió returncode=1 ante asset inválido.")
                tests_passed += 1
            else:
                print(f"  ==> ERROR: Se esperaba returncode=1, se obtuvo {res.returncode}")
                if res.stdout:
                    print(f"  stdout: {res.stdout[-300:]}")
                if res.stderr:
                    print(f"  stderr: {res.stderr[-300:]}")

    test_cli_exit_code_fail()

    # Código de salida CLI ante asset válido
    def test_cli_exit_code_pass():
        nonlocal tests_passed, tests_total
        tests_total += 1
        print(f"\n--- Test {tests_total}: Código de salida CLI ante asset válido (esperado 0) ---")
        wood_wedge_glb = PROJECT_ROOT / "assets" / "models" / "wood_wedge.glb"
        wood_wedge_spec = SCRIPT_DIR / "specs" / "wood_wedge.json"
        cmd = [
            bpy.app.binary_path,
            "-b",
            "--factory-startup",
            "-P",
            str(SCRIPT_DIR / "validate_asset.py"),
            "--",
            str(wood_wedge_glb),
            str(wood_wedge_spec),
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if res.returncode == 0:
            print("  ==> OK: La CLI devolvió returncode=0 ante asset válido (wood_wedge.glb).")
            tests_passed += 1
        else:
            print(f"  ==> ERROR: Se esperaba returncode=0, se obtuvo {res.returncode}")
            if res.stdout:
                print(f"  stdout: {res.stdout[-300:]}")
            if res.stderr:
                print(f"  stderr: {res.stderr[-300:]}")

    test_cli_exit_code_pass()

    print("\n==========================================")
    print(f"Resumen de tests de validación: {tests_passed}/{tests_total} pasados.")
    print("==========================================")

    if tests_passed == tests_total:
        print("==> Todos los tests unitarios y de aceptación del validador pasaron con éxito.")
        sys.exit(0)
    else:
        print(f"==> Fallaron {tests_total - tests_passed} tests.")
        sys.exit(1)


if __name__ == "__main__":
    run_test_suite()
