shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

/**
 * silhouette.gdshader
 * Silueta del jugador local (#193): se dibuja como material_overlay de sus mallas y solo donde
 * algo opaco está por delante (la profundidad de la pantalla es más cercana que la suya). Así
 * nunca se pierde al personaje detrás de una columna, un mueble alto o una pared sin recortar.
 * Profundidad inversa de Godot 4: más cerca, valor mayor.
 */

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 silhouette_color : source_color = vec4(1.0, 0.243, 0.647, 0.55);
/// Margen para que la propia malla del personaje no cuente como algo delante
uniform float depth_bias = 0.00005;

void fragment() {
	float scene = texture(depth_texture, SCREEN_UV).r;
	if (scene <= FRAGCOORD.z + depth_bias) {
		discard;
	}
	ALBEDO = silhouette_color.rgb;
	ALPHA = silhouette_color.a;
}
