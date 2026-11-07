## @file night_look.gd
## Aspecto nocturno del museo (#181, fase 1): paleta, entorno, luna, contorno y luz de borde.
## Lo aplica NightEnvironmentSetup al cargar el mapa; los valores viven en
## data/visual/night_look.tres. La paleta y su uso están en docs/gdd/art_style.md.
class_name NightLook
extends Resource

@export_group("Paleta")
## Fondo, sombra, muro oscuro y muro iluminado
@export var night_deep: Color = Color("0b0e1a")
@export var night_shadow: Color = Color("1b2140")
@export var night_wall: Color = Color("2e3666")
@export var night_lit: Color = Color("4a5590")
## Piel y ropa
@export var skin: Color = Color("e0a98a")
@export var cloth: Color = Color("3a2e4f")
## Neones
@export var neon_pink: Color = Color("ff3ea5")
@export var neon_cyan: Color = Color("2ef2ff")
## Alarma y lámparas
@export var alarm_red: Color = Color("ff3b30")
@export var lamp_amber: Color = Color("ffb627")

@export_group("Entorno")
@export var sky_energy: float = 1.0
## Luz ambiente plana (es la banda de sombra del cel-shading)
@export var ambient_energy: float = 0.55
@export var ssr_enabled: bool = true
@export var sdfgi_enabled: bool = true
@export var sdfgi_energy: float = 0.6
@export var glow_intensity: float = 0.55
@export var glow_bloom: float = 0.08
@export var glow_hdr_threshold: float = 1.1
@export var volumetric_fog_enabled: bool = true
@export var volumetric_fog_density: float = 0.015
@export var volumetric_fog_albedo: Color = Color("4a5590")

@export_group("Luna")
@export var moon_color: Color = Color("8f9ce8")
@export var moon_energy: float = 0.55

@export_group("Materiales")
@export var outline_color: Color = Color("06030b")
## Metros a 25 m de la cámara
@export var outline_width: float = 0.05
## Penumbra relativa a la luz
@export var penumbra_tint: Color = Color("7a70b8")
## Paso entre las bandas del cel-shading (0 = corte duro). #189: más blando, menos escalones
@export var band_softness: float = 0.02
## Desenfoque de las sombras de todas las luces del mapa (#189: sombras suaves)
@export var shadow_blur: float = 1.0
@export var thief_rim: Color = Color("ff3ea5")
@export var guard_rim: Color = Color("2ef2ff")
@export var rim_strength: float = 0.8

@export_group("Capas (#191)")
## Trazo solo en lo jugable (personajes, botín, puertas, cajas fuertes...): ver CelConverter
@export var outline_only_gameplay: bool = false
## Trazo en muros, tabiques, muebles y piezas del kit (materiales de WallXRay)
@export var outline_architecture: bool = true
## Modelos con el color medio de su textura, sin textura ni relieve (salvo los cuadros)
@export var flat_textures: bool = false
## Intensidad del sombreado ambiental (SSAO) del WorldEnvironment
@export var ssao_intensity: float = 2.0
## Opacidad del cono de luz de la linterna de los guardias (0 lo quita)
@export var beam_cone_alpha: float = 0.0

@export_group("Paredes recortadas (#193)")
## true: las paredes delante de la sala del jugador bajan (WallCutaway); false: círculo de WallXRay
@export var occlusion_cutaway: bool = false
## Altura (m) a la que se recortan
@export var cutaway_height: float = 1.0
## Segundos que tardan en bajar o subir al cambiar de sala
@export var cutaway_time: float = 0.25
## Silueta del jugador local cuando algo lo tapa
@export var silhouette_color: Color = Color(1.0, 0.243, 0.647, 0.55)
## Rugosidad de los suelos (SSR refleja por debajo de ~0,6)
@export var floor_roughness: float = 0.35
