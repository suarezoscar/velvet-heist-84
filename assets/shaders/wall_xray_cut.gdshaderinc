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

/// #193 paredes recortadas por sala: lo que cae en la franja de una sala (desde su lado
/// lejano a la cámara hasta cut_front m por delante) se corta a cut_height m. Dos salas para el
/// fundido al cambiar: la que entra (a) y la que sale (b), con su avance de 0 a 1
uniform vec4 cut_rect_a = vec4(0.0);
uniform float cut_amount_a = 0.0;
uniform vec4 cut_rect_b = vec4(0.0);
uniform float cut_amount_b = 0.0;
uniform float cut_height = 1.0;
uniform float cut_top = 3.3;
uniform float cut_back = 0.2;
uniform float cut_front = 4.5;
/// false (muebles, columnas, piezas del kit): solo se cortan en la franja de las paredes de
/// delante y más allá, no en el interior de la sala
uniform bool cut_interior = true;
/// Anchura (m) de esa franja, desde el borde delantero de la sala hacia dentro
uniform float cut_band = 0.45;

bool in_cut(vec3 world, vec4 r) {
	bool inside = world.x > r.x + cut_back && world.x < r.z + cut_front
			&& world.z > r.y + cut_back && world.z < r.w + cut_front;
	if (!inside || cut_interior) {
		return inside;
	}
	return world.x > r.z - cut_band || world.z > r.w - cut_band;
}

/// Altura a la que se corta este punto del mundo (cut_top si no se corta)
float cutaway_height(vec3 world) {
	float h = cut_top;
	if (cut_amount_a > 0.0 && in_cut(world, cut_rect_a)) {
		h = min(h, mix(cut_top, cut_height, cut_amount_a));
	}
	if (cut_amount_b > 0.0 && in_cut(world, cut_rect_b)) {
		h = min(h, mix(cut_top, cut_height, cut_amount_b));
	}
	return h;
}

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

/// true si este píxel (vertex_view: VERTEX en espacio de vista) se recorta
/// ahead_margin: el contorno (malla inflada) lo baja en su grosor para recortarse con la pared
bool xray_discard(
	vec3 vertex_view, mat4 view_matrix, mat4 inv_view_matrix, vec2 frag_coord, float ahead_margin
) {
	vec3 world = (inv_view_matrix * vec4(vertex_view, 1.0)).xyz;
	if (world.y > cutaway_height(world)) {
		return true;
	}
	if (xray_radius <= 0.0) {
		return false;
	}
	vec3 center = (view_matrix * vec4(xray_center, 1.0)).xyz;
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
