shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

/**
 * outline.gdshader
 * Contorno negro de cómic (#181, fase 1) por malla invertida: se dibuja como next_pass la
 * misma malla inflada a lo largo de sus normales y solo con las caras traseras. El grosor crece
 * con la distancia a la cámara para que en pantalla sea casi constante. Las cajas (muros,
 * bancos) tienen normales planas y se abrirían por las esquinas: en box_mode cada vértice sale
 * hacia su esquina (signo de su posición) y la caja inflada queda cerrada. Con el recorte de
 * WallXRay (los muros lo comparten) el contorno se recorta igual que la pared.
 */

#include "res://assets/shaders/wall_xray_cut.gdshaderinc"

uniform vec4 outline_color : source_color = vec4(0.02, 0.01, 0.04, 1.0);
/// Grosor en metros a 25 m de la cámara (la distancia del encuadre del mapa)
uniform float outline_width : hint_range(0.0, 0.2) = 0.05;
/// Cajas centradas en su origen (BoxMesh): inflar hacia las esquinas en vez de por la normal
uniform bool box_mode = false;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float width = outline_width * length(CAMERA_POSITION_WORLD - world) / 25.0;
	vec3 axis_scale = vec3(
		length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)
	);
	vec3 dir = box_mode ? sign(VERTEX) : normalize(NORMAL);
	if (box_mode) {
		dir.y = max(dir.y, 0.0);  // hacia abajo atravesaría el suelo y le sacaría dientes
	}
	VERTEX += dir * width / max(axis_scale, vec3(0.0001));
}

void fragment() {
	ALBEDO = outline_color.rgb;
	if (xray_discard(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
}
