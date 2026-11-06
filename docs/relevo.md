# Relevo — #181 Fase 1 · Cel-shading y entorno nocturno

## Hecho
- Shaders: `cel_light.gdshaderinc` (3 bandas), `cel_toon.gdshader` (textura, normales, emisión con máscara, luz de borde), `outline.gdshader` (malla invertida, `box_mode`), `wall_xray_cut.gdshaderinc` (recorte compartido); `wall_xray.gdshader` con la luz cel y contorno.
- `CelConverter`, `NightLook` (`data/visual/night_look.tres`) y `NightEnvironmentSetup` (`src/vfx/setup_environment.gd`), enganchado en `HeistMap3D._ready`.
- Rejillas de conducto y piezas teñidas funcionan con o sin cel (`CelConverter.set_albedo`/`albedo_of`).
- `docs/gdd/art_style.md` con la paleta.
- Capturas antes/después enseñadas al usuario.

## Falta
- Cielo: synthwave procedural (`night_sky.gdshader`), sin `.hdr` (decisión del usuario).
- Ajustes tras la opinión del usuario (contorno, ambiente, bandas, light_keep de la niebla).
- Rendimiento con SDFGI + SSR + niebla volumétrica en su equipo.
- Limpieza de #147 (lo que no se usa o no tiene licencia).

## Decisiones
- Rutas del repo (`assets/shaders/`, `src/vfx/`) en vez de `res://shaders/` y `res://scripts/`.
- Contorno por malla invertida (lo pidió el usuario), no efecto de pantalla.
- VoxelGI no: el mapa se genera al cargar y no se puede hornear; SDFGI sí.

## Preguntas pendientes
- ¿Valen el contorno, la paleta y la luz del prototipo?
