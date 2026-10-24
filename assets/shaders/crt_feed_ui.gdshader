shader_type canvas_item;

/**
 * crt_feed_ui.gdshader
 * Versión 2D de crt_security_feed.gdshader para las imágenes de las cámaras CCTV del HUD
 * (interaction.md M2): líneas de barrido, tinte de fósforo, viñeteado, ruido analógico
 * animado y un tinte rojo que pulsa mientras la cámara detecta al ladrón.
 * La señal de entrada es la textura del TextureRect (TEXTURE).
 */

uniform vec4 phosphor_tint : source_color = vec4(0.85, 0.95, 0.85, 1.0);
uniform vec4 alert_tint : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float scanline_density : hint_range(50.0, 400.0) = 180.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float noise_intensity : hint_range(0.0, 0.5) = 0.08;
uniform float noise_speed : hint_range(0.0, 10.0) = 2.5;
uniform float lens_curvature : hint_range(0.0, 0.2) = 0.055;
uniform float vignette_power : hint_range(0.05, 1.0) = 0.25;
uniform float alert_pulse_speed : hint_range(0.0, 30.0) = 10.0;
uniform float alert_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool is_alert_active = false;

float random_noise(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	// Curvatura leve de lente CRT
	vec2 crt_uv = UV * 2.0 - 1.0;
	vec2 offset = crt_uv.yx * lens_curvature;
	crt_uv += crt_uv * offset * offset;
	vec2 uv = crt_uv * 0.5 + 0.5;

	// Muestreo de la señal en directo de la cámara
	vec4 feed_color = texture(TEXTURE, uv);

	// Escala de grises con el tinte de fósforo de seguridad
	float gray = dot(feed_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 base_tone = vec3(gray) * phosphor_tint.rgb;

	// Líneas de barrido horizontales
	float scanline = sin(uv.y * scanline_density * 3.14159) * 0.5 + 0.5;
	base_tone -= base_tone * scanline * scanline_intensity;

	// Ruido estático analógico animado
	vec2 noise_uv = uv + vec2(TIME * noise_speed, TIME * noise_speed * 0.72);
	base_tone += (random_noise(noise_uv) - 0.5) * noise_intensity;

	// Viñeteado de bordes de tubo
	float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
	vignette = clamp(pow(max(16.0 * vignette, 0.0), vignette_power), 0.0, 1.0);
	base_tone *= vignette;

	// Tinte rojo suave que pulsa mientras la cámara ve al ladrón
	if (is_alert_active) {
		float pulse = sin(TIME * alert_pulse_speed) * 0.5 + 0.5;
		vec3 red_tone = alert_tint.rgb * (gray * 1.2 + 0.2) * vignette;
		base_tone = mix(base_tone, red_tone, pulse * alert_strength);
	}

	COLOR = vec4(base_tone, 1.0);
}
