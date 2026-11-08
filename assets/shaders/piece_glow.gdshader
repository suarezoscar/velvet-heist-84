shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

/**
 * piece_glow.gdshader
 * Brillo ligero de las piezas del botín (#194): capa (material_overlay) que suma un filo de luz
 * fría en el contorno y un poco de luz en toda la pieza. Va pegada al modelo, así que sigue la
 * memoria de la niebla: una pieza robada fuera de la vista sigue brillando como se recuerda.
 */

uniform vec3 glow_color : source_color = vec3(0.8, 0.9, 1.0);
/// Luz en toda la pieza
uniform float glow_base : hint_range(0.0, 1.0) = 0.06;
/// Filo en el contorno (Fresnel)
uniform float glow_rim : hint_range(0.0, 2.0) = 0.5;
uniform float glow_power : hint_range(0.5, 8.0) = 2.5;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), glow_power);
	ALBEDO = glow_color;
	ALPHA = clamp(glow_base + fresnel * glow_rim, 0.0, 1.0);
}
