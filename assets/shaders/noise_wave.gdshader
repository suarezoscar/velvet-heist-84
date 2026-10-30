shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled;

/**
 * noise_wave.gdshader
 * Minionda de ruido (#114): dos anillos finos y ondulados que se abren desde el centro y se
 * desvanecen. Semitransparente y de color apagado; NoiseWave3D anima `progress` de 0 a 1.
 */

uniform vec4 tint : source_color = vec4(0.78, 0.82, 0.86, 1.0);
/// Avance de la onda: 0 al nacer, 1 al desaparecer
uniform float progress : hint_range(0.0, 1.0) = 0.0;
/// Opacidad máxima (al principio)
uniform float max_alpha : hint_range(0.0, 1.0) = 0.55;
/// Grosor de cada anillo, en fracción del radio
uniform float ring_width : hint_range(0.01, 0.5) = 0.07;
/// Retraso del segundo anillo respecto al primero
uniform float second_lag : hint_range(0.0, 1.0) = 0.35;
/// Ondulación: cuántas crestas por vuelta y cuánto se deforma el anillo
uniform float wobble_count = 7.0;
uniform float wobble_amount : hint_range(0.0, 0.2) = 0.045;

float ring(float r, float at) {
	float d = abs(r - at);
	return 1.0 - smoothstep(ring_width * 0.35, ring_width, d);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float wobble = sin(a * wobble_count + progress * 9.0) * wobble_amount;
	float first = ring(r + wobble, progress);
	float second = ring(r - wobble, max(progress - second_lag, 0.0)) * step(second_lag, progress);
	float fade = 1.0 - smoothstep(0.35, 1.0, progress);
	ALBEDO = tint.rgb;
	ALPHA = clamp(first + second * 0.6, 0.0, 1.0) * fade * max_alpha * step(r, 1.0);
}
