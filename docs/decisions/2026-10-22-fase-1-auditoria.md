# Fase 1 — Auditoría de FEAT-000 a FEAT-005

Auditoría con `reviewer` en modo auditoría sobre `master` en `e89a8f9`, con tres revisores en paralelo (000+001, 002+003, 004+005). La suite completa se ejecutó una vez antes, en el mismo commit: 12 scripts, 88 tests, 88 pasan, 1036 asserts. Los revisores no ejecutaron Godot ni Blender, para no pisarse la caché `.godot`, así que lo que exige el motor (importación limpia, servidor headless, ejecución de `bpy`) queda sin evidencia reproducida.

## Veredicto

| FEAT | Veredicto | Lo esencial |
|---|---|---|
| 000 Línea base | hecha parcialmente | Tests que no prueban el código del juego (botín pesado, proximidad). `import.sh` no falla ante errores. Ninguna ejecución de CI en verde registrada. |
| 001 Validador de assets | hecha parcialmente | Validador más laxo que la FEAT. Previews en blanco. Sin informe de los 8 assets principales. `gen_museum_level.py` no usa la paleta. |
| 002 Preparación para red | hecha parcialmente | La separación input/simulación/presentación existe. Las cuatro decisiones de arquitectura (servidor autoritativo, filtrado, eventos fiables, reconciliación) no se cumplen. |
| 003 Lobby y sincronización | hecha parcialmente | Autoridad del cliente sobre su personaje. Botín, reloj y partida sin red. Dos bugs que rompen el online. Ningún test con dos peers reales. |
| 004 Gadgets | hecha parcialmente | Los 5 `.glb` en `pass`, pero previews vacías, sin `source` y dimensiones forzadas con escalado no uniforme. |
| 005 Posturas y rigging | hecha parcialmente | Posturas con tests, pero sin red, sin HUD, TIPTOE no se puede activar y WALL_COVER no exige muro. Choca con los pilares 2, 3 y 4. |

Ninguna FEAT tiene registro de revisión independiente ni evidencia de `/verify`: el "aprobada por lead-architect" no tiene respaldo bajo el flujo v2.

## Bugs que afectan al juego hoy

1. **Porra online**: un guardia de un cliente solo golpea una vez por partida. En el servidor es `is_remote_puppet()`, así que no ejecuta `simulate_movement` y `baton_cooldown` nunca baja (`player_base_3d.gd:109-111`, `guard_controller_3d.gd:60-61,161`). La captura online es imposible.
2. **`guard_3` controla al ladrón**: el lobby ofrece el rol, el museo tiene dos guardias y `match local_role` cae en `_:` → ladrón (`museum_velvet_84.gd:56-62,97-102`).
3. **Servidor dedicado sin forma de lanzar la partida**: arranca en `main_menu.tscn` y `launch_match` solo lo dispara el botón del host (`main_menu.gd:298-302`).
4. **Acústica de suelos probablemente inerte** (sin verificar en el motor): en la mansión el metadato está en el `Node3D` raíz y `SurfaceDetector3D` lo lee del collider, así que devolvería 1,0. Además los valores están trocados respecto al GSD: alfombra 0,4, parqué 1,2 y mármol 1,6, frente a 0,2, 1,5 y 1,2 (`mansion_belmonte.tscn:1558-1690`).
5. **WALL_COVER sin muro**: `can_enter_stance` no lo exige y la detección es a 0,7 m, no a 0,6 m (`player_base_3d.gd:261,372,421`).
6. **Agacharse no oculta**: la percepción usa el torso a 0,9 m fijos (`guard_controller_3d.gd:112`).
7. **Proximidad de 1,8 m que en realidad es ~1,70 m** con los dos en el suelo (ojos a 1,5 m, torso a 0,9 m). Los tests lo ocultan levantando al ladrón (`test_thief_visibility.gd:61,73,84`).
8. **Fuga de información al guardia**: la mirada del ladrón se reenvía sin filtro y `set_stealth_visibility` fuerza `visible = true` (`museum_velvet_84.gd:147-148,186-189`, `thief_controller_3d.gd:129-130`).

## Tests que no prueban lo que dicen

- Botín pesado ×0,8: el test reimplementa la multiplicación y nunca llama a `simulate_movement()` (`test_loot_weight.gd:91-115`).
- Ruido por superficie: comprueba un metadato que pone el propio test (`test_surface_detector_noise.gd`).
- TIPTOE silencioso: llama a `_emit_step_sound()` sin suelo, y las aserciones se saltan si falta el autoload (`test_stealth_mechanics.gd:163-196`).
- Autoridad de input: el guardia ya tiene `is_locally_controlled=false`, así que pasaría sin la comprobación (`test_multiplayer_lobby.gd:141`, `test_global_gameplay_loop.gd:346`).
- "Dos instancias por loopback": un solo proceso con un `ENetMultiplayerPeer` suelto (`test_multiplayer_lobby.gd:244`).
- Importación de assets: la tolerancia `max(1 %, 0,015 m)` permite entre el 19 % y el 37 % en piezas pequeñas (`test_asset_import.gd:140-172`); faltan `floor_parquet` y `floor_marble`.
- `scenes/ui/test_lobby_ui.gd` está fuera de GUT, usa `assert()` y tiene una ruta absoluta.

## Decisiones de diseño pendientes (para `game-designer`)

- **Posturas frente a los pilares**:
  - TIPTOE y PRONE ×0,0 eliminan el sonido como información (pilar 2).
  - TIPTOE (2,0 m/s, ruido 0) domina a `sneak` (2,2 m/s, ×0,3) (pilar 4).
  - Las posturas están en `PlayerBase3D` y también las usan los guardias (pilar 3).
- **PRONE**: cápsula vertical de 0,4 × 0,4 m frente a la "horizontal" de la FEAT. Un cuerpo tumbado cabe por huecos irreales.
- **Números en conflicto con el GSD**: porra a 1,6 m frente a 1,5 m; ruido de sprint ×2,0 frente a ×1,8; velocidad de sprint ×1,56 frente a ×1,5; proximidad de 1,8 m medida en 3D o en horizontal.
- **Pilar 1, a revisar por el usuario**: el guardia es un modelo SWAT, no seguridad privada de los 80. La textura emisiva verde del ladrón puede leerse como visión nocturna.
- **Personajes Mixamo**: 29.012 tris (ladrón) y 19.450 tris (guardia), frente al máximo de 5.000 de la regla 02. Hay que decidir el presupuesto real o reducir las mallas.

## Huecos agrupados para specs

Cada grupo cita los huecos de los informes. Al escribir cada spec, los detalles con `archivo:línea` están en la sección de bugs y tests de arriba.

### A. CI fiable (integrator; pequeño, sin decisiones de diseño)
- `import.sh` falla si aparece `ERROR:` o `Failed loading resource`.
- Lanzar el workflow y registrar una ejecución en verde.
- Que `ci.yml` lea `GODOT_VERSION` de `godot_version.env`.
- Fijar la versión de Blender en `tools/ci/` y comprobarla en `validate_asset.py`.
- Que los tests de `test_validator.py` se ejecuten en CI, con un test de la CLI que compruebe el código de salida.

### B. Refactor de `PlayerBase3D` y balance a `.tres` (ya en la vía de ingeniería)
- `player_base_3d.gd` (586 líneas): posturas, cobertura y red a componentes.
- `main_menu.gd` (523) y `net_manager.gd` (345).
- Tests de más de 300 líneas.
- Errores de lint `class-definitions-order`.
- Números a `data/balance/` y tests que comprueben relaciones, no literales:
  - superficies, con un `.tres` que hoy existe pero nadie lee;
  - velocidades, porra, proximidad, reloj, posturas, cápsulas e intervalos de paso.
- Pasar los valores actuales sin cambiarlos; los ajustes que decida diseño irán como `TUNE`.

### C. Tests honestos (qa-engineer)
- Rehacer los tests de la sección anterior para que fallen si se quita el código que prueban.
- Bordes:
  - porra a 1,49 / 1,51 m;
  - proximidad a 1,79 / 1,81 m con los dos personajes en el suelo;
  - borde del cono;
  - WALL_COVER a 0,65 m.
- Caminar de verdad sobre los tres suelos en cada postura.
- Animador: que `stance_changed` dispare `crouch_to_prone` y `taking_cover_idle`, con `push_warning` si falta una pista.
- Pasar `test_lobby_ui.gd` a GUT.

### D. Mecánicas de sigilo locales (tras las decisiones de diseño)
- Acústica de suelos conectada de verdad, con un test que cargue el mapa.
- WALL_COVER solo con muro.
- La altura del torso según la postura en la percepción.
- TIPTOE con binding o eliminado, según diseño.
- HUD de postura (vfx-ui-engineer).

### E. Higiene de assets (technical-artist)
- Arreglar `render_preview.py`: los 13 PNG son transparentes. Añadir un check que falle si la imagen está vacía.
- Bloque `source` en todas las fichas y validador que lo exija.
- Validador más estricto:
  - paleta por valor y no solo por nombre;
  - `materials` de la ficha solo restringe;
  - tolerancias de ±1 % reales;
  - snake_case real.
- Quitar el escalado no uniforme de `gen_gadgets_assets.py:100-142`.
- Bisel proporcional en la regla 02, y `ChromeTrim` en su tabla.
- `gen_museum_level.py` con la paleta y sin ruta absoluta.
- Una sola carpeta de fichas (hoy duplicadas en `data/asset_specs/`), y un test de Godot guiado por ellas.
- JSON de validación de los 8 assets principales.
- Fichas de los personajes Mixamo; corregir `Soldier_body1.001`.

### F. Red autoritativa (vía de ingeniería, al final; el disfraz ya diseñado)
- El servidor simula a partir del input; el cliente predice y reconcilia.
- Red fuera del mapa, en `src/network/`, instanciada por `HeistMap3D`.
- Filtrado completo del ladrón: posición, mirada y visibilidad; resolver el caso del host que juega de guardia.
- Porra y captura en el servidor (bug 1).
- Botín por `request_interact`.
- Reloj de ronda y de partida autoritativos, y `game_ended`.
- Roles limitados a los guardias del mapa (bug 2).
- Arranque del servidor dedicado sin UI (bug 3).
- Desconexiones y confirmación de rol.
- Replicación de ruido y postura.
- Tests con un servidor headless y 2 clientes en `tools/ci/qa_*.sh`.

## Orden propuesto

1. **A (CI fiable)**: sin él, la Definición de hecho no se puede demostrar. Es pequeño y no depende de nada.
2. **Diseño con `game-designer`** (en paralelo con 1): las decisiones de la sección anterior. Ya estaba previsto como "revisión de posturas"; se amplía con los números y el pilar 1.
3. **B y C juntos**: el refactor mueve los números a `.tres` y los tests honestos lo vigilan. qa-engineer escribe los tests en su propio paquete.
4. **D**, cuando estén las decisiones de diseño.
5. **E**: independiente, puede ir en paralelo con 3 y 4.
6. **F**, en su sitio de la hoja de ruta. Los bugs 1 a 3 solo importan con partidas online, que todavía no se juegan. Si se quiere probar online antes, el bug 2 se puede arreglar aparte.
