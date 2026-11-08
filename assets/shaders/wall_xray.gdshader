shader_type spatial;
render_mode cull_disabled;  // #193: la cara interior hace de tapa del corte

/**
 * wall_xray.gdshader
 * Paredes del museo (FEAT-034): opacas, salvo lo que queda entre la cámara y el jugador local,
 * que se recorta con wall_xray_cut.gdshaderinc. #181: con la luz cel-shading de
 * cel_light.gdshaderinc, como el resto del mapa.
 */

#include "res://assets/shaders/cel_light.gdshaderinc"
#include "res://assets/shaders/wall_xray_cut.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.62, 0.6, 0.58, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
/// Tapa del corte (#193): lo que se ve por dentro de una pared recortada
uniform vec3 cut_cap_color : source_color = vec3(0.04, 0.05, 0.1);

void fragment() {
	ALBEDO = albedo.rgb;
	if (!FRONT_FACING) {
		ALBEDO = cut_cap_color;
		NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	}
	ROUGHNESS = roughness;
	if (xray_discard(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, FRAGCOORD.xy, 0.0)) {
		discard;
	}
}
