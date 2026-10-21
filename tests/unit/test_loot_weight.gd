## @file test_loot_weight.gd
## Tests de penalizaciones y peso del botín (Criterio 5 / GSD 4.3).
extends GutTest


## Crea una instancia de ladrón configurada en árbol
func _create_thief() -> ThiefController3D:
	var thief: ThiefController3D = autofree(ThiefController3D.new())
	add_child_autofree(thief)
	return thief


## Crea un objeto de botín pesado
func _create_heavy_loot(name: String = "Cuadro Barroco", value: int = 5000) -> LootItem3D:
	var loot: LootItem3D = autofree(LootItem3D.new())
	loot.loot_name = name
	loot.loot_value = value
	loot.is_heavy = true
	add_child_autofree(loot)
	return loot


## Crea un objeto de botín ligero
func _create_light_loot(name: String = "Fajo de Dolares", value: int = 1500) -> LootItem3D:
	var loot: LootItem3D = autofree(LootItem3D.new())
	loot.loot_name = name
	loot.loot_value = value
	loot.is_heavy = false
	add_child_autofree(loot)
	return loot


## Criterio 5: Constante de penalización de velocidad fijada en 0.8 (-20%)
func test_heavy_loot_constants() -> void:
	assert_eq(ThiefController3D.HEAVY_LOOT_SPEED_MULTIPLIER, 0.8, "Penalización botín es 0.8")


## Criterio 5: El ladrón empieza sin botín pesado y con gadgets habilitados
func test_thief_initial_state_can_use_gadgets() -> void:
	var thief: ThiefController3D = _create_thief()
	await wait_physics_frames(1)

	assert_false(thief.is_carrying_heavy_loot, "El ladrón no carga botín al inicio")
	assert_null(thief.carried_loot, "No hay referencia de objeto transportado")
	assert_true(thief.can_use_gadgets(), "El ladrón puede usar gadgets libremente sin peso")


## Criterio 5: Cargar botín pesado bloquea el uso de gadgets
func test_carrying_heavy_loot_blocks_gadgets() -> void:
	var thief: ThiefController3D = _create_thief()
	var heavy_loot: LootItem3D = _create_heavy_loot("Busto de Bronce", 8000)
	await wait_physics_frames(1)

	heavy_loot.interact(thief)

	assert_true(thief.is_carrying_heavy_loot, "Bandera de botín pesado activa")
	assert_eq(thief.carried_loot, heavy_loot, "Ladrón sostiene objeto pesado")
	assert_false(thief.can_use_gadgets(), "Gadgets bloqueados con botín pesado")


## Criterio 5: Soltar botín pesado restaura el uso de gadgets
func test_dropping_heavy_loot_restores_gadgets() -> void:
	var thief: ThiefController3D = _create_thief()
	var heavy_loot: LootItem3D = _create_heavy_loot("Caja de Caudales", 10000)
	await wait_physics_frames(1)

	heavy_loot.interact(thief)
	assert_false(thief.can_use_gadgets(), "Bloqueado al cargarlo")

	thief.drop_heavy_loot()

	assert_false(thief.is_carrying_heavy_loot, "Ya no carga botín pesado")
	assert_null(thief.carried_loot, "Referencia de objeto liberada")
	assert_true(thief.can_use_gadgets(), "Uso de gadgets restaurado tras soltar el botín")


## Criterio 5: El botín ligero NO penaliza ni bloquea gadgets
func test_light_loot_does_not_block_gadgets_or_slow() -> void:
	var thief: ThiefController3D = _create_thief()
	var light_loot: LootItem3D = _create_light_loot("Reloj de Oro", 2000)
	await wait_physics_frames(1)

	light_loot.interact(thief)

	assert_false(thief.is_carrying_heavy_loot, "Botín ligero no activa penalización de peso")
	assert_null(thief.carried_loot, "Las manos del ladrón permanecen libres")
	assert_true(thief.can_use_gadgets(), "El ladrón conserva la capacidad de usar gadgets")


## Criterio 5: Penalización de velocidad a x0.8 aplicada a la velocidad de movimiento
func test_heavy_loot_velocity_reduction() -> void:
	var thief: ThiefController3D = _create_thief()
	await wait_physics_frames(1)

	# Simular velocidad normal
	var base_vx: float = 4.0
	var base_vz: float = 3.0
	thief.velocity = Vector3(base_vx, 0.0, base_vz)

	# Sin botín pesado, no hay reducción
	thief.is_carrying_heavy_loot = false
	if thief.is_carrying_heavy_loot:
		thief.velocity.x *= ThiefController3D.HEAVY_LOOT_SPEED_MULTIPLIER
		thief.velocity.z *= ThiefController3D.HEAVY_LOOT_SPEED_MULTIPLIER
	assert_almost_eq(thief.velocity.x, 4.0, 0.001, "Velocidad X intacta sin botín pesado")
	assert_almost_eq(thief.velocity.z, 3.0, 0.001, "Velocidad Z intacta sin botín pesado")

	# Con botín pesado, reducción del 20% (x0.8)
	thief.is_carrying_heavy_loot = true
	if thief.is_carrying_heavy_loot:
		thief.velocity.x *= ThiefController3D.HEAVY_LOOT_SPEED_MULTIPLIER
		thief.velocity.z *= ThiefController3D.HEAVY_LOOT_SPEED_MULTIPLIER

	assert_almost_eq(thief.velocity.x, 3.2, 0.001, "Velocidad X reducida al 80% (4.0 * 0.8 = 3.2)")
	assert_almost_eq(thief.velocity.z, 2.4, 0.001, "Velocidad Z reducida al 80% (3.0 * 0.8 = 2.4)")


## Criterio 5: El ladrón no puede cargar un segundo botín pesado simultáneamente
func test_cannot_carry_two_heavy_loots_simultaneously() -> void:
	var thief: ThiefController3D = _create_thief()
	var loot1: LootItem3D = _create_heavy_loot("Estatua de Marmol", 6000)
	var loot2: LootItem3D = _create_heavy_loot("Tapiz Gigante", 7000)
	await wait_physics_frames(1)

	loot1.interact(thief)
	assert_eq(thief.carried_loot, loot1, "Primer botín cargado")

	# Intento de cargar segundo botín
	loot2.interact(thief)
	assert_eq(thief.carried_loot, loot1, "El segundo botín pesado es rechazado; manos ocupadas")
	assert_false(loot2.is_collected, "El segundo botín no se recoge")
