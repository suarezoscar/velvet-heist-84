## @file test_noise_meter_unit.gd
## Tests unitarios del ejecutor para NoiseMeter84 y NoiseMix (FEAT-012 PKG-5).
extends GutTest

const NOISE_MIX_PATH: String = "res://assets/audio/noise_mix.tres"
const HUD_PALETTE_PATH: String = "res://assets/ui/hud_palette.tres"


func test_meter_configure_and_initial_state() -> void:
	var meter: NoiseMeter84 = autofree(NoiseMeter84.new())
	meter.configure(10.0, 0.15, 0.4, 3.5)
	assert_almost_eq(meter.get_level(), 0.0, 0.001, "Nivel inicial debe ser 0")
	assert_eq(meter.lit_segments(), 0, "No debe haber segmentos encendidos inicialmente")
	assert_false(meter.is_over(), "No debe estar en saturación inicialmente")


func test_meter_push_dynamics() -> void:
	var meter: NoiseMeter84 = autofree(NoiseMeter84.new())
	meter.configure(10.0, 0.15, 0.4, 3.5)

	meter.push(3.5)
	assert_almost_eq(meter.get_level(), 3.5, 0.001, "Nivel tras push(3.5) debe ser 3.5")
	assert_eq(meter.lit_segments(), 4, "Radio 3.5 sobre escala 10 debe iluminar 4 segmentos")
	assert_false(meter.is_over(), "Radio 3.5 no satura")

	meter._process(0.15)
	assert_almost_eq(meter.get_level(), 3.5, 0.001, "A los meter_hold_time el nivel se mantiene")

	meter._process(0.2)
	assert_almost_eq(meter.get_level(), 1.75, 0.05, "A mitad de la caída debe valer 1.75 +- 0.05")

	meter._process(0.2)
	assert_almost_eq(meter.get_level(), 0.0, 0.001, "Tras hold + fall debe valer 0")
	assert_eq(meter.lit_segments(), 0, "Al volver a 0 no hay segmentos encendidos")


func test_meter_saturation_and_push_during_fall() -> void:
	var meter: NoiseMeter84 = autofree(NoiseMeter84.new())
	meter.configure(10.0, 0.15, 0.4, 3.5)

	meter.push(10.5)
	assert_almost_eq(meter.get_level(), 10.5, 0.001, "Nivel debe registrar 10.5")
	assert_true(meter.is_over(), "Radio 10.5 > 10.0 activa el LED de saturación")
	assert_eq(meter.lit_segments(), 10, "10.5 enciende todos los 10 segmentos")

	meter._process(0.15)
	meter._process(0.2)
	var mid_level: float = meter.get_level()
	assert_almost_eq(mid_level, 5.25, 0.1, "Mitad de caída desde 10.5")

	meter.push(8.0)
	assert_almost_eq(meter.get_level(), 8.0, 0.001, "Nuevo push(8.0) establece pico")
	meter._process(0.15)
	assert_almost_eq(meter.get_level(), 8.0, 0.001, "Retención reiniciada a 8.0")


func test_noise_mix_categories_db() -> void:
	var mix: NoiseMix = autofree(NoiseMix.new())
	mix.step_db = -14.0
	mix.impact_db = -6.0
	mix.mechanism_db = -10.0

	assert_almost_eq(mix.category_db(&"step"), -14.0, 0.001, "step_db debe ser -14.0")
	assert_almost_eq(mix.category_db(&"impact"), -6.0, 0.001, "impact_db debe ser -6.0")
	assert_almost_eq(mix.category_db(&"mechanism"), -10.0, 0.001, "mechanism_db debe ser -10.0")
	assert_almost_eq(mix.category_db(&"unknown"), 0.0, 0.001, "Categoría desconocida da 0.0")


func test_noise_mix_surface_thresholds() -> void:
	var mix: NoiseMix = autofree(NoiseMix.new())
	mix.soft_surface_max = 0.7
	mix.hard_surface_min = 1.3

	var s_soft: AudioStream = AudioStreamOggVorbis.new()
	var s_wood: AudioStream = AudioStreamOggVorbis.new()
	var s_hard: AudioStream = AudioStreamOggVorbis.new()
	var s_impact: AudioStream = AudioStreamOggVorbis.new()
	var s_mech: AudioStream = AudioStreamOggVorbis.new()

	mix.step_soft = [s_soft]
	mix.step_wood = [s_wood]
	mix.step_hard = [s_hard]
	mix.impact = [s_impact]
	mix.mechanism = [s_mech]

	assert_eq(mix.streams_for(&"step", 0.4), mix.step_soft, "Mult 0.4 debe ser step_soft")
	assert_eq(mix.streams_for(&"step", 0.7), mix.step_soft, "Borde 0.7 debe ser step_soft")

	assert_eq(mix.streams_for(&"step", 0.71), mix.step_wood, "Mult 0.71 debe ser step_wood")
	assert_eq(mix.streams_for(&"step", 1.0), mix.step_wood, "Mult 1.0 debe ser step_wood")
	assert_eq(mix.streams_for(&"step", 1.29), mix.step_wood, "Mult 1.29 debe ser step_wood")

	assert_eq(mix.streams_for(&"step", 1.3), mix.step_hard, "Borde 1.3 debe ser step_hard")
	assert_eq(mix.streams_for(&"step", 1.6), mix.step_hard, "Mult 1.6 debe ser step_hard")

	assert_eq(mix.streams_for(&"impact", 1.0), mix.impact, "impact devuelve array impact")
	assert_eq(mix.streams_for(&"mechanism", 1.0), mix.mechanism, "Categoría mechanism")
	assert_eq(mix.streams_for(&"other", 1.0).size(), 0, "Categoría desconocida da vacío")


func test_noise_mix_tres_assets() -> void:
	var mix: NoiseMix = load(NOISE_MIX_PATH) as NoiseMix
	assert_not_null(mix, "noise_mix.tres debe cargarse correctamente")
	assert_eq(mix.step_soft.size(), 5, "step_soft debe contener 5 muestras")
	assert_eq(mix.step_wood.size(), 5, "step_wood debe contener 5 muestras")
	assert_eq(mix.step_hard.size(), 5, "step_hard debe contener 5 muestras")
	assert_eq(mix.impact.size(), 5, "impact debe contener 5 muestras")
	assert_eq(mix.mechanism.size(), 5, "mechanism debe contener 5 muestras")


func test_hud_palette_tres_assets() -> void:
	var palette: HudPalette = load(HUD_PALETTE_PATH) as HudPalette
	assert_not_null(palette, "hud_palette.tres debe cargarse correctamente")
	var own_hex: String = palette.color_own.to_html(false).to_upper()
	assert_eq(own_hex, "F2B84B", "color_own F2B84B")
	var guard_hex: String = palette.color_guard.to_html(false).to_upper()
	assert_eq(guard_hex, "4FC3F7", "color_guard 4FC3F7")
	var other_hex: String = palette.color_other.to_html(false).to_upper()
	assert_eq(other_hex, "B8E6C1", "color_other B8E6C1")
	var low_hex: String = palette.color_meter_low.to_html(false).to_upper()
	assert_eq(low_hex, "B8E6C1", "color_meter_low B8E6C1")
	var mid_hex: String = palette.color_meter_mid.to_html(false).to_upper()
	assert_eq(mid_hex, "F2B84B", "color_meter_mid F2B84B")
	var high_hex: String = palette.color_meter_high.to_html(false).to_upper()
	assert_eq(high_hex, "FF6B5A", "color_meter_high FF6B5A")
