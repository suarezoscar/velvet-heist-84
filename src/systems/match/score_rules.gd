## @file score_rules.gd
## Puntos del informe final (FEAT-041). No cambian el juego: solo valoran la partida de cada
## jugador. Se ajustan con /balance (data/balance/score_rules.tres).
class_name ScoreRules
extends Resource

@export_group("Ladrón")
## Por cada pieza del encargo robada
@export var thief_piece: int = 100
## Por escapar con el encargo completo
@export var thief_escape: int = 150
## Por cada vez que hizo saltar la alarma
@export var thief_alarm: int = -25
## Por cada vez que un guardia empezó a verlo
@export var thief_seen: int = -10

@export_group("Guardias")
## Por cada reloj fichado
@export var guard_clock: int = 10
## Por cada falta de ronda
@export var guard_fault: int = -20
## Por cada vez que empezó a ver al ladrón
@export var guard_seen: int = 25
## Por cada golpe de porra que acertó
@export var guard_hit: int = 50
## Al que da el golpe que lo atrapa
@export var guard_capture: int = 150
## Por cada cabezada
@export var guard_nap: int = -15
