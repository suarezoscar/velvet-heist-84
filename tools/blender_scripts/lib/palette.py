# tools/blender_scripts/lib/palette.py
"""
Paleta unificada PBR 'Velvet 84' para Blender (regla 02 y FEAT-001).
Única fuente de verdad de materiales para Velvet Heist '84.
Prohibido el uso de nodos procedurales: solo Principled BSDF limpio o texturas simples.
"""

from typing import Any, Dict, List, Optional, Tuple, Union
import math

try:
    import bpy
except ImportError:
    bpy = None

# Paleta oficial PBR Velvet '84
PALETTE: Dict[str, Dict[str, Any]] = {
    # 6 Materiales base oficiales de la regla 02
    "MahoganyWood": {
        "hex": "#3B1E14",
        "roughness": 0.35,
        "metallic": 0.0,
        "description": "Madera noble de caoba barnizada para zócalos, puertas y vitrinas.",
    },
    "BrassGold": {
        "hex": "#D4AF37",
        "roughness": 0.20,
        "metallic": 0.90,
        "description": "Latón dorado pulido ochentero para diales, pomos, marcos y biseles.",
    },
    "Steel80s": {
        "hex": "#2B2D42",
        "roughness": 0.40,
        "metallic": 0.80,
        "description": "Acero laminado en frío oscuro para cajas fuertes y maquinaria.",
    },
    "VelvetBlack": {
        "hex": "#16161A",
        "roughness": 0.85,
        "metallic": 0.0,
        "description": "Terciopelo negro mate absorbente de luz para el atuendo del ladrón.",
    },
    "GuardNavy": {
        "hex": "#1B263B",
        "roughness": 0.65,
        "metallic": 0.10,
        "description": "Azul marino oscuro reglamentario de la guardia de seguridad.",
    },
    "BakeliteBlack": {
        "hex": "#111113",
        "roughness": 0.15,
        "metallic": 0.05,
        "description": "Baquelita sintética negra pulida para linternas, teléfonos y carcasas.",
    },
    # Materiales de entorno y suelos
    "CarpetWine": {
        "hex": "#4A121A",
        "roughness": 0.90,
        "metallic": 0.0,
        "description": "Moqueta de lana color vino tinto/burdeos.",
    },
    "ParquetWood": {
        "hex": "#6F4E37",
        "roughness": 0.45,
        "metallic": 0.0,
        "description": "Parqué de madera tratada para salas secundarias.",
    },
    "MarbleWhite": {
        "hex": "#ECEBE4",
        "roughness": 0.25,
        "metallic": 0.05,
        "description": "Mármol blanco pulido de la galería principal.",
    },
    # Props y vehículos de los años 80
    "BurgundyCar": {
        "hex": "#3A0D14",
        "roughness": 0.20,
        "metallic": 0.35,
        "description": "Pintura metalizada burdeos para el coche de fuga 1984.",
    },
    "ChromeTrim": {
        "hex": "#D8D8E0",
        "roughness": 0.10,
        "metallic": 0.95,
        "description": "Cromado reflectante para parachoques y molduras de coche.",
    },
    "GlassAmber": {
        "hex": "#FFAA22",
        "roughness": 0.10,
        "metallic": 0.0,
        "description": "Óptica ámbar de faros antiniebla e indicadores.",
    },
    "CashGreen": {
        "hex": "#2E5D34",
        "roughness": 0.85,
        "metallic": 0.0,
        "description": "Papel moneda verde oscuro de fajos de billetes de 1984.",
    },
    "PaperWhite": {
        "hex": "#F0EAD6",
        "roughness": 0.90,
        "metallic": 0.0,
        "description": "Papel/cartón beige desgastado para esferas de reloj y fajas.",
    },
    "CanvasOil": {
        "hex": "#5C4033",
        "roughness": 0.70,
        "metallic": 0.0,
        "description": "Lienzo al óleo para obras maestras.",
    },
    # Seguridad y equipamiento del museo
    "CctvCasing": {
        "hex": "#D6D1C2",
        "roughness": 0.35,
        "metallic": 0.10,
        "description": "Plástico beige ochentero para cámaras de seguridad.",
    },
    "CctvLens": {
        "hex": "#05080D",
        "roughness": 0.05,
        "metallic": 0.90,
        "description": "Vidrio tintado antireflejos para objetivos CCTV.",
    },
    "CctvLed": {
        "hex": "#FF1A1A",
        "roughness": 0.20,
        "metallic": 0.0,
        "emission": (1.0, 0.0, 0.0, 1.0),
        "emission_strength": 4.0,
        "description": "LED rojo analógico de grabación activa.",
    },
    "GlassClear": {
        "hex": "#D9EBF2",
        "roughness": 0.05,
        "metallic": 0.10,
        "alpha": 0.35,
        "description": "Cristal de vitrinas de museo.",
    },
}

# Nodos permitidos según la regla 02 (solo Principled BSDF limpio o textura de imagen simple)
ALLOWED_NODE_TYPES = {
    "OUTPUT_MATERIAL", "ShaderNodeOutputMaterial",
    "BSDF_PRINCIPLED", "ShaderNodeBsdfPrincipled",
    "TEX_IMAGE", "ShaderNodeTexImage",
    "UVMAP", "ShaderNodeUVMap",
    "MAPPING", "ShaderNodeMapping",
}

# Tipos de nodos procedurales explícitamente prohibidos
FORBIDDEN_NODE_TYPES = {
    "ShaderNodeTexNoise", "TEX_NOISE",
    "ShaderNodeTexVoronoi", "TEX_VORONOI",
    "ShaderNodeValToRGB", "VALTORGB",  # Color Ramp
    "ShaderNodeTexWave", "TEX_WAVE",
    "ShaderNodeTexMusgrave", "TEX_MUSGRAVE",
    "ShaderNodeTexMagic", "TEX_MAGIC",
    "ShaderNodeTexGradient", "TEX_GRADIENT",
    "ShaderNodeTexChecker", "TEX_CHECKER",
    "ShaderNodeTexBrick", "TEX_BRICK",
    "ShaderNodeMapRange", "MAP_RANGE",
    "ShaderNodeMath", "MATH",
    "ShaderNodeVectorMath", "VECT_MATH",
}


def hex_to_linear_rgb(hex_code: str) -> Tuple[float, float, float, float]:
    """Convierte un código hexadecimal sRGB (#RRGGBB) a RGBA lineal (0.0 - 1.0)."""
    hex_code = hex_code.lstrip("#")
    if len(hex_code) == 6:
        r_s = int(hex_code[0:2], 16) / 255.0
        g_s = int(hex_code[2:4], 16) / 255.0
        b_s = int(hex_code[4:6], 16) / 255.0
    elif len(hex_code) == 3:
        r_s = int(hex_code[0] * 2, 16) / 255.0
        g_s = int(hex_code[1] * 2, 16) / 255.0
        b_s = int(hex_code[2] * 2, 16) / 255.0
    else:
        raise ValueError(f"Hex code inválido: {hex_code}")

    def to_linear(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (to_linear(r_s), to_linear(g_s), to_linear(b_s), 1.0)


def linear_to_hex(linear_rgb: Union[Tuple, List]) -> str:
    """Convierte RGBA/RGB lineal a código hexadecimal sRGB (#RRGGBB)."""
    def to_srgb(c: float) -> float:
        c = max(0.0, min(1.0, c))
        return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055

    r_s = int(round(to_srgb(linear_rgb[0]) * 255.0))
    g_s = int(round(to_srgb(linear_rgb[1]) * 255.0))
    b_s = int(round(to_srgb(linear_rgb[2]) * 255.0))
    return f"#{r_s:02X}{g_s:02X}{b_s:02X}"


def get_palette_def(key: str) -> Optional[Dict[str, Any]]:
    """Devuelve la definición de un material de la paleta si existe."""
    # Búsqueda insensible a mayúsculas/minúsculas o coincidencia exacta
    if key in PALETTE:
        return PALETTE[key]
    key_lower = key.lower()
    for name, data in PALETTE.items():
        if name.lower() == key_lower:
            return data
    return None


def create_pbr_material(
    name: str,
    palette_key_or_props: Union[str, Dict[str, Any], None] = None,
    *,
    base_color: Optional[Tuple[float, float, float, float]] = None,
    roughness: Optional[float] = None,
    metallic: Optional[float] = None,
    alpha: float = 1.0,
    emission: Optional[Tuple[float, float, float, float]] = None,
    emission_strength: float = 1.0,
    texture_diffuse: Optional[str] = None,
) -> "bpy.types.Material":
    """
    Crea un material Principled BSDF en Blender asegurando conformidad estricta
    con la regla 02: sin nodos procedurales, valores PBR limpios y paleta Velvet '84.
    """
    if bpy is None:
        raise RuntimeError("create_pbr_material solo puede ejecutarse dentro de Blender.")

    # Resolver propiedades desde la paleta
    mat_props: Dict[str, Any] = {}
    if isinstance(palette_key_or_props, str):
        p_def = get_palette_def(palette_key_or_props)
        if p_def:
            mat_props = p_def.copy()
        else:
            raise KeyError(f"El material '{palette_key_or_props}' no está en la paleta oficial.")
    elif isinstance(palette_key_or_props, dict):
        mat_props = palette_key_or_props.copy()
    elif palette_key_or_props is None:
        p_def = get_palette_def(name)
        if p_def:
            mat_props = p_def.copy()

    # Reutilizar material si ya existe con el mismo nombre
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)

    mat.use_nodes = True
    node_tree = mat.node_tree
    nodes = node_tree.nodes

    # Eliminar nodos que no sean Principled BSDF o Material Output
    bsdf = None
    output_node = None
    for n in list(nodes):
        if n.type == "BSDF_PRINCIPLED":
            bsdf = n
        elif n.type == "OUTPUT_MATERIAL":
            output_node = n
        else:
            nodes.remove(n)

    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    if output_node is None:
        output_node = nodes.new("ShaderNodeOutputMaterial")

    # Asegurar enlace de BSDF a Material Output
    is_linked = any(
        link.from_node == bsdf and link.to_node == output_node
        for link in node_tree.links
    )
    if not is_linked:
        node_tree.links.new(bsdf.outputs["BSDF"], output_node.inputs["Surface"])

    # Determinar parámetros finales
    final_color = base_color
    if final_color is None:
        if "hex" in mat_props:
            final_color = hex_to_linear_rgb(mat_props["hex"])
        elif "base_color" in mat_props:
            final_color = mat_props["base_color"]
        else:
            final_color = (0.5, 0.5, 0.5, 1.0)

    final_roughness = roughness if roughness is not None else mat_props.get("roughness", 0.5)
    final_metallic = metallic if metallic is not None else mat_props.get("metallic", 0.0)
    final_alpha = alpha if alpha != 1.0 else mat_props.get("alpha", 1.0)
    final_emission = emission or mat_props.get("emission")
    final_emission_strength = (
        emission_strength
        if emission_strength != 1.0
        else mat_props.get("emission_strength", 1.0)
    )

    # Configurar sockets del Principled BSDF
    if "Base Color" in bsdf.inputs:
        bsdf.inputs["Base Color"].default_value = final_color
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = final_roughness
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = final_metallic
    if "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = final_alpha
        if final_alpha < 1.0:
            if hasattr(mat, "blend_method"):
                mat.blend_method = "BLEND"

    if final_emission:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = final_emission
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = final_emission
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = final_emission_strength

    # Soporte para textura difusa simple (sin nodos procedurales)
    if texture_diffuse:
        import os
        if os.path.exists(texture_diffuse):
            tex_node = nodes.new("ShaderNodeTexImage")
            tex_node.image = bpy.data.images.load(texture_diffuse)
            node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])

    return mat


def check_material_procedural_nodes(mat: "bpy.types.Material") -> Tuple[bool, str]:
    """
    Verifica que el material no utilice nodos procedurales prohibidos.
    Retorna (True, "OK") o (False, "Descripción del nodo prohibido").
    """
    if not mat.use_nodes or not mat.node_tree:
        return True, "No usa nodos de sombreado (colores planos)."

    for node in mat.node_tree.nodes:
        n_type = getattr(node, "type", "")
        bl_id = getattr(node, "bl_idname", "")
        if n_type in FORBIDDEN_NODE_TYPES or bl_id in FORBIDDEN_NODE_TYPES:
            return False, f"Usa nodo procedural prohibido: '{bl_id or n_type}' ({node.name})."
        if n_type not in ALLOWED_NODE_TYPES and bl_id not in ALLOWED_NODE_TYPES:
            return False, f"Usa nodo no permitido por la regla 02: '{bl_id or n_type}' ({node.name})."

    return True, "Sin nodos procedurales."


def check_material_against_palette(
    mat: "bpy.types.Material", key: str, tol: float
) -> Tuple[bool, str]:
    """Compara el Principled BSDF de mat con PALETTE[key]: Base Color lineal por canal,
    Roughness, Metallic y Alpha (si la entrada define alpha). Key debe ser clave exacta.
    Un material sin Principled BSDF falla.
    """
    if key not in PALETTE:
        return False, f"La clave '{key}' no existe en PALETTE."

    if not getattr(mat, "use_nodes", False) or not mat.node_tree:
        return False, f"Material '{mat.name}' no tiene Principled BSDF (no usa nodos)."

    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return False, f"Material '{mat.name}' no tiene nodo Principled BSDF."

    palette_entry = PALETTE[key]
    expected_color = hex_to_linear_rgb(palette_entry["hex"])

    if "Base Color" not in bsdf.inputs:
        return False, f"El nodo BSDF del material '{mat.name}' no tiene socket 'Base Color'."
    actual_color = bsdf.inputs["Base Color"].default_value
    for i, ch_name in enumerate(["R", "G", "B"]):
        diff = abs(actual_color[i] - expected_color[i])
        if diff > tol:
            return (
                False,
                f"Base Color canal {ch_name} difiere en {diff:.4f} (actual={actual_color[i]:.4f}, esperado={expected_color[i]:.4f}, tol={tol})",
            )

    if "Roughness" not in bsdf.inputs:
        return False, f"El nodo BSDF del material '{mat.name}' no tiene socket 'Roughness'."
    actual_roughness = float(bsdf.inputs["Roughness"].default_value)
    expected_roughness = float(palette_entry["roughness"])
    diff_roughness = abs(actual_roughness - expected_roughness)
    if diff_roughness > tol:
        return (
            False,
            f"Roughness difiere en {diff_roughness:.4f} (actual={actual_roughness:.4f}, esperado={expected_roughness:.4f}, tol={tol})",
        )

    if "Metallic" not in bsdf.inputs:
        return False, f"El nodo BSDF del material '{mat.name}' no tiene socket 'Metallic'."
    actual_metallic = float(bsdf.inputs["Metallic"].default_value)
    expected_metallic = float(palette_entry["metallic"])
    diff_metallic = abs(actual_metallic - expected_metallic)
    if diff_metallic > tol:
        return (
            False,
            f"Metallic difiere en {diff_metallic:.4f} (actual={actual_metallic:.4f}, esperado={expected_metallic:.4f}, tol={tol})",
        )

    if "alpha" in palette_entry:
        if "Alpha" not in bsdf.inputs:
            return False, f"El nodo BSDF del material '{mat.name}' no tiene socket 'Alpha'."
        actual_alpha = float(bsdf.inputs["Alpha"].default_value)
        expected_alpha = float(palette_entry["alpha"])
        diff_alpha = abs(actual_alpha - expected_alpha)
        if diff_alpha > tol:
            return (
                False,
                f"Alpha difiere en {diff_alpha:.4f} (actual={actual_alpha:.4f}, esperado={expected_alpha:.4f}, tol={tol})",
            )

    return True, "OK"
