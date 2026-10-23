"""tools/blender_scripts/lib/blender_utils.py.

Funciones compartidas para generadores y adaptadores de assets 3D en Blender:
- decimate_to_budget: reducción controlada de polígonos sobre mallas visuales.
- add_box_collision: generación de caja de colisión estática '<name>-colonly'.
- center_by_pivot: centrado y posicionamiento de pivote (bottom_center, top_center, back_center).
"""

from typing import List, Tuple
import bpy
import mathutils

PIVOT_TYPES = ("bottom_center", "top_center", "back_center")


def is_collision_object(obj: bpy.types.Object) -> bool:
    """Verifica si un objeto es de colisión por su sufijo -col o -colonly."""
    name_lower = obj.name.lower()
    return name_lower.endswith("-col") or name_lower.endswith("-colonly")


def get_visual_mesh_objects(objects: list) -> List[bpy.types.Object]:
    """Obtiene las mallas visuales de una lista de objetos."""
    return [
        obj
        for obj in objects
        if getattr(obj, "type", None) == "MESH" and not is_collision_object(obj)
    ]


def count_mesh_triangles(mesh_objects: List[bpy.types.Object]) -> int:
    """Calcula el total de triángulos de una lista de objetos malla."""
    total = 0
    for obj in mesh_objects:
        if obj.type == "MESH" and obj.data:
            for poly in obj.data.polygons:
                total += max(1, len(poly.vertices) - 2)
    return total


def compute_world_bounds(objects: list) -> Tuple[mathutils.Vector, mathutils.Vector]:
    """Calcula el bounding box global (AABB) de una lista de objetos."""
    all_corners = []
    for obj in objects:
        if getattr(obj, "type", None) == "MESH" and getattr(obj, "bound_box", None):
            for corner in obj.bound_box:
                all_corners.append(obj.matrix_world @ mathutils.Vector(corner))

    if not all_corners:
        return mathutils.Vector((0.0, 0.0, 0.0)), mathutils.Vector((0.0, 0.0, 0.0))

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


def decimate_to_budget(objects: list, budget: int) -> int:
    """Aplica la regla de reducción Decimate (COLLAPSE) sobre las mallas visuales

    y devuelve los triángulos finales.
    Regla FEAT-010:
    ratio = 0.95 * presupuesto / triángulos actuales;
    si aún se pasa, se repite multiplicando el ratio por 0.9, como máximo 5 veces.
    """
    visual_objs = get_visual_mesh_objects(objects)
    current_triangles = count_mesh_triangles(visual_objs)

    if current_triangles <= budget or budget <= 0 or not visual_objs:
        return current_triangles

    ratio = 0.95 * float(budget) / float(current_triangles)
    if ratio < 1.0:
        for obj in visual_objs:
            mod = obj.modifiers.new(name="Decimate", type="DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = max(0.001, ratio)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier="Decimate")

    current_triangles = count_mesh_triangles(visual_objs)

    attempts = 0
    while current_triangles > budget and attempts < 5:
        attempts += 1
        for obj in visual_objs:
            mod = obj.modifiers.new(name="Decimate_Iter", type="DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = 0.9
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier="Decimate_Iter")
        current_triangles = count_mesh_triangles(visual_objs)

    return current_triangles


def add_box_collision(objects: list, name: str) -> bpy.types.Object:
    """Crea <name>-colonly con la AABB visual de objects."""
    visual_objs = get_visual_mesh_objects(objects)
    min_v, max_v = compute_world_bounds(visual_objs)

    size_x = max(max_v.x - min_v.x, 0.001)
    size_y = max(max_v.y - min_v.y, 0.001)
    size_z = max(max_v.z - min_v.z, 0.001)

    center_x = (min_v.x + max_v.x) / 2.0
    center_y = (min_v.y + max_v.y) / 2.0
    center_z = (min_v.z + max_v.z) / 2.0

    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=(center_x, center_y, center_z),
        scale=(size_x, size_y, size_z),
    )
    col = bpy.context.active_object
    col.name = f"{name}-colonly"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return col


def center_by_pivot(objects: list, pivot: str) -> None:
    """Traslada todas las mallas (incluida la colisión) para cumplir el tipo de pivote.

    - bottom_center: centro X/Y en 0, base inferior en Z=0.
    - top_center: centro X/Y en 0, parte superior en Z=0.
    - back_center: centro X y centro Z en 0; cara trasera en Y=0
      (deja la cara trasera en el lado de Y que ya estaba más cerca de 0).
    Solo traslada, nunca escala.
    """
    if pivot not in PIVOT_TYPES:
        raise ValueError(f"Pivote desconocido '{pivot}'. Válidos: {PIVOT_TYPES}")

    visual_objs = get_visual_mesh_objects(objects)
    if not visual_objs:
        return

    min_v, max_v = compute_world_bounds(visual_objs)

    center_x = (min_v.x + max_v.x) / 2.0
    center_y = (min_v.y + max_v.y) / 2.0
    center_z = (min_v.z + max_v.z) / 2.0

    if pivot == "bottom_center":
        offset_x = -center_x
        offset_y = -center_y
        offset_z = -min_v.z
    elif pivot == "top_center":
        offset_x = -center_x
        offset_y = -center_y
        offset_z = -max_v.z
    elif pivot == "back_center":
        offset_x = -center_x
        offset_z = -center_z
        if abs(min_v.y) <= abs(max_v.y):
            offset_y = -min_v.y
        else:
            offset_y = -max_v.y

    offset = mathutils.Vector((offset_x, offset_y, offset_z))

    mesh_objs = [obj for obj in objects if getattr(obj, "type", None) == "MESH"]
    for obj in mesh_objs:
        mat_world = obj.matrix_world.copy()
        if obj.data and hasattr(obj.data, "vertices"):
            for v in obj.data.vertices:
                v.co = (mat_world @ v.co) + offset
            obj.data.update()
        obj.matrix_world = mathutils.Matrix.Identity(4)
        obj.location = (0.0, 0.0, 0.0)
        obj.rotation_euler = (0.0, 0.0, 0.0)
        obj.scale = (1.0, 1.0, 1.0)

    bpy.context.view_layer.update()
