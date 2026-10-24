## @file museum_v2.gd
## Museo Velvet '84 v2 (FEAT-015): se construye desde data/levels/museum_v2.json en _ready,
## antes de que HeistMap3D busque al ladrón y a los guardias.
## Diseño en docs/gdd/levels/museum_v2.md.
extends HeistMap3D

const LEVEL_DATA_PATH: String = "res://data/levels/museum_v2.json"


func _ready() -> void:
	var data: LevelData = LevelData.load_json(LEVEL_DATA_PATH)
	if data != null:
		LevelArchitectureBuilder.build(data, self)
		LevelEntitiesBuilder.build(data, self)
	super._ready()
