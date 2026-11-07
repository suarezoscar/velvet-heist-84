/**
 * wall_xray_cut.gdshaderinc
 * Recorte de WallXRay (FEAT-034, #109) compartido por wall_xray.gdshader y su contorno
 * (outline.gdshader): lo que queda entre la cámara y el jugador local se recorta con un corte
 * limpio (#191; antes, tramado Bayer 4×4) dentro de una elipse con la silueta del personaje. Qué está «entre» se
 * decide en el plano del suelo, a lo largo de la dirección de la cámara y sin mirar la altura.
 * WallXRay pasa el centro cada frame; con xray_radius = 0 no se recorta nada.
 */

uniform vec3 xray_center = vec3(0.0);
uniform float xray_radius = 0.0;
/// Elipse con la silueta del personaje, en metros de pantalla: medio ancho y media altura
uniform float xray_half_width = 0.6;
uniform float xray_half_height = 1.15;
/// Parte de la franja con el recorte entero; más allá se desvanece hasta el borde
uniform float xray_core : hint_range(0.0, 1.0) = 0.55;
/// Densidad máxima del recorte (1 = agujero completo)
uniform float xray_strength : hint_range(0.0, 1.0) = 0.85;
/// #191: corte limpio; true vuelve a la trama de puntos (Bayer 4×4) de antes
uniform bool xray_dither = false;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

/// true si este píxel (vertex_view: VERTEX en espacio de vista) se recorta
/// ahead_margin: el contorno (malla inflada) lo baja en su grosor para recortarse con la pared
bool xray_discard(
	vec3 vertex_view, mat4 view_matrix, mat4 inv_view_matrix, vec2 frag_coord, float ahead_margin
) {
	if (xray_radius <= 0.0) {
		return false;
	}
	vec3 center = (view_matrix * vec4(xray_center, 1.0)).xyz;
	vec3 world = (inv_view_matrix * vec4(vertex_view, 1.0)).xyz;
	// +Z de la cámara apunta hacia ella; en el suelo, «hacia la cámara» es su parte horizontal
	vec2 toward_camera = normalize(inv_view_matrix[2].xz);
	float ahead = dot(world.xz - xray_center.xz, toward_camera);
	if (ahead <= 0.4 - ahead_margin) {
		return false;
	}
	vec2 off = (vertex_view.xy - center.xy) / vec2(xray_half_width, xray_half_height);
	float cut = (1.0 - smoothstep(xray_core, 1.0, length(off))) * xray_strength;
	if (!xray_dither) {
		return cut > 0.5;
	}
	ivec2 cell = ivec2(frag_coord) % 4;
	return (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0 < cut;
}
