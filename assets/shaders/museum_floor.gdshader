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

float grid_line(float x, float period, float w) {
	float f = abs(fract(x / period + 0.5) - 0.5) * period;
	return 1.0 - step(w * 0.5, f);
}

vec3 marble(vec2 p) {
	vec2 cell = floor(p);
	bool dark = mod(cell.x + cell.y, 2.0) > 0.5;
	vec3 base = dark ? color_b : color_a;
	float vein = abs(sin(p.x * 2.3 + p.y * 1.1 + noise(p * 2.5) * 5.0));
	base *= mix(0.9, 1.0, smoothstep(0.0, 0.12, vein));
	float joint = max(grid_line(p.x, 1.0, 0.02), grid_line(p.y, 1.0, 0.02));
	return mix(base, base * 0.6, joint);
}

/// Espiga: celdas de una tabla horizontal (n×1) y una vertical (1×n), red (1,1) y (n,-n)
vec3 parquet(vec2 world) {
	float w = 0.18;
	float n = 4.0;
	vec2 p = world / w;
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
				vec3 c = mix(color_a, color_b, tone);
				return mix(c * 0.55, c, smoothstep(0.03, 0.08, edge));
			}
		}
	}
	return color_a;
}

vec3 carpet(vec2 p, float border) {
	if (border < 0.45) {
		return border > 0.12 && border < 0.2 ? color_c * 0.7 : color_b;
	}
	vec2 q = fract(p / 0.7) - 0.5;
	float diamond = abs(q.x) + abs(q.y);
	vec3 c = color_a;
	c = mix(c, color_b, 1.0 - step(0.035, abs(diamond - 0.32)));
	c = mix(c, color_c * 0.6, 1.0 - step(0.06, diamond));
	return c;
}

vec3 linoleum(vec2 p, float border) {
	vec2 cell = floor(p / 0.5);
	bool alt = mod(cell.x + cell.y, 2.0) > 0.5;
	vec3 c = alt ? color_b : color_a;
	c *= mix(0.95, 1.03, hash(cell));
	if (border > 0.3 && border < 0.42) {
		return color_c;
	}
	float joint = max(grid_line(p.x, 0.5, 0.015), grid_line(p.y, 0.5, 0.015));
	return mix(c, c * 0.75, joint);
}

vec3 asphalt(vec2 p) {
	float grain = hash(floor(p * 40.0));
	float patch = smoothstep(0.55, 0.7, noise(p * 0.6));
	vec3 c = color_a * mix(0.85, 1.1, grain);
	return mix(c, color_b, patch * 0.6);
}

void fragment() {
	vec2 p = world_pos.xz;
	float border = min(
		min(p.x - room_rect.x, room_rect.z - p.x), min(p.y - room_rect.y, room_rect.w - p.y)
	);
	vec3 color;
	if (pattern == 0) {
		color = marble(p);
	} else if (pattern == 1) {
		color = parquet(p);
	} else if (pattern == 2) {
		color = carpet(p, border);
	} else if (pattern == 3) {
		color = linoleum(p, border);
	} else {
		color = asphalt(p);
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
}
