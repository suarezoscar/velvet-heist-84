# FEAT-005 — Mecánicas de Sigilo Avanzadas, Posturas y Rigging de Personajes '84

- **Estado**: hecha parcialmente (auditoría de la Fase 1, 2026-10-22: `docs/decisions/2026-10-22-fase-1-auditoria.md`)
- **Responsable**: gameplay-engineer, technical-artist y vfx-ui-engineer  **Revisor**: lead-architect
- **Fase del GSD**: 3 (Mecánicas de sigilo, animaciones Mixamo y gadgets analógicos)

## Objetivo
Elevar la jugabilidad de sigilo e inmersión estética de *Velvet Heist '84* al estándar neo-noir de 1984, sustituyendo los personajes geométricos provisionales por los modelos riggeados definitivos (**Crypto** para el Ladrón y **SWAT** para los Guardias) e implementando un sistema completo de posturas tácticas (`STAND`, `TIPTOE`, `CROUCH`, `PRONE` y `WALL_COVER`) con colisión dinámica, modulación acústica y animación esqueletal.

## Alcance y fuera de alcance
- **Dentro**:
  1. **Sustitución de mallas en escenas de personajes**:
     - `scenes/entities/thief_player.tscn`: instancia `assets/models/characters/thief_crypto.glb` bajo el nodo `VisualRoot`.
     - `scenes/entities/guard_player.tscn`: instancia `assets/models/characters/guard_swat.glb` bajo el nodo `VisualRoot`.
     - Reubicación precisa de anclas: `CarryAnchor3D` (manos del ladrón) y `MagliteSpotLight` (pecho/mano del guardia).
  2. **Máquina de Estados de Postura (`StanceState`) en `PlayerBase3D`**:
     - `STAND`: Altura de cápsula 1.6m, velocidad 100%, ruido de pasos base x1.0 (sprint x1.8).
     - `TIPTOE`: Altura 1.6m, velocidad reducida (2.0 m/s), multiplicador de ruido acústico x0.0 (paso totalmente inaudible).
     - `CROUCH`: Altura de cápsula reducida a 1.0m (y offset a 0.5m), velocidad x0.55 (2.4 m/s), ruido x0.35. Permite ocultarse tras vitrinas y mesas bajas.
     - `PRONE`: Cápsula horizontal de 0.40m de altura, velocidad x0.25 (1.2 m/s), ruido x0.0. Permite deslizarse bajo los haces de alarmas láser o conductos estrechos.
     - `WALL_COVER`: Adherencia magnética a muros (< 0.6m); orienta la espalda al muro y restringe el movimiento al eje tangencial, permitiendo asomarse a las esquinas.
  3. **Controlador de Animaciones `CharacterAnimator3D`**:
     - Conectar automáticamente con el `AnimationPlayer` de los nuevos `.glb`.
     - Soporte para las 11 animaciones: `walk`, `tiptoe_walk`, `sneak_walk`, `crouch_walk`, `crouch_to_prone`, `prone_idle`, `prone_forward`, `taking_cover_idle`, `cover_idle`, `cover_sneak_left`, `cover_sneak_right`.
     - Transiciones fluidas con cross-fade (blend time 0.15s - 0.25s).
  4. **Sincronización en Red**:
     - Replicación del estado de postura (`current_stance`) a través de `NetManager` y snapshots autoritativos.
     - Validación en el servidor de la altura de colisión física (prevención de desincronización y trampas al pasar por zonas bajas).
  5. **HUD de Postura Analógico**:
     - Indicador visual en `HUD84` mostrando la postura actual en tipografía ámbar/verde de fósforo estilo 1984.
  6. **Suite de Tests Unitarios con GUT**:
     - `tests/unit/test_stealth_mechanics.gd` verificando dimensiones de cápsula, factores de ruido por postura y transiciones de estado.

- **Fuera**:
  - Takedowns cuerpo a cuerpo con animaciones cinemáticas complejas (se mantiene neutralización con porra autoritativa).
  - Escalada vertical / parkour por tuberías.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Las escenas `thief_player.tscn` y `guard_player.tscn` utilizan `thief_crypto.glb` y `guard_swat.glb` respectivamente, con pivotes alineados y 0 errores de importación | inspección de escena y ejecución headless |
| 2 | `PlayerBase3D` implementa el enum `Stance` (`STAND`, `TIPTOE`, `CROUCH`, `PRONE`, `WALL_COVER`) y ajusta la altura de `CollisionShape3D` entre 1.6m (`STAND`), 1.0m (`CROUCH`) y 0.4m (`PRONE`) | tests en `test_stealth_mechanics.gd` |
| 3 | El modo `TIPTOE` emite 0.0 de radio de ruido de pasos al desplazarse sobre cualquier superficie | test unitario con `SurfaceDetector3D` y `SignalBus` |
| 4 | En modo `PRONE`, el AABB vertical del personaje es inferior a 0.50m, permitiendo cruzar bajo un rayo láser situado a 0.60m sin activar colisión | test de penetración de rayo láser |
| 5 | En modo `WALL_COVER`, el personaje detecta un muro a < 0.6m con RayCast, alinea su orientación paralela al muro y mapea el desplazamiento lateral con `cover_sneak_left`/`right` | test de proyección de normales y cinemática |
| 6 | `CharacterAnimator3D` reproduce las 11 pistas de animación según la postura y velocidad sin arrojar warnings de animación no encontrada | log de ejecución y test de estados de animación |
| 7 | Todos los 56 tests anteriores de FEAT-000 a FEAT-004 continúan pasando al 100% en verde con código de salida 0 | salida de `./tools/ci/run_tests.sh` |

## Contratos
### Enum `Stance` en `src/entities/player_base_3d.gd`
```gdscript
enum Stance {
	STAND = 0,
	TIPTOE = 1,
	CROUCH = 2,
	PRONE = 3,
	WALL_COVER = 4,
}
```

### Métodos públicos y señales en `PlayerBase3D`
- `signal stance_changed(old_stance: Stance, new_stance: Stance)`
- `func set_stance(new_stance: Stance) -> void`
- `func get_stance() -> Stance`
- `func can_enter_stance(target_stance: Stance) -> bool`
- `func get_stance_speed_multiplier() -> float`
- `func get_stance_noise_multiplier() -> float`

### Parámetros de Colisión por Postura
| Postura | Altura Cápsula (`height`) | Radio (`radius`) | Centro Y (`transform.origin.y`) |
|---|---|---|---|
| `STAND` / `TIPTOE` | 1.60 m | 0.35 m | 0.80 m |
| `CROUCH` | 1.00 m | 0.35 m | 0.50 m |
| `PRONE` | 0.40 m | 0.30 m | 0.20 m |
| `WALL_COVER` | 1.60 m | 0.25 m | 0.80 m |

### Parámetros de Velocidad y Acústica
| Postura | Mult. Velocidad | Mult. Ruido de Pasos | Pistas de Animación |
|---|---|---|---|
| `STAND` | 1.00 (sprint x1.5) | 1.00 (sprint x1.8) | `Armature|mixamo.com|Layer0`, `walk` |
| `TIPTOE` | 0.45 (2.0 m/s) | 0.00 | `tiptoe_walk` |
| `CROUCH` | 0.55 (2.4 m/s) | 0.35 | `crouch_walk`, pose agachada |
| `PRONE` | 0.25 (1.2 m/s) | 0.00 | `crouch_to_prone`, `prone_idle`, `prone_forward` |
| `WALL_COVER` | 0.40 (1.8 m/s) | 0.15 | `taking_cover_idle`, `cover_idle`, `cover_sneak_left`, `cover_sneak_right` |

## Assets necesarios
- `assets/models/characters/thief_crypto.glb` (Integrado en FEAT-005, 1.80m, 11 animaciones).
- `assets/models/characters/guard_swat.glb` (Integrado en FEAT-005, 1.82m, 11 animaciones).

## Impacto en red
- La postura actual `current_stance` se replica como entero (`uint8`) en los paquetes de simulación periódica (20 Hz).
- El servidor autoritativo valida si hay espacio físico superior suficiente antes de permitir pasar de `PRONE` o `CROUCH` a `STAND` (mediante un ShapeCast3D hacia arriba) para evitar que un jugador quede atrapado o atraviese techos bajos.

## Reparto y orden
1. **lead-architect**:
   - Aprobar la especificación FEAT-005.
   - Definir los bindings de input en `project.godot` para `crouch`, `prone` y `cover`.
2. **technical-artist**:
   - Actualizar las escenas `thief_player.tscn` y `guard_player.tscn` enlazando los nuevos `.glb` bajo `VisualRoot`.
   - Ajustar colisiones base y anclas `CarryAnchor3D` y `MagliteSpotLight`.
3. **gameplay-engineer**:
   - Implementar la lógica de `Stance` y ajuste dinámico de cápsula en `PlayerBase3D`.
   - Actualizar `CharacterAnimator3D` para las 11 animaciones.
   - Implementar la detección y desplazamiento en `WALL_COVER`.
   - Crear y pasar la suite de tests en `tests/unit/test_stealth_mechanics.gd`.
4. **vfx-ui-engineer**:
   - Añadir indicador de postura táctica en `HUD84`.
5. **lead-architect**:
   - Revisión completa de código e integración final con `/review`.

## Riesgos y decisiones abiertas
- *Transición de Prone a Stand bajo techos bajos*: Si el jugador intenta levantarse mientras está debajo de una mesa o conducto, el ShapeCast3D hacia arriba debe cancelar la transición y mantenerlo agachado/tumbado hasta que salga al espacio despejado.
- *Animación de Idle de Mixamo*: El T-pose base (`Armature|mixamo.com|Layer0`) puede relajarse mediante un blend suave o usando los primeros fotogramas en reposo de `taking_cover_idle` o `tiptoe_walk` cuando la velocidad sea < 0.1 m/s.
