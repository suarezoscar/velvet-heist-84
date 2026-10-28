shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

/**
 * fog_of_war.gdshader
 * Niebla de guerra de la vista principal (vision.md R1-R2). Malla de pantalla completa que
 * reconstruye la posición de cada píxel desde la profundidad y la compara con la zona visible
 * del jugador local, dada como distancia por ángulo alrededor de sus ojos (polígono en estrella
 * que calcula FogOfWar3D). Fuera de la zona, oscurece y desatura; con un borde suave. Las luces
 * (pilotos, bombillas) atraviesan la niebla: el píxel cuyo canal más alto pasa de light_keep
 * no se oscurece (vision.md D5).
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
	vec3 fogged = mix(color, vec3(gray), fog_desaturation) * fog_brightness;
	ALBEDO = mix(fogged, color, visible);
	ALPHA = 1.0;
}
