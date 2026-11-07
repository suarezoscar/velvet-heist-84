shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

/**
 * fog_of_war.gdshader
 * Niebla de guerra de la vista principal (vision.md R1-R2). Malla de pantalla completa que
 * reconstruye la posición de cada píxel desde la profundidad y la compara con la zona visible
 * del jugador local, dada como distancia por ángulo alrededor de sus ojos (polígono en estrella
 * que calcula FogOfWar3D). Fuera de la zona, el museo se dibuja como un plano (#186): dos tintas
 * azules según la luz del píxel, la del suelo y la de lo que se alza de él (más de raised_from
 * m, del todo desde raised_to; #163), con el contorno de la geometría en claro. Las luces
 * (pilotos, bombillas) atraviesan la niebla: el píxel cuyo canal más alto pasa de light_keep
 * se ve tal cual (vision.md D5). El borde es corto en el suelo y más ancho en lo alzado, para
 * que no barra las paredes al andar (#161, #163).
 */

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;
uniform float distances[256];
uniform int ray_count = 256;
uniform vec2 eye_xz = vec2(0.0);
uniform float view_radius = 18.0;
/// Anchura (m) del borde entre lo visible y la niebla: en el suelo y en lo alzado
uniform float edge_feather = 0.4;
uniform float raised_feather = 1.5;
uniform float light_keep = 0.9;
uniform float raised_from = 0.08;
uniform float raised_to = 0.2;
/// Tintas del plano: de la sombra a la luz, para el suelo y para lo alzado
uniform vec3 ink_floor_dark : source_color = vec3(0.02, 0.035, 0.09);
uniform vec3 ink_floor_light : source_color = vec3(0.07, 0.13, 0.27);
uniform vec3 ink_raised_dark : source_color = vec3(0.06, 0.1, 0.22);
uniform vec3 ink_raised_light : source_color = vec3(0.2, 0.32, 0.58);
uniform vec3 ink_line : source_color = vec3(0.55, 0.75, 1.0);
uniform float line_strength : hint_range(0.0, 1.0) = 0.2;
/// Sin contorno a menos de esta distancia (m) de los ojos: allí el tramado de rayos X del
/// personaje deja huecos que se dibujarían como puntitos
uniform float line_clear_near = 2.0;
/// #189: contorno solo por encima de esta altura (m): con 2 m, solo muros y tabiques
uniform float line_min_height = -100.0;

/// Distancia a la cámara del píxel en uv (espacio de vista)
float view_depth(vec2 uv, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, texture(depth_texture, uv).x, 1.0);
	return -v.z / v.w;
}

/// Contorno del plano en un píxel: saltos de profundidad y cambios de normal con sus vecinos
float plan_edge(vec2 uv, vec2 px, mat4 inv_proj) {
	float c = view_depth(uv, inv_proj);
	float l = view_depth(uv - vec2(px.x, 0.0), inv_proj);
	float r = view_depth(uv + vec2(px.x, 0.0), inv_proj);
	float u = view_depth(uv - vec2(0.0, px.y), inv_proj);
	float d = view_depth(uv + vec2(0.0, px.y), inv_proj);
	// Salto de profundidad (silueta), medido contra la pendiente de la propia cara: una pared
	// vista casi de canto tiene mucha pendiente pero ninguna silueta y no debe dar contorno
	float bend_x = abs(l + r - 2.0 * c) / (abs(l - r) + 0.002 * c);
	float bend_y = abs(u + d - 2.0 * c) / (abs(u - d) + 0.002 * c);
	float depth_edge = smoothstep(0.5, 0.9, max(bend_x, bend_y));
	vec3 nc = texture(normal_texture, uv).xyz * 2.0 - 1.0;
	vec3 nr = texture(normal_texture, uv + vec2(px.x, 0.0)).xyz * 2.0 - 1.0;
	vec3 nd = texture(normal_texture, uv + vec2(0.0, px.y)).xyz * 2.0 - 1.0;
	float normal_edge = smoothstep(0.25, 0.5, max(1.0 - dot(nc, nr), 1.0 - dot(nc, nd)));
	return max(depth_edge, normal_edge);
}

/// Contorno suavizado con los cuatro vecinos: una línea de unos 3 px con caída suave, que al
/// moverse la cámara se desliza en vez de encenderse y apagarse píxel a píxel
float soft_plan_edge(vec2 uv, vec2 px, mat4 inv_proj) {
	float e = plan_edge(uv, px, inv_proj) * 2.0;
	e += plan_edge(uv + vec2(px.x, 0.0), px, inv_proj);
	e += plan_edge(uv - vec2(px.x, 0.0), px, inv_proj);
	e += plan_edge(uv + vec2(0.0, px.y), px, inv_proj);
	e += plan_edge(uv - vec2(0.0, px.y), px, inv_proj);
	return min(e / 3.0, 1.0);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;

	vec2 offset = world.xz - eye_xz;
	float radial = length(offset);
	float angle = atan(offset.y, offset.x);
	if (angle < 0.0) {
		angle += 6.28318530718;
	}
	float slot = angle / 6.28318530718 * float(ray_count);
	int first = int(floor(slot)) % ray_count;
	int second = (first + 1) % ray_count;
	float limit = mix(distances[first], distances[second], fract(slot));
	limit = min(limit, view_radius);
	float raised = smoothstep(raised_from, raised_to, world.y);
	float feather = mix(edge_feather, raised_feather, raised);
	float visible = 1.0 - smoothstep(limit, limit + feather, radial);

	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float peak = max(color.r, max(color.g, color.b));
	visible = max(visible, smoothstep(light_keep, light_keep + 0.3, peak));
	if (visible >= 1.0) {
		ALBEDO = color;
		ALPHA = 1.0;
	} else {
		float gray = dot(color, vec3(0.299, 0.587, 0.114));
		float tone = smoothstep(0.0, 0.5, gray);
		vec3 ink_floor = mix(ink_floor_dark, ink_floor_light, tone);
		vec3 ink_raised = mix(ink_raised_dark, ink_raised_light, tone);
		vec3 ink = mix(ink_floor, ink_raised, raised);
		float edge = soft_plan_edge(SCREEN_UV, 1.0 / VIEWPORT_SIZE, INV_PROJECTION_MATRIX);
		edge *= smoothstep(line_clear_near, line_clear_near + 1.0, radial);
		edge *= smoothstep(line_min_height - 0.2, line_min_height, world.y);
		vec3 plan = mix(ink, ink_line, edge * line_strength);
		ALBEDO = mix(plan, color, visible);
		ALPHA = 1.0;
	}
}
