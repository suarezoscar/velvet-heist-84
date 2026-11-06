shader_type sky;

/**
 * night_sky.gdshader
 * Cielo nocturno synthwave de 1984 (#181, fase 1), sin texturas: degradado cobalto a morado,
 * nubes de cómic posterizadas en dos tonos, resplandor de neón magenta y cian en el horizonte,
 * silueta de ciudad con ventanas y una luna de borde duro hacia la luz direccional 0. Todo
 * procedural: no hay .hdr ni licencia que registrar. Resplandor y luna en HDR real (más de 1)
 * para los reflejos del cielo en suelos y vitrinas; el cenit sigue oscuro. La luz ambiente no
 * sale de aquí (es plana, para que la banda de sombra del cel-shading sea uniforme). Colores de NightLook (art_style.md).
 */

uniform vec3 top_color : source_color = vec3(0.043, 0.055, 0.102);
uniform vec3 mid_color : source_color = vec3(0.106, 0.129, 0.251);
uniform vec3 low_color : source_color = vec3(0.227, 0.18, 0.31);
uniform vec3 glow_magenta : source_color = vec3(1.0, 0.243, 0.647);
uniform vec3 glow_cyan : source_color = vec3(0.18, 0.95, 1.0);
/// Energía HDR del resplandor (más de 1: tiñe los reflejos del suelo y lo recoge el glow)
uniform float glow_energy : hint_range(0.0, 8.0) = 3.0;
uniform vec3 cloud_dark : source_color = vec3(0.16, 0.12, 0.27);
uniform vec3 cloud_lit : source_color = vec3(0.29, 0.33, 0.56);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform vec3 city_color : source_color = vec3(0.02, 0.02, 0.05);
uniform vec3 window_color : source_color = vec3(1.0, 0.714, 0.153);
uniform vec3 moon_color : source_color = vec3(0.92, 0.9, 1.0);
uniform float moon_size : hint_range(0.0, 0.2) = 0.045;
uniform float moon_energy : hint_range(0.0, 8.0) = 2.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return value;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	float azimuth = atan(dir.x, dir.z);
	// Degradado del cielo: cobalto arriba, morado abajo
	vec3 color = mix(mid_color, top_color, smoothstep(0.1, 0.7, h));
	color = mix(low_color, color, smoothstep(-0.02, 0.18, h));
	// Resplandor de neón en el horizonte, en bandas limpias (magenta pegado, cian encima)
	float band = 1.0 - smoothstep(0.0, 0.16, abs(h - 0.02));
	vec3 glow = mix(glow_magenta, glow_cyan, smoothstep(0.02, 0.12, h));
	color += glow * floor(band * 4.0) / 4.0 * glow_energy;
	// Estrellas
	vec2 star_cell = floor(vec2(azimuth * 120.0, h * 120.0));
	float star = step(1.0 - star_density * 0.02, hash(star_cell)) * smoothstep(0.2, 0.5, h);
	color += vec3(star);
	// Nubes de cómic: dos tonos con corte duro, más densas cerca del horizonte
	if (h > 0.0) {
		vec2 cloud_uv = dir.xz / (h + 0.25) * 1.6 + vec2(TIME * 0.004, 0.0);
		float c = fbm(cloud_uv) * smoothstep(0.0, 0.25, h) * (1.0 - smoothstep(0.5, 0.9, h));
		float cut = 1.0 - cloud_cover * 0.6;
		float body = step(cut * 0.55, c);
		float lit = step(cut * 0.55 + 0.06, c + fbm(cloud_uv + vec2(0.3, 0.2)) * 0.08);
		color = mix(color, mix(cloud_dark, cloud_lit, lit), body);
	}
	// Luna de borde duro hacia la luz direccional 0
	if (LIGHT0_ENABLED) {
		float moon = step(1.0 - moon_size * moon_size, dot(dir, LIGHT0_DIRECTION));
		color = mix(color, moon_color * moon_energy, moon);
	}
	// Silueta de ciudad: edificios escalonados por azimut con ventanas
	float column = floor(azimuth * 60.0);
	float building = 0.015 + hash(vec2(column, 3.1)) * 0.07 * step(0.25, hash(vec2(column, 7.7)));
	if (h < building) {
		vec2 window = floor(vec2(azimuth * 360.0, h * 260.0));
		float lit_window = step(0.82, hash(window)) * step(0.004, h) * step(h, building - 0.006);
		color = mix(city_color, window_color, lit_window);
	}
	if (h < 0.0) {
		color = city_color;
	}
	COLOR = color;
}
