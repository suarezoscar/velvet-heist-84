shader_type spatial;
render_mode cull_disabled;  // #193: la cara interior hace de tapa del corte

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
/// #189: fuerza de los dibujos (rayas, paneles, juntas, remaches); 0 deja el color liso con
/// zócalo y moldura del friso
uniform float pattern_strength : hint_range(0.0, 1.0) = 1.0;

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

/// 0 → 1 al pasar x por edge, fundido en un píxel (fw = fwidth de x): sin dientes que bailen
float over(float x, float edge, float fw) {
	return clamp((x - edge) / max(fw, 1e-5) + 0.5, 0.0, 1.0);
}

/// Cobertura de una línea de ancho w (m) que se repite cada period, suavizada a un píxel;
/// si la línea es más fina que el píxel se aclara en vez de aparecer y desaparecer
float grid_line(float x, float period, float w, float fw) {
	float f = abs(fract(x / period + 0.5) - 0.5) * period;
	float line = clamp((w * 0.5 - f) / max(fw, 1e-5) + 0.5, 0.0, 1.0);
	return line * clamp(w / max(fw, 1e-5), 0.0, 1.0);
}

/// Onda cuadrada (0/1, la mitad de cada period) suavizada a un píxel
float square_wave(float x, float period, float fw) {
	float f = fract(x / period);
	float d = min(abs(f - 0.5), min(f, 1.0 - f)) * period;
	float s = clamp(d / max(fw, 1e-5), 0.0, 1.0);
	float v = step(0.5, f);
	return mix(0.5, v, s);
}

vec3 public_face(float u, float y, vec2 fw, vec3 paint, vec3 dado) {
	// friso: paneles de 0,6 m con marco rehundido
	float px = fract(u / 0.6) * 0.6;
	float inner = over(px, 0.07, fw.x) * (1.0 - over(px, 0.53, fw.x));
	inner *= over(y, 0.26, fw.y) * (1.0 - over(y, 0.88, fw.y));
	float groove = max(grid_line(u, 0.6, 0.025, fw.x), 1.0 - over(y, 0.2, fw.y));
	vec3 dado_c = mix(mix(dado, dado * 1.12, inner), dado * 0.55, groove);
	dado_c = mix(dado, dado_c, pattern_strength);
	// paño: papel pintado a rayas muy suaves
	vec3 paint_c = paint * mix(0.94, 1.04, square_wave(u, 0.3, fw.x));
	paint_c = mix(paint, paint_c, pattern_strength);
	vec3 c = mix(baseboard_color, dado_c, over(y, 0.16, fw.y));
	c = mix(c, rail_color, over(y, 0.98, fw.y));
	return mix(c, paint_c, over(y, 1.06, fw.y));
}

vec3 block_face(float u, float y, vec2 fw, vec3 base, bool stripe) {
	float row = floor(y / 0.4);
	float shift = mod(row, 2.0) * 0.4;
	float joint = max(grid_line(y, 0.4, 0.025, fw.y), grid_line(u + shift, 0.8, 0.025, fw.x));
	vec3 c = mix(base, base * 0.7, joint * pattern_strength);
	if (stripe && pattern_strength > 0.0) {
		float hazard = square_wave(u + y, 0.28, fw.x + fw.y);
		float inner = over(y, 1.03, fw.y) * (1.0 - over(y, 1.11, fw.y));
		vec3 band = mix(stripe_color, stripe_color * 0.25, hazard * inner);
		c = mix(c, band, over(y, 1.0, fw.y) * (1.0 - over(y, 1.14, fw.y)) * pattern_strength);
	}
	return mix(base * 0.45, c, over(y, 0.12, fw.y));
}

vec3 vault_face(float u, float y, vec2 fw, vec3 tint) {
	vec3 base = mix(vault_wall, tint, 0.15);
	float seam = max(grid_line(u, 1.0, 0.05, fw.x), grid_line(y - 0.14, 1.0, 0.05, fw.y));
	vec2 local = vec2(fract(u), fract(y - 0.14));
	vec2 corner = min(local, 1.0 - local);
	float rivet = 1.0 - over(length(corner - vec2(0.1)), 0.045, max(fw.x, fw.y));
	vec3 c = mix(base, base * 0.35, seam * pattern_strength);
	c = mix(c, base * 1.6, rivet * pattern_strength);
	return mix(base * 0.4, c, over(y, 0.14, fw.y));
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
	// derivadas fuera de las ramas (no son fiables dentro de un if por píxel)
	vec2 fw = vec2(fwidth(u), fwidth(y));
	vec3 color;
	float rough = roughness;
	if (n.y > 0.5) {
		color = part == 3 ? partition_cap : cap_color;
	} else if (family < 0.5) {
		color = public_face(u, y, fw, paint, dado);
		if (part == 1) {
			color = baseboard_color;
		} else if (part == 2) {
			color = cornice_color;
		}
	} else if (family < 1.5) {
		color = block_face(u, y, fw, service_wall, true);
		if (part == 2) {
			color = service_wall * 0.85;
		}
	} else if (family < 2.5) {
		color = vault_face(u, y, fw, paint);
		rough = 0.45;
		if (part == 2) {
			color = vault_wall * 0.7;
		}
	} else {
		color = block_face(u, y, fw, exterior_wall, false);
	}
	if (part == 3 && n.y <= 0.5) {
		color = mix(color, partition_cap, over(y, 2.3, fw.y));
	}
	ALBEDO = color;
	ROUGHNESS = rough;
	if (!FRONT_FACING) {  // #193: tapa del corte de las paredes recortadas
		ALBEDO = part == 3 ? partition_cap : cap_color;
		NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	}
	if (xray_discard(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, FRAGCOORD.xy, 0.0)) {
		discard;
	}
}
