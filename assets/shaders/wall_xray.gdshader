shader_type spatial;

/**
 * wall_xray.gdshader
 * Paredes del museo (FEAT-034): opacas, salvo las que quedan entre la cámara y el jugador
 * local. Qué está «entre» se decide en el plano del suelo, a lo largo de la dirección de la
 * cámara y sin mirar la altura: así la parte alta de una pared a tu espalda no se corta (#109).
 * Esas se recortan con un tramado ordenado (Bayer 4×4, retro) dentro de un radio en el
 * plano de la pantalla alrededor del jugador, para verle detrás. WallXRay pasa el centro cada
 * frame; con xray_radius = 0 no se recorta nada (servidor, menú o sin jugador local).
 */

uniform vec4 albedo : source_color = vec4(0.62, 0.6, 0.58, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform vec3 xray_center = vec3(0.0);
uniform float xray_radius = 0.0;
/// Parte del radio con el recorte entero; más allá se desvanece hasta el borde
uniform float xray_core : hint_range(0.0, 1.0) = 0.55;
/// Densidad máxima del recorte (1 = agujero completo)
uniform float xray_strength : hint_range(0.0, 1.0) = 0.85;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	if (xray_radius > 0.0) {
		vec3 center = (VIEW_MATRIX * vec4(xray_center, 1.0)).xyz;
		vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		// +Z de la cámara apunta hacia ella; en el suelo, «hacia la cámara» es su parte horizontal
		vec2 toward_camera = normalize(INV_VIEW_MATRIX[2].xz);
		float ahead = dot(world.xz - xray_center.xz, toward_camera);
		if (ahead > 0.4) {
			float d = length(VERTEX.xy - center.xy);
			float cut = (1.0 - smoothstep(xray_radius * xray_core, xray_radius, d)) * xray_strength;
			ivec2 cell = ivec2(FRAGCOORD.xy) % 4;
			float threshold = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
			if (threshold < cut) {
				discard;
			}
		}
	}
}
