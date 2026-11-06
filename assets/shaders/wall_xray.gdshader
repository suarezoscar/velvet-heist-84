shader_type spatial;

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

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	if (xray_discard(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, FRAGCOORD.xy, 0.0)) {
		discard;
	}
}
