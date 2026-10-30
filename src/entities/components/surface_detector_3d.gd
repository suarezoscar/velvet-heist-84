## Componente desacoplado para detectar el tipo de superficie bajo los pies de un personaje.
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


## Devuelve el multiplicador de ruido de la superficie actual (leído del StaticBody3D del suelo)
func get_surface_noise_multiplier() -> float:
	if _ray == null or not _ray.is_colliding():
		return DEFAULT_NOISE_MULTIPLIER

	var collider: Object = _ray.get_collider()
	if collider != null and collider.has_meta("noise_multiplier"):
		return float(collider.get_meta("noise_multiplier"))

	return DEFAULT_NOISE_MULTIPLIER


## Multiplicador de la superficie bajo un punto del mundo (donde cae la moneda, #111)
static func multiplier_at(world: World3D, pos: Vector3) -> float:
	if world == null:
		return DEFAULT_NOISE_MULTIPLIER
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 0.5, pos + Vector3.DOWN * RAY_LENGTH, ENVIRONMENT_COLLISION_MASK
	)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")
	if collider != null and collider.has_meta("noise_multiplier"):
		return float(collider.get_meta("noise_multiplier"))
	return DEFAULT_NOISE_MULTIPLIER


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
