## @file museum_v2.gd
## Museo Velvet '84 v2 (FEAT-015): se construye desde data/levels/museum_v2.json en _ready,
## antes de que HeistMap3D busque al ladrón y a los guardias. Sin red quedan tantos guardias
## de IA como dice el nivel; con red, uno por jugador guardia (FEAT-022). FEAT-034: decorado,
## ventilación, puerta de la garita, rondas por guardia y partida de match_minutes.
## Diseño en docs/gdd/levels/museum_v2.md.
extends HeistMap3D

const LEVEL_DATA_PATH: String = "res://data/levels/museum_v2.json"


func _ready() -> void:
	var data: LevelData = LevelData.load_json(LEVEL_DATA_PATH)
	if data != null:
		LevelArchitectureBuilder.build(data, self)
		LevelEntitiesBuilder.build(data, self)
		LevelDressingBuilder.build(data, self)
		offline_guard_count = int(data.raw.get("offline_guards", data.section("patrols").size()))
		if data.raw.has("match_minutes"):
			GameManager.match_duration_seconds = float(data.raw["match_minutes"]) * 60.0
	super._ready()
