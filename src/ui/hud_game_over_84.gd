## @file hud_game_over_84.gd
## Paneles de fin de partida del HUD: qué texto y color toca según el estado de GameManager.
class_name HudGameOver84
extends RefCounted


## Muestra el panel de fin de partida que toca según el estado de la partida
static func check_state(hud: HUD84) -> void:
	match GameManager.current_state:
		GameManager.MatchState.THIEF_ESCAPED:
			show_modal(
				hud,
				"¡EL LADRÓN HA ESCAPADO!",
				(
					"La colección tiene huecos y la ciudad, una leyenda nueva. «Con mis respetos, %s»"
					% PlayerName.thief_signature(hud.get_tree())
				),
				Color(0.25, 1.0, 0.4)
			)
		GameManager.MatchState.THIEF_CAPTURED:
			show_modal(
				hud,
				"¡LADRÓN CAPTURADO!",
				"Dos golpes de porra y el caballero acaba en el furgón. La central da parte: sin novedad.",
				Color(1.0, 0.25, 0.25)
			)
		GameManager.MatchState.THIEF_ESCAPED_PARTIAL:
			show_modal(
				hud,
				"¡HUIDA A MEDIAS!",
				"Salió con parte del encargo antes de que bajaran las rejas: decide la cuenta de la noche.",
				Color(0.95, 0.72, 0.29)
			)
		GameManager.MatchState.THIEF_LOCKED_IN:
			show_modal(
				hud,
				"¡ENCERRADO!",
				"Las rejas bajan y el caballero se queda dentro. La central da parte: sin novedad.",
				Color(1.0, 0.25, 0.25)
			)
		GameManager.MatchState.THIEF_NO_LOOT:
			show_modal(
				hud,
				"SIN BOTÍN",
				"Las rejas bajan con el ladrón en el callejón y las manos vacías.",
				Color(1.0, 0.25, 0.25)
			)
		GameManager.MatchState.TIME_EXPIRED:
			show_modal(
				hud,
				"SE ACABÓ LA NOCHE",
				"Amanece, la policía rodea el museo y el ladrón no salió con su encargo.",
				Color(1.0, 0.55, 0.1)
			)


## Rellena y muestra el panel de fin de partida
static func show_modal(hud: HUD84, title: String, subtitle: String, title_color: Color) -> void:
	if hud.game_over_panel != null:
		hud.game_over_panel.visible = true
	if hud.game_over_title != null:
		hud.game_over_title.text = title
		hud.game_over_title.modulate = title_color
	if hud.game_over_sub != null:
		hud.game_over_sub.text = subtitle
