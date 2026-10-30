shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.95, 0.72, 0.32, 0.6);
uniform float outline_width = 0.018;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	float fresnel = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * smoothstep(0.0, 1.0, fresnel);
}
