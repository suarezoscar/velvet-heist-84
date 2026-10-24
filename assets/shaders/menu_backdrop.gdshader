shader_type canvas_item;

/**
 * menu_backdrop.gdshader
 * Capa sobre el fondo del menú principal: oscurece la franja izquierda (donde va el texto)
 * y el borde inferior, viñetea las esquinas y añade grano de película y líneas de barrido.
 */

uniform vec4 shade_color : source_color = vec4(0.027, 0.031, 0.051, 1.0);
uniform float left_strength : hint_range(0.0, 1.0) = 0.9;
uniform float left_extent : hint_range(0.1, 1.0) = 0.62;
uniform float bottom_strength : hint_range(0.0, 1.0) = 0.55;
uniform float bottom_extent : hint_range(0.05, 1.0) = 0.3;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.05;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.05;
uniform float scanline_density : hint_range(100.0, 1200.0) = 540.0;
uniform vec2 grain_resolution = vec2(960.0, 540.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float left = left_strength * (1.0 - smoothstep(0.0, left_extent, uv.x));
	float bottom = bottom_strength * smoothstep(1.0 - bottom_extent, 1.0, uv.y);
	vec2 centered = uv - vec2(0.5);
	float vignette = vignette_strength * smoothstep(0.35, 0.85, length(centered));
	float shade = clamp(max(max(left, bottom), vignette), 0.0, 1.0);
	float scan = (sin(uv.y * scanline_density * 3.14159) * 0.5 + 0.5) * scanline_strength;
	vec2 cell = floor(uv * grain_resolution);
	float grain = (hash(cell + vec2(floor(TIME * 24.0) * 7.31)) - 0.5) * grain_strength;
	COLOR = vec4(shade_color.rgb, clamp(shade + scan + grain, 0.0, 1.0));
}
