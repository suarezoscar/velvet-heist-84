# FEAT-037 — Icono del juego

- **Estado**: en curso
- **Diseño**: `n/a — técnica` (aspecto aprobado por el usuario el 2026-10-29)
- **Hito del PoC**: H5 (que el juego instalado se reconozca en el escritorio y la barra de tareas)
- **Rama**: `feat/037-icono`

## Objetivo
Sustituir el icono de Godot por uno del juego en el ejecutable, el instalador, los accesos
directos, el AppImage, la ventana y la web.

## Diseño elegido
El logo del menú principal sobre su fondo: «Velvet» en neón manuscrito rosa (Mr Dafoe, -6°,
con brillo) sobre «HEIST '84» (Bebas Neue, crema con sombra), encima de un recorte cuadrado de
la calle mojada de `assets/ui/menu_background_84.jpg`, oscurecida en los bordes. De 16 a 32 px,
donde el logo no se lee, solo la «V» manuscrita sobre la misma calle.

## Archivos
- `tools/icon/make_icon.py` genera todo a partir del fondo y las fuentes del juego (las letras
  van como trazados): `assets/ui/icon/velvet_icon.png` (1024 px), `velvet_icon.ico` (16-256 px)
  y `site/favicon.png`.
- `project.godot`: `config/icon` y `config/windows_native_icon` (commit propio).
- `export_presets.cfg` (Windows): `application/icon` y `application/modify_resources=true`
  (sin esto Godot no cambia el icono ni los datos de versión del .exe).
- `tools/build/velopack.sh`: `--icon` en Windows (.ico) y Linux (.png).
- Se quitan `icon.svg` (el de Godot) y `site/favicon.svg`.

## Origen y licencias
- Fondo: `assets/ui/menu_background_84.jpg`, el del menú principal (FEAT-018).
- Fuentes: Mr Dafoe y Bebas Neue, SIL Open Font License (`assets/fonts/`).

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | El .exe exportado lleva el icono (16 y 32 la «V», 48-256 el logo) | Recursos del .exe extraídos con pefile, 2026-10-29 |
| 2 | El instalador lleva el icono | `VelvetHeist84-win-Setup.exe`: 7 imágenes de icono |
| 3 | El AppImage lleva el icono | `VelvetHeist84.png` del AppImage idéntico a `velvet_icon.png` |
| 4 | La web usa la «V» como favicon | `site/favicon.png` |

## Riesgos y decisiones abiertas
- La plantilla de Windows de Godot tiene 6 huecos de icono: el .exe lleva 16, 32, 48, 64, 128
  y 256 (sin 24). El instalador y los accesos de Velopack llevan los 7.
- Con `modify_resources` Godot escribe la versión en el .exe; las compilaciones locales llevan
  `-dev+commit` y exportan sin error.

## Cierre
