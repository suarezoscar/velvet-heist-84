shader_type spatial;
render_mode unshaded;

/**
 * crt_security_feed.gdshader
 * Simula la pantalla de un monitor de tubo de rayos catódicos (CRT) de 1984.
 * Añade líneas de escaneo analógicas (scanlines), tinte de fósforo y viñeteado.
 */

uniform sampler2D camera_feed : source_color, filter_linear_mipmap;
uniform vec4 phosphor_tint : source_color = vec4(0.85, 0.95, 0.85, 1.0);
uniform float scanline_density : hint_range(50.0, 400.0) = 180.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float noise_intensity : hint_range(0.0, 0.5) = 0.08;
uniform bool is_alert_active = false;

float random_noise(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;

	// Curvatura leve de lente CRT
	vec2 crt_uv = uv * 2.0 - 1.0;
	vec2 offset = crt_uv.yx / 18.0;
	crt_uv += crt_uv * offset * offset;
	uv = crt_uv * 0.5 + 0.5;

	// Muestreo de la señal en directo de la cámara
	vec4 feed_color = texture(camera_feed, uv);

	// Conversión a escala de grises / fósforo de seguridad ochentero
	float gray = dot(feed_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 base_tone = vec3(gray) * phosphor_tint.rgb;

	// Líneas de escaneo horizontales (Scanlines)
	float scanline = sin(uv.y * scanline_density * 3.14159) * 0.5 + 0.5;
	base_tone -= base_tone * scanline * scanline_intensity;

	// Ruido estático analógico leve
	float noise = (random_noise(uv + vec2(TIME * 2.5, TIME * 1.8)) - 0.5) * noise_intensity;
	base_tone += noise;

	// Viñeteado de bordes de tubo
	float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
	vignette = clamp(pow(16.0 * vignette, 0.25), 0.0, 1.0);
	base_tone *= vignette;

	// Parpadeo de alerta roja en caso de intrusión detectada
	if (is_alert_active) {
		float alert_pulse = sin(TIME * 10.0) * 0.5 + 0.5;
		base_tone = mix(base_tone, vec3(1.0, 0.15, 0.1) * (gray * 1.5 + 0.3), alert_pulse * 0.7);
	}

	ALBEDO = base_tone;
}
