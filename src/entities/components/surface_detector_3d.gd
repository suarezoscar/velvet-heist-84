## @file surface_detector_3d.gd
## Componente desacoplado para detectar el tipo de superficie bajo los pies de un personaje
## y calcular la propagación de ruido acústico según la regla de diseño de los años 80.
class_name SurfaceDetector3D
extends Node3D

## Distancia máxima del rayo hacia abajo para detectar el suelo
const RAY_LENGTH: float = 1.2

## Multiplicador de ruido por defecto si el suelo no tiene metadatos definidos
const DEFAULT_NOISE_MULTIPLIER: float = 1.0

## Capa de colisión del entorno estático (muros y suelos)
const ENVIRONMENT_COLLISION_MASK: int = 1

## RayCast interno hacia el suelo
var _ray: RayCast3D = null

func _ready() -> void:
	_initialize_raycast()

## Inicializa y configura el RayCast3D apuntando hacia los pies del personaje
func _initialize_raycast() -> void:
	_ray = RayCast3D.new()
	_ray.name = "GroundRay"
	_ray.target_position = Vector3(0.0, -RAY_LENGTH, 0.0)
	_ray.collision_mask = ENVIRONMENT_COLLISION_MASK
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	_ray.enabled = true
	add_child(_ray)

## Devuelve el multiplicador de ruido de la superficie actual (leído del StaticBody3D del suelo)
## Ejemplos: Alfombra (0.2), Parqué (1.5), Mármol (1.2).
func get_surface_noise_multiplier() -> float:
	if _ray == null or not _ray.is_colliding():
		return DEFAULT_NOISE_MULTIPLIER

	var collider: Object = _ray.get_collider()
	if collider != null and collider.has_meta("noise_multiplier"):
		return float(collider.get_meta("noise_multiplier"))

	return DEFAULT_NOISE_MULTIPLIER

## Calcula el radio acústico final en metros combinando la velocidad actual y la superficie
func calculate_step_noise_radius(base_radius: float, is_sprinting: bool, is_sneaking: bool) -> float:
	var state_base: float = base_radius
	if is_sprinting:
		state_base *= 2.0 # Correr duplica la propagación de onda
	elif is_sneaking:
		state_base *= 0.3 # El sigilo amortigua un 70% del sonido

	var surface_mult: float = get_surface_noise_multiplier()
	return state_base * surface_mult
