# FEAT-018 — Menú principal

- **Estado**: en curso (prototipo enseñado al usuario)
- **Diseño**: `n/a — interfaz`. Lo pidió el usuario el 2026-10-24: «algo bonito y profesional, el título del juego, un modo offline, un modo multijugador, opciones y mi nombre en un sitio discreto».
- **Hito del PoC**: H3
- **Rama**: `feat/018-menu-principal`

## Objetivo
Un menú de entrada con aspecto de juego terminado antes de la primera partida con amigos, que lleve a una partida contra la IA, al lobby o a las opciones.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Logo «Velvet» (neón manuscrito) sobre «HEIST '84», con el lema; fondo nocturno con zoom lento, oscurecido a la izquierda, con grano y líneas de barrido | captura |
| 2 | Entradas Un jugador, Multijugador, Opciones y Salir: se encienden al pasar el ratón o el foco, tienen una línea de ayuda y un clic; se navega con teclado o mando | `tests/unit/test_main_menu.gd` y captura |
| 3 | Un jugador: lista de mapas (Museo '84 primero, Villa Belmonte), ficha con miniatura y botón Empezar | `test_main_menu.gd` y captura |
| 4 | Opciones: pantalla completa, VSync y volumen general, aplicados y guardados en `user://settings.cfg`; el menú los aplica al arrancar | `test_main_menu.gd` |
| 5 | El lobby usa el mismo tema, con letra legible y textos claros («Elige bando», «1 ladrón contra 2 guardias») | `test_main_menu.gd`, `test_lobby_view.gd` y captura |
| 6 | «Un juego de Óscar Suárez», discreto, abajo a la derecha | `test_main_menu.gd` y captura |
| 7 | Se borra el mapa del gimnasio de pruebas (petición del usuario) | el test de regresión usa el museo v2 |

## Contratos
- `MenuTheme84`: paleta, tipografías (`assets/fonts/`, OFL; créditos en `assets/fonts/CREDITS.md`) y `build() -> Theme`.
- `GameSettings`: `load_saved(path)`, `save(path)` y `apply()`.
- `MainMenu.open_section(id)`, con `&"single"`, `&"multi"`, `&"options"` o `&"quit"`.

## Riesgos y decisiones abiertas
- La miniatura del museo v2 (`assets/ui/thumb_museum_v2.png`) es un render propio de la maqueta gris; se rehace al vestir el museo.

## Cierre
