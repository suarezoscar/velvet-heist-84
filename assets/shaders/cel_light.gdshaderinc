/**
 * cel_light.gdshaderinc
 * Luz cel-shading de Velvet Heist '84 (#181, fase 1): la luz difusa se cuantiza en tres
 * bandas (luz, penumbra tintada y sombra) y el brillo especular es una mancha dura opcional.
 * La sombra la pone la luz ambiente del WorldEnvironment (azul noche plana), así que la banda
 * oscura no suma nada. La comparten cel_toon.gdshader y wall_xray.gdshader.
 */

/// Por encima de este valor de luz (N·L × atenuación) la banda es luz plena
uniform float band_light : hint_range(0.0, 1.0) = 0.45;
/// Por encima de este y por debajo de band_light, penumbra
uniform float band_shadow : hint_range(0.0, 1.0) = 0.08;
/// Ancho del paso entre bandas (0 = corte duro)
uniform float band_softness : hint_range(0.0, 0.2) = 0.02;
/// Color de la penumbra relativo a la luz (azul/morado nocturno)
uniform vec3 penumbra_tint : source_color = vec3(0.5, 0.46, 0.72);
/// Brillo especular duro: 0 lo apaga
uniform float specular_strength : hint_range(0.0, 2.0) = 0.0;
/// Tamaño de la mancha especular (más alto, más pequeña)
uniform float specular_size : hint_range(1.0, 256.0) = 48.0;

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float full = smoothstep(band_light - band_softness, band_light + band_softness, lit);
	// El paso empieza por encima de 0: donde la luz no llega (lit = 0) no suma nada. Si empezara
	// por debajo, cada luz teñiría las baldosas de pantalla que tiene asignadas y se verían
	// cuadros de unos 32 px (#189, con band_softness 0,15)
	float low = max(band_shadow - band_softness, 0.001);
	float half_band = smoothstep(low, band_shadow + band_softness, lit);
	vec3 band = mix(penumbra_tint * half_band, vec3(1.0), full);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * band;
	if (specular_strength > 0.0) {
		vec3 half_vec = normalize(LIGHT + VIEW);
		float spec = pow(clamp(dot(NORMAL, half_vec), 0.0, 1.0), specular_size) * ATTENUATION;
		SPECULAR_LIGHT += LIGHT_COLOR / PI * step(0.5, spec) * specular_strength;
	}
}
