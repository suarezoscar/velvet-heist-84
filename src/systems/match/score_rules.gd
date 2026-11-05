## @file score_rules.gd
## Puntos del informe final (FEAT-041; #123, heist.md R4b y R11). Deciden la huida a medias y
## «MEJOR DE LA NOCHE»; no cambian el juego. Se ajustan con /balance
## (data/balance/score_rules.tres).
class_name ScoreRules
extends Resource

@export_group("Ladrón")
## Bolsa de las piezas: robar s de un encargo de k vale bolsa × s / k
@export var thief_piece_pool: int = 300
## Por escapar con el encargo completo
@export var thief_escape: int = 150
## Por la huida a medias, según los guardias con ficha (1, 2, 3, 4; más, el último)
@export var thief_partial_escape_by_guards: Array[int] = [75, 60, 54, 50]
## Por cada pieza robada que nadie notó hasta el final (sin rastro descubierto)
@export var thief_clean_piece: int = 20
## Por cada segundo de cuenta atrás que le sobraba al huir
@export var thief_fast_escape: int = 2
## Por cada vez que los despistó tras ser visto
@export var thief_lose_them: int = 25
## Segundos sin que ningún guardia lo vea ni le pegue para despistarlos
@export var lose_them_time: float = 8.0
## Por cada caja de reja que dejó saboteada al acabar
@export var thief_sabotage: int = 30
## Por huir por una reja que seguía arriba gracias al sabotaje (con la alarma, rejas cerradas)
@export var thief_sabotage_escape: int = 60
## Por cada vez que hizo saltar la alarma
@export var thief_alarm: int = -15
## Por cada vez que un guardia empezó a verlo
@export var thief_seen: int = -10
## Por cada golpe de porra recibido
@export var thief_hit_taken: int = -20

@export_group("Guardias")
## Al que hace saltar la alarma (viéndolo, con la cámara en pantalla o con el último rastro)
@export var guard_alarm: int = 50
## Por cada vez que empezó a verlo (sin contar la que dio la alarma)
@export var guard_seen: int = 25
## Por cada falsificación que descubrió examinándola
@export var guard_examine_fake: int = 40
## Por cada marca del walkie que acertó: un compañero lo ve cerca de ella a tiempo
@export var guard_walkie: int = 30
## Segundos tras la marca en los que cuenta que un compañero lo vea
@export var walkie_hit_window: float = 10.0
## Metros desde la marca a los que tiene que estar el ladrón
@export var walkie_hit_radius: float = 6.0
## Por cada robo en silencio a menos de near_theft_radius m de él (sin muros)
@export var guard_near_theft: int = -30
@export var near_theft_radius: float = 5.0
## Por cada golpe de porra que acertó
@export var guard_hit: int = 50
## Al que da el golpe que lo atrapa
@export var guard_capture: int = 150
## Por cada cabezada
@export var guard_nap: int = -15
## Por cada caja de reja saboteada que reparó
@export var guard_repair: int = 40

@export_group("Equipo")
## Bolsa de «proteger»: bolsa × (piezas en su sitio) / k, repartida entre los guardias
@export var team_protect_pool: int = 300
## Bolsa de «encerrado»: las rejas bajan con él dentro; repartida entre los guardias
@export var team_lockdown_pool: int = 150


## Puntos de la huida a medias con guards guardias con ficha
func partial_escape_for(guards: int) -> int:
	if thief_partial_escape_by_guards.is_empty():
		return 0
	var index: int = clampi(guards, 1, thief_partial_escape_by_guards.size()) - 1
	return thief_partial_escape_by_guards[index]
