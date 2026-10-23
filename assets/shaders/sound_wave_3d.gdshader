shader_type spatial;
render_mode unshaded, depth_test_disabled, blend_mix, cull_disabled;

uniform int category_mode = 0; // 0: continuo, 1: doble, 2: discontinuo
uniform float stroke_px = 2.0;
uniform float glow_px = 4.0;
uniform vec4 color : source_color = vec4(0.94902, 0.721569, 0.294118, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.45;
uniform float glow_alpha : hint_range(0.0, 1.0) = 0.15;
uniform float double_gap_px = 4.0;
uniform int dash_segments = 24;
uniform float current_radius_m = 0.0;
uniform float mesh_size = 1.0;

void fragment() {
	if (current_radius_m <= 0.0001) {
		ALBEDO = color.rgb;
		ALPHA = 0.0;
	} else {
		// Coordenadas locales en metros respecto al centro del quad
		vec2 pos_m = (UV - vec2(0.5)) * mesh_size;
		float dist_m = length(pos_m);

		// Derivada de distancia en metros por píxel en pantalla
		float px_size = max(fwidth(dist_m), 0.0001);
		float dist_from_ring_m = dist_m - current_radius_m;
		float dist_px = dist_from_ring_m / px_size;

		float d_stroke = abs(dist_px);
		if (category_mode == 1) {
			// Anillo doble: dos trazos de stroke_px separados por double_gap_px
			float offset_px = 0.5 * (stroke_px + double_gap_px);
			d_stroke = abs(abs(dist_px) - offset_px);
		}

		float half_stroke = stroke_px * 0.5;
		float d_glow = max(0.0, d_stroke - half_stroke);

		// Halo de fósforo cae de glow_alpha a 0 en glow_px
		float glow = clamp(1.0 - (d_glow / max(glow_px, 0.0001)), 0.0, 1.0) * glow_alpha;

		// Trazo suavizado en los bordes
		float stroke_mask = clamp(0.5 + half_stroke - d_stroke, 0.0, 1.0);
		float computed_alpha = mix(glow, alpha, stroke_mask);

		if (category_mode == 2) {
			// Anillo discontinuo: 24 segmentos, mitad visible
			float angle = atan(pos_m.y, pos_m.x);
			float c = cos(float(dash_segments) * angle);
			float dash_mask = clamp(c / max(fwidth(c), 0.001) + 0.5, 0.0, 1.0);
			computed_alpha *= dash_mask;
		}

		ALBEDO = color.rgb;
		ALPHA = computed_alpha * color.a;
	}
}
