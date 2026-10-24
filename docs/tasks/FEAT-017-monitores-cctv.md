# FEAT-017 — Monitores CCTV en la garita

- **Estado**: hecha
- **Diseño**: `docs/gdd/systems/interaction.md`, parte M (aprobado el 2026-10-24)
- **Hito del PoC**: H3
- **Rama**: `feat/017-monitores-cctv`

## Objetivo
Que un guardia pueda sentarse en la garita a mirar las 3 cámaras. A cambio se queda quieto y ciego al mundo. Las cámaras solo ven al ladrón si está iluminado, y unos pilotos rojos le avisan de que alguien mira.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | `interact` ante la mesa entra en «mirando» tras `monitor_enter_time`. Se sale con `interact`, con cualquier movimiento (ese primer input no mueve) o al acabar la partida. Hay una sola silla: con la mesa ocupada, el otro guardia lee «ocupado» (M1, invariante 4) | `tests/unit/test_cctv.gd` |
| 2 | El HUD del guardia que mira muestra las 3 imágenes en fila: 4:3, alto `feed_height_frac`, CRT, rótulo y marco rojo si esa cámara detecta. La tablilla de ronda sigue visible (M2) | `test_cctv_feeds.gd` y captura |
| 3 | Mirando, ni la linterna ni la luz detectan al ladrón; la proximidad sí, con su arco ciego (M3) | `test_cctv.gd` |
| 4 | Piloto rojo encendido en las 3 cámaras ⇔ algún guardia mirando, también en los clientes (M4, invariante 5) | `test_cctv.gd` y partida en red |
| 5 | Una cámara solo detecta al ladrón iluminado por una lámpara o por el haz de una linterna (M5, invariante 3) | `test_cctv.gd` |
| 6 | El servidor envía el ladrón a un guardia que mira, marcado `cctv_only`, si alguna cámara lo detecta. El cliente lo dibuja solo en las imágenes (capa de render propia y sin sombra). Un guardia que no mira no lo recibe nunca por las cámaras (M6, invariantes 1-2) | `test_cctv.gd`, partida en red con `--net-test=cctv` y captura |
| 7 | La IA solo atiende `thief_spotted` de una cámara si su guardia está mirando (M7) | `test_cctv.gd` |
| 8 | Las cámaras solo barren y detectan en el servidor; los clientes siguen el giro replicado | partida en red |

## Contratos
- `CCTVRules` (`src/systems/cctv_rules.gd`) y `data/balance/cctv_rules.tres`: `monitor_enter_time` (0,4) y `feed_height_frac` (0,40).
- `SecurityCamera3D`:
  - grupo `security_camera`;
  - `camera_label: String`;
  - `is_recording: bool` y `set_recording(on)`;
  - estado de red `{"alert", "rot_y", "rec"}`.
- `CCTVDesk3D` (`src/systems/cctv_desk_3d.gd`, `Area3D`):
  - grupo `cctv_desk`, `is_occupied()`, `watcher`;
  - interactuable;
  - estado de red `{"occupied"}`;
  - en el JSON del nivel, `"cctv_desk": {"pos", "rot_deg"}`.
- `GuardController3D`:
  - `monitor_watch: GuardMonitorWatch` (`start(desk)`), `is_watching_monitors()` y `stop_watching()`;
  - estado propio de red con `"watch"` (0 nada, 1 sentándose, 2 mirando).
- `ThiefController3D.set_view_mode(mode)`, con `ViewMode.HIDDEN`, `ViewMode.WORLD` y `ViewMode.CCTV`. `CCTV` pone las mallas en la capa de render `CCTV_ONLY_LAYER` (20) y quita las sombras. La cámara principal del mapa no incluye esa capa.
- `NetVisibility.guard_views(guards, cameras_detect)` → `{rol: &"world" | &"cctv" | &""}`.

| Dato | Autoridad | A quién | Frecuencia |
|---|---|---|---|
| `occupied` de la mesa | servidor | todos | al cambiar |
| `rec` de cada cámara | servidor | todos (el ladrón ve los pilotos) | al cambiar |
| `watch` del guardia | servidor | solo su dueño (estado propio) | 60 Hz |
| ladrón `cctv_only` | servidor | solo el guardia que mira, si una cámara lo detecta | 20 Hz |

## Fallos previos corregidos de paso
- El rayo de visión de la cámara salía de dentro de su propio modelo y chocaba con su colisión: las cámaras no podían detectar nunca. Ahora el rayo excluye el cuerpo de la cámara.
- La cámara interna y el foco del cono estaban 0,48 m por detrás del objetivo (el modelo va de z −0,5 a 0): cada imagen salía tapada por la carcasa. Ahora están 0,55 m por delante.

## Riesgos y decisiones abiertas
- Las imágenes son las mismas SubViewport de 320 × 240 que ya alimentan los monitores del mundo, escaladas. Si se ven demasiado borrosas, se sube la resolución.
- La sensación (tamaño, CRT y retardo al sentarse) se enseña al usuario con una captura antes de pulirla.
- Para capturas sin pantalla, las SubViewport de las cámaras solo se redibujan con `RenderingServer.force_draw()`. Sin eso, la imagen se queda congelada y parece que el ladrón no sale.

## Cierre
2026-10-24, PR #62. `reviewer` encontró un bloqueante: las cámaras no barrían en los clientes, porque `NetSessionClient` apaga `_physics_process` en `net_state`. Lo corregí siguiendo el giro en `_process` y lo verifiqué en red (el giro varía en ambos clientes). También apliqué estas sugerencias:
- el botín en manos sigue el modo de vista al cogerlo o soltarlo;
- los pilotos se encienden solo al estar mirando;
- la IA levanta al guardia que retoma;
- la fila de imágenes cabe fuera de 16:9;
- la linterna propia apunta a la mesa;
- el NaN del shader;
- `GuardSenses.has_line_of_sight` pública.

De paso, los monitores del nivel miraban a la pared porque el modelo muestra la pantalla hacia +Z. Tests: 192/192.

Backlog:
- decidir si sentado se puede usar la porra (pregunta al usuario);
- test de `on_snapshot` → `ViewMode`, hoy cubierto por la partida en red.
