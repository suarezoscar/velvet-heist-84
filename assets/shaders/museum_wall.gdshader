shader_type spatial;

/**
 * museum_wall.gdshader
 * Paredes del kit del museo (#177, fase 2): la misma caja de siempre (colisión, vista y rayos X
 * no cambian) con su acabado dibujado. Cada cara mira el «mapa de salas» un poco por delante de
 * sí para saber a qué sala da, y de ahí su familia:
 * - pública: zócalo, friso de madera en paneles, moldura y paño de color propio de la sala;
 * - servicio: bloque pintado con juntas y una franja de señalización;
 * - cámara: paneles metálicos con remaches;
 * - exterior: bloque oscuro sin franja.
 * La cara de arriba (el corte que ve la cámara isométrica) va en un tono plano.
 * part: 0 muro, 1 zócalo, 2 cornisa, 3 tabique (remate de madera arriba).
 */

#include "res://assets/shaders/cel_light.gdshaderinc"
#include "res://assets/shaders/wall_xray_cut.gdshaderinc"

/// Índice de sala + 1 en el canal rojo (0: fuera de toda sala), una celda por map_cell m
uniform sampler2D room_map : filter_nearest;
/// Una columna por sala (la 0, fuera): fila 0 paño (alfa: familia / 3), fila 1 friso
uniform sampler2D room_finish : source_color, filter_nearest;
uniform vec2 map_origin = vec2(0.0);
uniform float map_cell = 0.25;
uniform int part = 0;
uniform float wall_height = 3.2;
uniform vec3 cap_color : source_color = vec3(0.04, 0.05, 0.1);
uniform vec3 partition_cap : source_color = vec3(0.25, 0.15, 0.09);
uniform vec3 baseboard_color : source_color = vec3(0.12, 0.07, 0.05);
uniform vec3 rail_color : source_color = vec3(0.72, 0.56, 0.24);
uniform vec3 cornice_color : source_color = vec3(0.82, 0.78, 0.68);
uniform vec3 service_wall : source_color = vec3(0.36, 0.4, 0.46);
uniform vec3 stripe_color : source_color = vec3(1.0, 0.71, 0.15);
uniform vec3 vault_wall : source_color = vec3(0.42, 0.45, 0.5);
uniform vec3 exterior_wall : source_color = vec3(0.22, 0.2, 0.26);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

int room_at(vec2 xz) {
	ivec2 size = textureSize(room_map, 0);
	ivec2 cell = ivec2(floor((xz - map_origin) / map_cell));
	if (cell.x < 0 || cell.y < 0 || cell.x >= size.x || cell.y >= size.y) {
		return 0;
	}
	return int(texelFetch(room_map, cell, 0).r * 255.0 + 0.5);
}

/// 1 sobre una línea de ancho w (en metros) que se repite cada period
float grid_line(float x, float period, float w) {
	float f = abs(fract(x / period + 0.5) - 0.5) * period;
	return 1.0 - step(w * 0.5, f);
}

vec3 public_face(float u, float y, vec3 paint, vec3 dado) {
	if (y < 0.16) {
		return baseboard_color;
	}
	if (y < 0.98) {
		// friso: paneles de 0,6 m con marco rehundido
		float px = fract(u / 0.6) * 0.6;
		bool inner = px > 0.07 && px < 0.53 && y > 0.26 && y < 0.88;
		float groove = max(grid_line(u, 0.6, 0.025), 1.0 - step(0.2, y));
		vec3 c = inner ? dado * 1.12 : dado;
		return mix(c, dado * 0.55, groove);
	}
	if (y < 1.06) {
		return rail_color;
	}
	// paño: papel pintado a rayas muy suaves
	float stripe = step(0.5, fract(u / 0.3));
	return paint * mix(0.94, 1.04, stripe);
}

vec3 block_face(float u, float y, vec3 base, bool stripe) {
	if (y < 0.12) {
		return base * 0.45;
	}
	if (stripe && y > 1.0 && y < 1.14) {
		float hazard = step(0.5, fract((u + y) / 0.28));
		return mix(stripe_color, stripe_color * 0.25, hazard * step(1.03, y) * step(y, 1.11));
	}
	float row = floor(y / 0.4);
	float shift = mod(row, 2.0) * 0.4;
	float joint = max(grid_line(y, 0.4, 0.025), grid_line(u + shift, 0.8, 0.025));
	return mix(base, base * 0.7, joint);
}

vec3 vault_face(float u, float y, vec3 tint) {
	vec3 base = mix(vault_wall, tint, 0.15);
	if (y < 0.14) {
		return base * 0.4;
	}
	float seam = max(grid_line(u, 1.0, 0.05), grid_line(y - 0.14, 1.0, 0.05));
	vec2 local = vec2(fract(u), fract(y - 0.14));
	vec2 corner = min(local, 1.0 - local);
	float rivet = 1.0 - step(0.045, length(corner - vec2(0.1)));
	vec3 c = mix(base, base * 0.35, seam);
	return mix(c, base * 1.6, rivet);
}

void fragment() {
	vec3 n = normalize(world_normal);
	int room = room_at(world_pos.xz + n.xz * 0.3);
	vec4 head = texelFetch(room_finish, ivec2(room, 0), 0);
	vec3 paint = head.rgb;
	vec3 dado = texelFetch(room_finish, ivec2(room, 1), 0).rgb;
	float family = head.a * 3.0;
	vec2 tangent = vec2(-n.z, n.x);
	float u = dot(world_pos.xz, tangent);
	float y = world_pos.y;
	vec3 color;
	float rough = roughness;
	if (n.y > 0.5) {
		color = part == 3 ? partition_cap : cap_color;
	} else if (family < 0.5) {
		color = public_face(u, y, paint, dado);
		if (part == 1) {
			color = baseboard_color;
		} else if (part == 2) {
			color = cornice_color;
		}
	} else if (family < 1.5) {
		color = block_face(u, y, service_wall, true);
		if (part == 2) {
			color = service_wall * 0.85;
		}
	} else if (family < 2.5) {
		color = vault_face(u, y, paint);
		rough = 0.45;
		if (part == 2) {
			color = vault_wall * 0.7;
		}
	} else {
		color = block_face(u, y, exterior_wall, false);
	}
	if (part == 3 && y > 2.3 && n.y <= 0.5) {
		color = partition_cap;
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	if (xray_discard(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, FRAGCOORD.xy, 0.0)) {
		discard;
	}
}
