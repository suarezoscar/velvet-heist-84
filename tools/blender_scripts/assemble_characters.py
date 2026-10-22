#!/usr/bin/env python3
"""
tools/blender_scripts/assemble_characters.py
Importa modelos Mixamo (Crypto y SWAT), aplica escala métrica humana exacta (1.80m / 1.82m)
con transforms aplicados (desacoplando jerarquías con CLEAR_KEEP_TRANSFORM para evitar
el bug de escala centimétrica de 180m), normaliza huesos y vertex groups a 'mixamorig:',
ajusta el pivote inferior a Z=0 e integra las 11 animaciones de sigilo en formato .glb para Godot 4.
"""

import os
import sys

try:
    import bpy
    import mathutils
except ImportError:
    print("Error: Este script debe ejecutarse dentro de Blender (blender -b -P <script.py>).")
    sys.exit(1)

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW_MODELS_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "raw")
ANIM_DIR = os.path.join(RAW_MODELS_DIR, "animations")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "characters")
os.makedirs(OUTPUT_DIR, exist_ok=True)

ANIMATIONS = {
    "walk": os.path.join(ANIM_DIR, "walk.fbx"),
    "tiptoe_walk": os.path.join(ANIM_DIR, "tiptoe_walk.fbx"),
    "sneak_walk": os.path.join(ANIM_DIR, "sneak_walk.fbx"),
    "crouch_walk": os.path.join(ANIM_DIR, "crouch_walk.fbx"),
    "crouch_to_prone": os.path.join(ANIM_DIR, "crouch_to_prone.fbx"),
    "prone_idle": os.path.join(ANIM_DIR, "prone_idle.fbx"),
    "prone_forward": os.path.join(ANIM_DIR, "prone_forward.fbx"),
    "taking_cover_idle": os.path.join(ANIM_DIR, "taking_cover_idle.fbx"),
    "cover_idle": os.path.join(ANIM_DIR, "cover_idle.fbx"),
    "cover_sneak_left": os.path.join(ANIM_DIR, "cover_sneak_left.fbx"),
    "cover_sneak_right": os.path.join(ANIM_DIR, "cover_sneak_right.fbx"),
}


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def process_character(base_fbx: str, output_glb: str, target_height: float = 1.80):
    print(f"\n=======================================================")
    print(f"Procesando personaje: {os.path.basename(base_fbx)} -> {os.path.basename(output_glb)}")
    print(f"=======================================================")
    clear_scene()

    # 1. Importar el modelo base con malla y armature
    bpy.ops.import_scene.fbx(filepath=base_fbx)

    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not armatures:
        print("ERROR: No se encontró Armature en", base_fbx)
        return False
    main_armature = armatures[0]
    main_armature.name = "CharacterArmature"

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        print("ERROR: No se encontraron mallas.")
        return False

    print(f"Detectada armadura '{main_armature.name}' y {len(meshes)} malla(s): {[m.name for m in meshes]}")

    # 2. Normalizar prefijo de huesos y grupos de vértices de 'mixamorig1:' a 'mixamorig:'
    for b in main_armature.data.bones:
        if b.name.startswith("mixamorig1:"):
            b.name = b.name.replace("mixamorig1:", "mixamorig:")
    for m in meshes:
        for vg in m.vertex_groups:
            if vg.name.startswith("mixamorig1:"):
                vg.name = vg.name.replace("mixamorig1:", "mixamorig:")

    # 3. Desvincular mallas manteniendo transformación para aplicar la escala base (0.01 centimétrico de FBX)
    for m in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        m.select_set(True)
        bpy.context.view_layer.objects.active = m
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")

    for o in meshes + [main_armature]:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Reparentar mallas a la armadura
    for m in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        m.select_set(True)
        main_armature.select_set(True)
        bpy.context.view_layer.objects.active = main_armature
        bpy.ops.object.parent_set(type="ARMATURE")

    # 4. Medir altura métrica real y reescalar al tamaño objetivo exacto
    min_z = min((m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices)
    max_z = max((m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices)
    current_height = max_z - min_z
    scale_factor = target_height / current_height if current_height > 0.01 else 1.0
    print(f"Altura métrica previa: {current_height:.4f}m. Factor de ajuste a {target_height}m: {scale_factor:.4f}")

    # Desvincular, aplicar scale_factor y reaplicar transforms
    for m in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        m.select_set(True)
        bpy.context.view_layer.objects.active = m
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")

    for o in meshes + [main_armature]:
        o.scale *= scale_factor
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    for m in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        m.select_set(True)
        main_armature.select_set(True)
        bpy.context.view_layer.objects.active = main_armature
        bpy.ops.object.parent_set(type="ARMATURE")

    # 5. Ajustar offset Z para que los pies toquen exactamente el suelo Z=0
    min_z_scaled = min((m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices)
    print(f"Ajustando pies al suelo Z=0.0 (offset Z: {-min_z_scaled:.4f}m)...")
    for o in meshes + [main_armature]:
        o.location.z -= min_z_scaled
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    final_min_z = min((m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices)
    final_max_z = max((m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices)
    print(f"Dimensiones finales: Z={final_min_z:.4f}m a {final_max_z:.4f}m (Altura: {final_max_z - final_min_z:.4f}m)")

    # 6. Inicializar animation_data si no existe
    if not main_armature.animation_data:
        main_armature.animation_data_create()

    # 7. Importar cada animación, reescalar curvas de desplazamiento (Hips) y asignar a NLA
    for anim_name, anim_path in ANIMATIONS.items():
        if not os.path.exists(anim_path):
            print(f"Aviso: Archivo de animación no encontrado: {anim_path}")
            continue

        existing_actions = set(bpy.data.actions)
        existing_objects = set(bpy.context.scene.objects)

        # Importar el FBX de animación
        bpy.ops.import_scene.fbx(filepath=anim_path)

        new_actions = set(bpy.data.actions) - existing_actions
        new_objects = set(bpy.context.scene.objects) - existing_objects

        for act in new_actions:
            act.name = anim_name
            # Reescalar curvas de desplazamiento de huesos (centímetros Mixamo a metros aplicados)
            factor = 0.01 * scale_factor
            if hasattr(act, "layers"):
                for l in act.layers:
                    for s in l.strips:
                        for b in s.channelbags:
                            for c in b.fcurves:
                                if "location" in c.data_path:
                                    for k in c.keyframe_points:
                                        k.co[1] *= factor
            if hasattr(act, "fcurves"):
                for c in act.fcurves:
                    if "location" in c.data_path:
                        for k in c.keyframe_points:
                            k.co[1] *= factor

            track = main_armature.animation_data.nla_tracks.new()
            track.name = anim_name
            track.strips.new(anim_name, 1, act)
            print(f"  + Animación integrada en NLA: '{anim_name}'")

        # Limpiar armaduras secundarias auxiliares importadas por el fbx de animación
        for obj in new_objects:
            bpy.data.objects.remove(obj, do_unlink=True)

    # 8. Exportar a GLTF / GLB métrico limpio
    print(f"Exportando GLB métrico a: {output_glb}...")
    bpy.ops.export_scene.gltf(
        filepath=output_glb,
        export_format="GLB",
        export_yup=True,
        export_animations=True,
        export_nla_strips=True,
        export_def_bones=True,
    )

    size_mb = os.path.getsize(output_glb) / (1024 * 1024)
    print(f"¡Éxito! Archivo generado: {output_glb} ({size_mb:.2f} MB)")
    return True


if __name__ == "__main__":
    crypto_fbx = os.path.join(RAW_MODELS_DIR, "crypto.fbx")
    swat_fbx = os.path.join(RAW_MODELS_DIR, "swat.fbx")

    thief_glb = os.path.join(OUTPUT_DIR, "thief_crypto.glb")
    guard_glb = os.path.join(OUTPUT_DIR, "guard_swat.glb")

    if os.path.exists(crypto_fbx):
        process_character(crypto_fbx, thief_glb, target_height=1.80)
    if os.path.exists(swat_fbx):
        process_character(swat_fbx, guard_glb, target_height=1.82)
