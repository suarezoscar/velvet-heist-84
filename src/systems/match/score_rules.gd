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
## Por la huida a medias (con la alarma, por una salida abierta con parte del botín)
@export var thief_partial_escape: int = 50
## Por cada caja de reja que dejó saboteada al acabar
@export var thief_sabotage: int = 30
## Por huir por una reja que seguía arriba gracias al sabotaje (con la alarma, rejas cerradas)
@export var thief_sabotage_escape: int = 60

@export_group("Guardias")
## Por cada vez que empezó a ver al ladrón
@export var guard_seen: int = 25
## Por cada golpe de porra que acertó
@export var guard_hit: int = 50
## Al que da el golpe que lo atrapa
@export var guard_capture: int = 150
## Por cada cabezada
@export var guard_nap: int = -15
## Por cada pieza del encargo que sigue en su sitio al acabar
@export var guard_protect: int = 60
## Al encerrar al ladrón (las rejas bajan con él dentro)
@export var guard_lockdown: int = 100
## Por cada caja de reja saboteada que reparó
@export var guard_repair: int = 40
