## @file player_name.gd
## El nombre del jugador y la firma del ladrón (docs/gdd/estilo-de-textos.md §7). El nombre
## tiene de MIN_LENGTH a MAX_LENGTH caracteres: letras (con tildes y ñ), números, espacio, guion
## y guion bajo, sin espacios en los extremos. El ladrón firma con la primera letra de su
## nombre en mayúscula («—D.»), o con «—V.» si no tiene nombre o este no tiene letras.
class_name PlayerName
extends RefCounted

const MIN_LENGTH: int = 2
const MAX_LENGTH: int = 16
const FALLBACK_SIGNATURE: String = "—V."
const EXTRA_CHARACTERS: String = " -_"


## Quita lo que no vale y recorta a MAX_LENGTH ("" si no queda un nombre válido)
static func clean(raw: String) -> String:
	var kept: String = ""
	for character: String in raw:
		if (
			_is_letter(character)
			or character.is_valid_int()
			or EXTRA_CHARACTERS.contains(character)
		):
			kept += character
	kept = kept.strip_edges().left(MAX_LENGTH).strip_edges()
	return kept if kept.length() >= MIN_LENGTH else ""


## Firma de un nombre: «—» con la primera letra en mayúscula y un punto, o FALLBACK_SIGNATURE
static func signature(player_name: String) -> String:
	for character: String in player_name:
		if _is_letter(character):
			return "—%s." % character.to_upper()
	return FALLBACK_SIGNATURE


## El nombre tal cual si nadie lo usa; si no, con un número («Diego 2», «Diego 3»…)
static func unique(player_name: String, taken: Array) -> String:
	if not taken.has(player_name):
		return player_name
	var index: int = 2
	while taken.has("%s %d" % [player_name, index]):
		index += 1
	return "%s %d" % [player_name, index]


## Firma del ladrón de esta partida: en red, la del jugador que lo lleva; sin red, la del
## jugador local (que es el ladrón)
static func thief_signature(_tree: SceneTree) -> String:
	if NetManager.is_online():
		var peer: int = NetManager.get_peer_id_for_role(NetManagerNode.ROLE_THIEF)
		var info: Dictionary = NetManager.get_connected_players().get(peer, {})
		return signature(String(info.get("chosen_name", "")))
	return signature(GameSettings.load_saved().player_name)


static func _is_letter(character: String) -> bool:
	return character.to_upper() != character.to_lower()
