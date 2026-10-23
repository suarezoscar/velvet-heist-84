## Perfil de configuración de un tipo de lámpara (alcance, interruptor, desmontable y luz).
## Define los parámetros leídos por Lamp3D para balance visual y de interacción.
class_name LampProfile
extends Resource

@export var lamp_type: StringName = &""
@export var lit_radius: float = 0.0
@export var has_switch: bool = false
@export var unscrewable: bool = false
@export var light_color: Color = Color.WHITE
@export var light_energy: float = 1.0
