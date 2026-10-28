# FEAT-030 — Audio: música de fondo, volúmenes y sonidos de verdad

- **Estado**: hecha
- **Diseño**: `n/a — audio`. Lo pidió el usuario el 2026-10-28: «assets de audio más decentes, una música ligera de fondo bajita y opciones de audio en el menú».
- **Hito del PoC**: antes del playtest
- **Rama**: `feat/030-audio`

## Objetivo
Que el juego suene a juego: una música tranquila de fondo que no tape los pasos, volúmenes separados y grabaciones reales en lugar de sonidos sintéticos.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Buses Master, Music y SFX (`default_bus_layout.tres`). Los efectos (ruidos, hoja de ronda e interfaz) van a SFX y la música, a Music | `test_buses_exist` y script (buses `Master`, `Music`, `SFX`) |
| 2 | En Opciones hay volumen general, de música y de efectos. Se guardan y se aplican al momento; la música empieza al 40 % | `test_music_and_sfx_volumes_are_saved_and_applied` y `test_options_panel_has_three_sliders` |
| 3 | Música en bucle que cambia con un fundido: «Coffee Black» en el menú (-10 dB) y «Espionage» en la partida (-16 dB, más baja). No suena en el servidor dedicado | `test_track_per_scene` y script (pista correcta y `playing=true`) |
| 4 | El bostezo es una grabación real; la cafetera tiene su sonido (categoría `coffee`) | `test_coffee_and_yawn_have_sound` |
| 5 | Licencias y autores en `assets/audio/CREDITS.md`, el README y el LEEME de los paquetes | archivos |

## Contratos
- Autoload `Music` (`MusicPlayer84`): `play(track, volume_db)` y `track_for(scene)`. Va en su propio commit de `project.godot`.
- `GameSettings`: `music_volume`, `sfx_volume` y `set_bus_volume(bus, volume)`.
- `NoiseMix`: categoría `coffee`.

## Riesgos y decisiones abiertas
- No he podido escuchar las pistas: las elegí por su descripción y licencia. Si alguna no encaja, se cambia en `music_player_84.gd`.
- Se retiran los bostezos sintéticos de FEAT-029 y su script.

## Cierre
2026-10-28.
