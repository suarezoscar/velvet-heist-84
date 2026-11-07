shader_type spatial;

/**
 * museum_floor.gdshader
 * Suelos del kit del museo (#177, fase 2), dibujados sin texturas según la superficie de la
 * sala en el JSON del nivel (pattern):
 * 0 mármol: ajedrezado con vetas suaves · 1 parqué en espiga · 2 moqueta con dibujo ochentero
 * 3 vinilo: baldosa con franja de señalización junto a las paredes · 4 asfalto con manchas.
 * room_rect (mín x, mín z, máx x, máx z en mundo) sirve para la cenefa y la franja.
 */

#include "res://assets/shaders/cel_light.gdshaderinc"

uniform int pattern = 0;
uniform vec3 color_a : source_color = vec3(0.8);
uniform vec3 color_b : source_color = vec3(0.4);
uniform vec3 color_c : source_color = vec3(1.0, 0.24, 0.65);
uniform vec4 room_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/// 0 → 1 al pasar x por edge, fundido en un píxel (fw = fwidth de x)
float over(float x, float edge, float fw) {
	return clamp((x - edge) / max(fw, 1e-5) + 0.5, 0.0, 1.0);
}

/// Cobertura de una línea de ancho w cada period, suavizada a un píxel (y más tenue si es
/// más fina que el píxel, para que no aparezca y desaparezca al moverse)
float grid_line(float x, float period, float w, float fw) {
	float f = abs(fract(x / period + 0.5) - 0.5) * period;
	float line = clamp((w * 0.5 - f) / max(fw, 1e-5) + 0.5, 0.0, 1.0);
	return line * clamp(w / max(fw, 1e-5), 0.0, 1.0);
}

/// Onda cuadrada (0/1, la mitad de cada period) suavizada a un píxel
float square_wave(float x, float period, float fw) {
	float f = fract(x / period);
	float d = min(abs(f - 0.5), min(f, 1.0 - f)) * period;
	return mix(0.5, step(0.5, f), clamp(d / max(fw, 1e-5), 0.0, 1.0));
}

/// Ajedrezado de celdas de lado cell, suavizado (0 claro, 1 oscuro)
float checker(vec2 p, float cell, vec2 fw) {
	float sx = square_wave(p.x, cell * 2.0, fw.x);
	float sy = square_wave(p.y, cell * 2.0, fw.y);
	return sx + sy - 2.0 * sx * sy;
}

vec3 marble(vec2 p, vec2 fw) {
	vec3 base = mix(color_a, color_b, checker(p, 1.0, fw));
	float vein = abs(sin(p.x * 2.3 + p.y * 1.1 + noise(p * 2.5) * 5.0));
	base *= mix(0.9, 1.0, smoothstep(0.0, 0.12, vein));
	float joint = max(grid_line(p.x, 1.0, 0.02, fw.x), grid_line(p.y, 1.0, 0.02, fw.y));
	return mix(base, base * 0.6, joint);
}

/// Espiga: celdas de una tabla horizontal (n×1) y una vertical (1×n), red (1,1) y (n,-n)
vec3 parquet(vec2 world, float fw) {
	float w = 0.18;
	float n = 4.0;
	vec2 p = world / w;
	float fwn = fw / w;
	float s0 = floor((p.x + p.y) * 0.5);
	float t0 = floor((p.x - p.y) / (2.0 * n));
	for (int i = -3; i <= 0; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 k = vec2(s0 + float(i), t0 + float(j));
			vec2 o = vec2(k.x + k.y * n, k.x - k.y * n);
			vec2 h = p - o;
			vec2 v = p - o - vec2(0.0, 1.0);
			bool in_h = h.x >= 0.0 && h.x < n && h.y >= 0.0 && h.y < 1.0;
			bool in_v = v.x >= 0.0 && v.x < 1.0 && v.y >= 0.0 && v.y < n;
			if (in_h || in_v) {
				vec2 l = in_h ? h : v.yx;
				float edge = min(min(l.x, n - l.x), min(l.y, 1.0 - l.y));
				float tone = hash(k + (in_h ? 0.0 : 17.0));
				// el tono de la tabla se acerca a la media cuando las tablas son de pocos píxeles
				tone = mix(tone, 0.5, clamp(fwn * 4.0 - 0.5, 0.0, 1.0));
				vec3 c = mix(color_a, color_b, tone);
				float gap = clamp((0.05 - edge) / max(fwn, 1e-5) + 0.5, 0.0, 1.0);
				gap *= clamp(0.1 / max(fwn, 1e-5), 0.0, 1.0);
				return mix(c, c * 0.55, gap);
			}
		}
	}
	return color_a;
}

vec3 carpet(vec2 p, float border, vec2 fw) {
	float fb = max(fw.x, fw.y);
	vec2 q = fract(p / 0.7) - 0.5;
	float diamond = abs(q.x) + abs(q.y);
	float fd = (fw.x + fw.y) / 0.7;
	vec3 c = color_a;
	c = mix(c, color_b, 1.0 - over(abs(diamond - 0.32), 0.035, fd));
	c = mix(c, color_c * 0.6, 1.0 - over(diamond, 0.06, fd));
	float inner_band = over(border, 0.12, fb) * (1.0 - over(border, 0.2, fb));
	vec3 edge_c = mix(color_b, color_c * 0.7, inner_band);
	return mix(edge_c, c, over(border, 0.45, fb));
}

vec3 linoleum(vec2 p, float border, vec2 fw) {
	vec2 cell = floor(p / 0.5);
	vec3 c = mix(color_a, color_b, checker(p, 0.5, fw));
	c *= mix(0.95, 1.03, hash(cell));
	float joint = max(grid_line(p.x, 0.5, 0.015, fw.x), grid_line(p.y, 0.5, 0.015, fw.y));
	c = mix(c, c * 0.75, joint);
	float fb = max(fw.x, fw.y);
	return mix(c, color_c, over(border, 0.3, fb) * (1.0 - over(border, 0.42, fb)));
}

vec3 asphalt(vec2 p, float fw) {
	// grano suave que se apaga cuando es más fino que el píxel (antes chisporroteaba)
	float grain = mix(noise(p * 40.0), 0.5, clamp(fw * 40.0 - 0.5, 0.0, 1.0));
	float patch = smoothstep(0.55, 0.7, noise(p * 0.6));
	vec3 c = color_a * mix(0.85, 1.1, grain);
	return mix(c, color_b, patch * 0.6);
}

void fragment() {
	vec2 p = world_pos.xz;
	float border = min(
		min(p.x - room_rect.x, room_rect.z - p.x), min(p.y - room_rect.y, room_rect.w - p.y)
	);
	// derivadas fuera de las ramas (no son fiables dentro de un if por píxel)
	vec2 fw = fwidth(p);
	vec3 color;
	if (pattern == 0) {
		color = marble(p, fw);
	} else if (pattern == 1) {
		color = parquet(p, max(fw.x, fw.y));
	} else if (pattern == 2) {
		color = carpet(p, border, fw);
	} else if (pattern == 3) {
		color = linoleum(p, border, fw);
	} else {
		color = asphalt(p, max(fw.x, fw.y));
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
}
