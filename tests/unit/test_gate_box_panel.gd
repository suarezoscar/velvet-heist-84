extends GutTest
## El panel de sabotear la caja de la reja y el texto de las rejas cerradas (#121)


func _view(step: int, holding: bool = true, splice: float = 0.0) -> Dictionary:
	return {"game": 1, "step": step, "holding": holding, "splice": splice}


func test_status_pasos_con_tornillos() -> void:
	assert_eq(GateBox84.status_text(_view(GateBox3D.Step.UNSCREW)), "QUITANDO LA TAPA…")
	assert_eq(GateBox84.status_text(_view(GateBox3D.Step.SCREW)), "CERRANDO LA TAPA…")
	assert_eq(GateBox84.status_text(_view(GateBox3D.Step.UNSCREW, false)), "EN PAUSA: MANTÉN E")
	assert_eq(GateBox84.status_text(_view(GateBox3D.Step.SCREW, false)), "EN PAUSA: MANTÉN E")


func test_status_cables() -> void:
	var text: String = "CORTA LOS CABLES POR ORDEN DE BORNE"
	assert_eq(GateBox84.status_text(_view(GateBox3D.Step.CUT)), text)
	assert_eq(GateBox84.status_text(_view(GateBox3D.Step.CUT, false, 1.5)), text)


func test_closed_text() -> void:
	assert_eq(LockdownHud84.closed_text(1), "REJAS CERRADAS · 1 SALIDA ABIERTA")
	assert_eq(LockdownHud84.closed_text(2), "REJAS CERRADAS · 2 SALIDAS ABIERTAS")


func test_bind_ensena_y_oculta() -> void:
	var panel: GateBox84 = GateBox84.new()
	add_child_autofree(panel)
	var box: GateBox3D = GateBox3D.create("P01")
	add_child_autofree(box)
	var actor: Node3D = Node3D.new()
	add_child_autofree(actor)
	box.game = SabotageSession.start(box, actor)
	panel.bind(box)
	assert_true(panel.visible)
	panel.bind(null)
	assert_false(panel.visible)
