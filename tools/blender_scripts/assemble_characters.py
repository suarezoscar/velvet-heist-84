#!/usr/bin/env python3
"""
tools/blender_scripts/assemble_characters.py
Importa modelos Mixamo (Crypto y SWAT), aplica escala métrica (1.80m),
alinea el pivote a Z=0 e integra la suite completa de animaciones de sigilo
(caminar, de puntillas, agacharse, reptar, pegarse a la pared) en formato .glb para Godot 4.
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

    # 2. Calcular límites globales para escalar exactamente a target_height
    # Evaluamos los vértices de las mallas hijas
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        print("ERROR: No se encontraron mallas.")
        return False

    min_z = 999999.0
    max_z = -999999.0
    for m in meshes:
        for v in m.data.vertices:
            global_v = m.matrix_world @ v.co
            if global_v.z < min_z:
                min_z = global_v.z
            if global_v.z > max_z:
                max_z = global_v.z

    current_height = max_z - min_z
    print(f"Altura detectada: {current_height:.3f}m (Z: {min_z:.3f} a {max_z:.3f})")

    scale_factor = target_height / current_height if current_height > 0.01 else 1.0
    print(f"Factor de escala aplicado: {scale_factor:.4f}")

    # Aplicar escala al armature y reposicionar pivote en el suelo (Z=0)
    main_armature.scale = (scale_factor, scale_factor, scale_factor)
    bpy.context.view_layer.objects.active = main_armature
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Re-evaluar tras escala y ajustar offset Z para que los pies toquen Z=0
    min_z_scaled = min_z * scale_factor
    offset_z = -min_z_scaled
    print(f"Ajustando pies al suelo (offset Z: {offset_z:.3f}m)...")
    main_armature.location.z += offset_z
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    # 3. Inicializar animation_data si no existe
    if not main_armature.animation_data:
        main_armature.animation_data_create()

    # 4. Importar cada animación y asignarla como track NLA
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

        # Encontrar la acción importada y transferirla a main_armature
        for act in new_actions:
            act.name = anim_name
            track = main_armature.animation_data.nla_tracks.new()
            track.name = anim_name
            track.strips.new(anim_name, 1, act)
            print(f"  + Animación integrada en NLA: '{anim_name}'")

        # Limpiar los objetos auxiliares (armatures secundarias) importadas por el fbx de animación
        for obj in new_objects:
            bpy.data.objects.remove(obj, do_unlink=True)

    # 5. Exportar a GLTF / GLB con animaciones empaquetadas
    print(f"Exportando GLB a: {output_glb}...")
    bpy.ops.export_scene.gltf(
        filepath=output_glb,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
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
