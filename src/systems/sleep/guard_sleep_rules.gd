## @file guard_sleep_rules.gd
## Números del sueño del guardia y del café (heist.md R5).
class_name GuardSleepRules
extends Resource

## Subida del sueño por segundo fuera de la garita (0..1; #116: 1/240 → bostezo a 180 s y
## cabezada a 240 s con los umbrales de abajo)
@export var rise_rate: float = 1.0 / 240.0
## Umbrales de somnoliento y agotado
@export var drowsy_at: float = 0.75
@export var exhausted_at: float = 1.0
## Bostezo: cada cuántos segundos y radio del ruido (m)
@export var yawn_interval: float = 8.0
@export var yawn_radius: float = 7.0
## Factor de los alcances de vista somnoliento
@export var drowsy_sight: float = 0.8
## Cabezadas: cada cuántos segundos y cuánto dura cada una
@export var nod_interval: float = 10.0
@export var nod_time: float = 2.5
## Café: lo que tarda, radio del ruido de la cafetera (m) y tiempo despejado después
@export var coffee_time: float = 3.0
@export var coffee_radius: float = 8.0
@export var fresh_time: float = 60.0
## Si el guardia se aleja más de esto (m) mientras se sirve, se cancela
@export var coffee_leash: float = 1.5
## Somnífero del ladrón (FEAT-033): dosis por partida, segundos que tarda en echarlo y cuánto
## dura la cabezada del guardia que se bebe el café drogado (s)
@export var drug_doses: int = 1
@export var drug_time: float = 3.0
@export var drug_nap_time: float = 8.0
## Bajón tras las luces de alarma (FEAT-033): sueño mínimo de los guardias al apagarse
@export var crash_level: float = 0.85
## La IA va a por café cuando su sueño llega aquí (#116: al primer bostezo)
@export var ai_coffee_at: float = 0.75
