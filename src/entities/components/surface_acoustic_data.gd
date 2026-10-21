## @file surface_acoustic_data.gd
## Recurso de datos de balance para la acústica de superficies de suelo.
class_name SurfaceAcousticData
extends Resource

## Identificador de la superficie (ej. carpet, wood_parquet, marble)
@export var surface_id: StringName = &"default"

## Multiplicador de propagación acústica (GSD 4.1)
@export var noise_multiplier: float = 1.0
