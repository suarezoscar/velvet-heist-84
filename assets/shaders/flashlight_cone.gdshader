shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

/**
 * flashlight_cone.gdshader
 * Haz de la linterna de los guardias (#191): un cono que suma un poco de luz, más fuerte junto
 * a la linterna y en el eje, y que se apaga hacia la punta y los bordes. Sustituye a la niebla
 * volumétrica, que ensuciaba toda la pantalla para dibujar solo el haz.
 * UV.y va de 0 (junto a la linterna) a 1 (punta del haz).
 */

uniform vec3 beam_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float beam_alpha : hint_range(0.0, 1.0) = 0.015;

void fragment() {
	float along = pow(1.0 - clamp(UV.y, 0.0, 1.0), 1.5);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = beam_color;
	ALPHA = beam_alpha * along * facing;
}
