shader_type spatial;

/**
 * cel_toon.gdshader
 * Material cel-shading de Velvet Heist '84 (#181, fase 1): luz en tres bandas
 * (cel_light.gdshaderinc), textura de color y mapa de normales opcionales, y luz de borde
 * (Fresnel) para que las siluetas se lean en la oscuridad. CelConverter lo pone en lugar de
 * los StandardMaterial3D del mapa al cargarlo, copiando color, texturas y rugosidad.
 */

#include "res://assets/shaders/cel_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
/// Píxeles duros (texelFetch) en vez de filtrado: para los suelos de baldosas de 2×2
uniform bool texture_nearest = false;
uniform vec2 uv_scale = vec2(1.0);
/// Proyección plana del mundo (XZ) en vez de las UV: suelos
uniform bool world_planar = false;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_map = false;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
/// Máscara de la emisión (los .glb de Mixamo traen emisión blanca con textura negra)
uniform sampler2D emission_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
/// Luz de borde (Fresnel): cian para guardias, magenta para el ladrón; 0 la apaga
uniform vec4 rim_color : source_color = vec4(0.18, 0.95, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.0;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
/// Corte duro del borde (estilo cómic): por debajo no hay borde
uniform float rim_cut : hint_range(0.0, 1.0) = 0.45;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec4 sample_albedo(vec2 uv) {
	if (texture_nearest) {
		ivec2 size = textureSize(albedo_texture, 0);
		ivec2 texel = ivec2(floor(fract(uv) * vec2(size)));
		return texelFetch(albedo_texture, clamp(texel, ivec2(0), size - 1), 0);
	}
	return texture(albedo_texture, uv);
}

void fragment() {
	vec2 uv = (world_planar ? world_pos.xz : UV) * uv_scale;
	vec4 color = albedo * sample_albedo(uv);
	ALBEDO = color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_map, uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float rim = smoothstep(rim_cut - 0.03, rim_cut + 0.03, fresnel) * rim_strength;
	vec3 glow = emission * texture(emission_texture, uv).rgb * emission_energy;
	EMISSION = glow + rim_color.rgb * rim;
}
