## @file update_plan.gd
## Qué bajar para actualizar el juego (FEAT-036) a partir del índice de Velopack
## (releases.<canal>.json): los paquetes de diferencias desde la versión instalada si están
## todos, pesan menos y está su paquete completo como base; si no, el paquete completo.
class_name UpdatePlan
extends RefCounted


## a > b en versiones «X.Y.Z» (lo que va tras un «-» no cuenta)
static func is_newer(a: String, b: String) -> bool:
	var left: PackedStringArray = a.get_slice("-", 0).split(".")
	var right: PackedStringArray = b.get_slice("-", 0).split(".")
	for index: int in range(maxi(left.size(), right.size())):
		var l: int = int(left[index]) if index < left.size() else 0
		var r: int = int(right[index]) if index < right.size() else 0
		if l != r:
			return l > r
	return false


## Qué bajar para pasar de current a la versión más nueva del índice ([] si ya está al día):
## las diferencias de cada versión intermedia si hay base (el paquete completo de current), si
## están todas y si pesan menos que el completo; si no, solo el paquete completo de la última
static func make(feed: Dictionary, current: String, has_base: bool) -> Array[Dictionary]:
	var fulls: Dictionary = {}
	var deltas: Dictionary = {}
	for entry: Variant in feed.get("Assets", []):
		var item: Dictionary = entry as Dictionary
		var version: String = String(item.get("Version", ""))
		if String(item.get("Type", "")) == "Full":
			fulls[version] = item
		elif String(item.get("Type", "")) == "Delta":
			deltas[version] = item
	var versions: Array = fulls.keys()
	for version: String in deltas:
		if not fulls.has(version):
			versions.append(version)
	versions.sort_custom(func(a: String, b: String) -> bool: return is_newer(b, a))
	var result: Array[Dictionary] = []
	if versions.is_empty() or not fulls.has(versions[-1]) or not is_newer(versions[-1], current):
		return result
	var latest: Dictionary = fulls[versions[-1]]
	var start: int = versions.find(current)
	var chain_size: int = 0
	if has_base and start >= 0:
		for version: String in versions.slice(start + 1):
			if not deltas.has(version):
				result.clear()
				break
			result.append(deltas[version])
			chain_size += int(deltas[version].get("Size", 0))
	if result.is_empty() or chain_size >= int(latest.get("Size", 0)):
		result.assign([latest])
	return result
