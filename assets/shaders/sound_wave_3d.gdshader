shader_type spatial;
render_mode unshaded, depth_test_disabled, blend_add, cull_disabled;

uniform vec4 wave_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float current_radius : hint_range(0.0, 1.0) = 0.0;
uniform float thickness : hint_range(0.01, 0.2) = 0.04;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // Coordenadas centradas UV (-0.5 a 0.5)
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv) * 2.0; // Distancia normalizada de 0.0 a 1.0

    // Anillo SDF basado en distancia al radio actual
    float ring_dist = abs(dist - current_radius);
    float ring_alpha = smoothstep(thickness, 0.0, ring_dist);

    ALBEDO = wave_color.rgb;
    ALPHA = ring_alpha * fade_alpha * wave_color.a;
}
