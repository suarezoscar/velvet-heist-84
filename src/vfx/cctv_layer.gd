## @file cctv_layer.gd
## «Solo en las imágenes CCTV» (interaction.md M6, FEAT-042): pasa la geometría de un personaje
## a LAYER, sin sombra, para que la cámara principal no lo dibuje y las cámaras de seguridad sí.
## Lo usan el ladrón que ve un guardia por las cámaras y el guardia que ve al ladrón.
class_name CctvLayer
extends RefCounted

const LAYER: int = 20


## Como apply, pero solo si cambia (se llama en cada fotograma o snapshot)
static func set_mode(root: Node, cctv: bool) -> void:
	if root == null or bool(root.get_meta(&"cctv_mode", false)) == cctv:
		return
	root.set_meta(&"cctv_mode", cctv)
	apply(root, cctv)


## Pone node y todo lo que cuelga de él en LAYER (cctv) o en sus capas de siempre
static func apply(node: Node, cctv: bool) -> void:
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		if not geometry.has_meta(&"world_layers"):
			geometry.set_meta(&"world_layers", geometry.layers)
			geometry.set_meta(&"world_shadow", geometry.cast_shadow)
		geometry.layers = 1 << (LAYER - 1) if cctv else int(geometry.get_meta(&"world_layers"))
		geometry.cast_shadow = (
			(
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if cctv
				else geometry.get_meta(&"world_shadow")
			)
			as GeometryInstance3D.ShadowCastingSetting
		)
	for child: Node in node.get_children():
		apply(child, cctv)
