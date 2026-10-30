shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled;

/**
 * noise_wave.gdshader
 * Minionda de ruido (#114) con aspecto de gota en el agua: varias circunferencias concéntricas
 * que se abren desde el centro, cada una con una cresta clara y una sombra suave por dentro, y
 * un punto que brilla al principio. NoiseWave3D anima `progress` de 0 a 1.
 */

uniform vec4 crest_color : source_color = vec4(0.92, 0.94, 0.96, 1.0);
uniform vec4 trough_color : source_color = vec4(0.35, 0.38, 0.42, 1.0);
/// Avance de la onda: 0 al nacer, 1 al desaparecer
uniform float progress : hint_range(0.0, 1.0) = 0.0;
/// Opacidad máxima de una cresta
uniform float max_alpha : hint_range(0.0, 1.0) = 0.6;
/// Circunferencias y separación entre ellas (en fracción del radio)
uniform int ring_count : hint_range(1, 6) = 3;
uniform float ring_spacing : hint_range(0.0, 0.5) = 0.2;
/// Grosor de cada cresta (en fracción del radio)
uniform float ring_width : hint_range(0.005, 0.2) = 0.035;
/// Cuánto pesa la sombra junto a cada cresta
uniform float trough_strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float crest = 0.0;
	float trough = 0.0;
	for (int i = 0; i < ring_count; i++) {
		float at = progress - float(i) * ring_spacing;
		if (at <= 0.0) {
			continue;
		}
		float weight = 1.0 - float(i) / float(ring_count);
		float d = (r - at) / ring_width;
		crest += exp(-d * d) * weight;
		float dt = d + 1.6;
		trough += exp(-dt * dt) * weight;
	}
	float dot_glow = exp(-pow(r / 0.07, 2.0)) * pow(1.0 - progress, 3.0);
	crest += dot_glow;
	float fade = 1.0 - smoothstep(0.3, 1.0, progress);
	float total = crest + trough * trough_strength;
	ALBEDO = mix(trough_color.rgb, crest_color.rgb, clamp(crest / max(total, 0.0001), 0.0, 1.0));
	ALPHA = clamp(total, 0.0, 1.0) * fade * max_alpha * step(r, 1.0);
}
