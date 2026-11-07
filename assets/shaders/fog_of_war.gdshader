shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

/**
 * fog_of_war.gdshader
 * Niebla de guerra de la vista principal (vision.md R1-R2). Malla de pantalla completa que
 * reconstruye la posición de cada píxel desde la profundidad y la compara con la zona visible
 * del jugador local, dada como distancia por ángulo alrededor de sus ojos (polígono en estrella
 * que calcula FogOfWar3D). Fuera de la zona, oscurece y desatura; con un borde suave. Las luces
 * (pilotos, bombillas) atraviesan la niebla: el píxel cuyo canal más alto pasa de light_keep
 * no se oscurece (vision.md D5). #163: dos grados con la misma zona; el suelo lleva la niebla
 * entera y lo que se alza de él (más de raised_from m, del todo desde raised_to) solo un
 * oscurecido suave, para que el borde de la vista no barra las paredes al andar.
 */

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float distances[256];
uniform int ray_count = 256;
uniform vec2 eye_xz = vec2(0.0);
uniform float view_radius = 18.0;
uniform float edge_feather = 1.0;
uniform float fog_brightness : hint_range(0.0, 1.0) = 0.35;
uniform float fog_desaturation : hint_range(0.0, 1.0) = 0.7;
uniform float light_keep = 0.9;
uniform float raised_brightness : hint_range(0.0, 1.0) = 0.8;
uniform float raised_desaturation : hint_range(0.0, 1.0) = 0.3;
uniform float raised_from = 0.08;
uniform float raised_to = 0.2;
/// #186 (prototipo): 0 actual (oscuro y gris), 1 oscuridad, 2 plano en azul tinta
uniform int style = 0;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;
uniform vec3 ink_floor_dark : source_color = vec3(0.02, 0.035, 0.09);
uniform vec3 ink_floor_light : source_color = vec3(0.07, 0.13, 0.27);
uniform vec3 ink_raised_dark : source_color = vec3(0.06, 0.1, 0.22);
uniform vec3 ink_raised_light : source_color = vec3(0.2, 0.32, 0.58);
uniform vec3 ink_line : source_color = vec3(0.55, 0.75, 1.0);
uniform float ink_line_strength : hint_range(0.0, 1.0) = 0.5;

/// Distancia a la cámara del píxel en uv (espacio de vista)
float view_depth(vec2 uv, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, texture(depth_texture, uv).x, 1.0);
	return -v.z / v.w;
}

/// Contorno del plano: saltos de profundidad y cambios de normal entre píxeles vecinos
float plan_edge(vec2 uv, vec2 px, mat4 inv_proj) {
	float c = view_depth(uv, inv_proj);
	float l = view_depth(uv - vec2(px.x, 0.0), inv_proj);
	float r = view_depth(uv + vec2(px.x, 0.0), inv_proj);
	float u = view_depth(uv - vec2(0.0, px.y), inv_proj);
	float d = view_depth(uv + vec2(0.0, px.y), inv_proj);
	float lap = abs(l + r - 2.0 * c) + abs(u + d - 2.0 * c);
	float depth_edge = smoothstep(0.04, 0.1, lap / max(c, 0.001) * 10.0);
	vec3 nc = texture(normal_texture, uv).xyz * 2.0 - 1.0;
	vec3 nr = texture(normal_texture, uv + vec2(px.x, 0.0)).xyz * 2.0 - 1.0;
	vec3 nd = texture(normal_texture, uv + vec2(0.0, px.y)).xyz * 2.0 - 1.0;
	float normal_edge = smoothstep(0.25, 0.5, max(1.0 - dot(nc, nr), 1.0 - dot(nc, nd)));
	return max(depth_edge, normal_edge);
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
	float visible = 1.0 - smoothstep(limit, limit + edge_feather, radial);

	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float peak = max(color.r, max(color.g, color.b));
	visible = max(visible, smoothstep(light_keep, light_keep + 0.3, peak));
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	float raised = smoothstep(raised_from, raised_to, world.y);
	float brightness = mix(fog_brightness, raised_brightness, raised);
	float desaturation = mix(fog_desaturation, raised_desaturation, raised);
	vec3 fogged = mix(color, vec3(gray), desaturation) * brightness;
	if (style == 1) {
		// oscuridad: noche cerrada azulada, las paredes algo más claras que el suelo
		fogged = gray * vec3(0.45, 0.55, 1.0) * brightness;
	} else if (style == 2) {
		// plano: dos tintas (suelo y lo que se alza) según la luz, con el contorno en claro
		float tone = smoothstep(0.0, 0.5, gray);
		vec3 ink_floor = mix(ink_floor_dark, ink_floor_light, tone);
		vec3 ink_raised = mix(ink_raised_dark, ink_raised_light, tone);
		vec3 ink = mix(ink_floor, ink_raised, raised);
		vec2 px = 1.0 / VIEWPORT_SIZE;
		float edge = plan_edge(SCREEN_UV, px, INV_PROJECTION_MATRIX);
		fogged = mix(ink, ink_line, edge * ink_line_strength);
	}
	ALBEDO = mix(fogged, color, visible);
	ALPHA = 1.0;
}
