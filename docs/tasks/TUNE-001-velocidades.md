# TUNE-001 — Guardias más lentos (3,0 / 2,0 / 5,5) y ladrón corriendo a 6,0

- **Estado**: aprobada (decisión del usuario en la entrevista del playtest 2, 2026-11-05; issue #166)
- **Sistema**: `docs/gdd/systems/stealth.md` (modos de movimiento) y, por los ejemplos con m/s, `docs/gdd/systems/heist.md` (R5d, R7b, R7c y la tabla de números)
- **Evidencia**: playtest 2 (2026-11-05). El usuario decidió las velocidades en la entrevista; no hay informe de `/balance` ni telemetría previa.

Una `TUNE` solo cambia valores de `.tres` dentro del rango que declara el documento del sistema. Tres valores quedaban fuera de los rangos de `stealth.md`; como los decidió el usuario, los rangos se han movido en el documento (citando el anterior y «TUNE de #166, decidido por el usuario»). No cambia ninguna regla.

## Cambios
Velocidad = `walk_speed` × ratio del modo (`MovementProfile.speed_for`). La linterna del guardia humano fuerza el modo sigilo (`GuardController3D.simulate_movement`), así que su velocidad barriendo es la de sigilo. Igual para guardias humanos y de IA (comparten `movement_guard.tres`).

| Recurso `.tres` | Campo | Actual | Nuevo | Rango del documento | Motivo |
|---|---|---|---|---|---|
| `data/balance/movement_guard.tres` | `walk_speed` | 4,2 | **3,0** | 2,6-3,4 m/s (antes 3,8-4,6) | Guardia andando a 3,0 m/s (#166). |
| `data/balance/movement_guard.tres` | `sneak_ratio` | 0,48 | **0,6667** | el que dé 1,8-2,2 m/s; con 3,0, 0,60-0,73 (antes 0,40-0,55) | Guardia con la linterna (y en sigilo manual) a 2,0 m/s, como antes (4,2 × 0,48 = 2,016). Se fija la velocidad absoluta: si cambia `walk_speed`, `sneak_ratio` = 2,0 / `walk_speed`. |
| `data/balance/movement_guard.tres` | `sprint_ratio` | 1,5 | **1,8333** | 1,70-1,90, < `sprint_mult` (antes 1,40-1,60) | Guardia corriendo (solo con alarma) a 5,5 m/s (antes 6,3). |
| `data/balance/movement_thief.tres` | `sprint_ratio` | 1,5 | **1,2** | 1,15-1,30 (antes 1,40-1,60) | Ladrón corriendo a 6,0 m/s (antes 7,5). |

Sin cambios: ladrón andando 5,0 (`walk_speed`) y en sigilo 2,4 (`sneak_ratio` 0,48); agachado 2,0 (`crouch_ratio` 0,4).

### Velocidades resultantes (m/s)
| | Sigilo / linterna | Paso | Carrera |
|---|---|---|---|
| Guardia, antes | 2,016 | 4,2 | 6,3 (solo con alarma) |
| Guardia, después | **2,0** | **3,0** | **5,5** (solo con alarma) |
| Ladrón, antes | 2,4 | 5,0 | 7,5 |
| Ladrón, después | 2,4 | 5,0 | **6,0** |

Ladrón corriendo con botín (`heist.md` R3, `loot_slow` 0,05 por pieza, mínimo 0,7): 1 pieza 5,7; 2 piezas 5,4; 3 piezas 5,1; 4 piezas 4,8 (antes 7,1 / 6,8 / 6,4 / 6,0).

## Contraste con el diseño
**Invariantes de `stealth.md`** (se cumplen todos):
- 1, orden de marchas: guardia 2,0 < 3,0 < 5,5; ladrón 2,4 < 5,0 < 6,0.
- 2, ningún modo domina: la velocidad sigue creciendo con el ruido (`g_modo` 0,3 / 1 / 2,0) en los dos bandos.
- 4, correr hace más ruido por metro: `sprint_mult` 2,0 > 1,8333 (guardia) y > 1,2 (ladrón). **Margen estrecho en el guardia**: `sprint_mult` ya no puede bajar de ~1,84 (su rango 1,6-2,2 queda en la práctica en 1,9-2,2; anotado en `stealth.md`).
- 5, agachado: el guardia no se agacha; su `crouch_ratio` 0,4 < 0,6667 igualmente.
- 22, vúmetro: solo depende del ladrón en sigilo y agachado, que no cambian.

**Cadencia de pasos** (sale de la animación): guardia andando 0,28 s entre pisadas (antes 0,20); en sigilo o barriendo 0,33 s; corriendo 0,18 s. Ladrón sin cambios (andar y correr siguen saturados a ×3: 0,18 s). El guardia andando suena con menos pisadas por segundo; el radio de cada una no cambia.

**`heist.md`, cuenta atrás de las rejas (R7b, `lockdown_time` 30 s, bajan a los 28,5 s)**:
- El ladrón desde lo más lejos (~45 m) a una salida: sin botín 7,5 s; con 3 piezas 8,8 s; con 4, 9,4 s; con el mínimo de velocidad, 10,7 s. **Llega de sobra**; le quedan ~18-20 s para decidir (antes ~21). La huida rápida (+2 por segundo que sobra) baja unos 4 puntos en el peor caso.
- La IA que va a cubrir una salida: la estamina del guardia (100, gasta 35/s, recupera 20/s, corta en 5; constantes en `guard_controller_3d.gd`, no en `.tres`) da ~2,7 s de carrera seguida (~15 m a 5,5) y luego alterna carrera y paso a ~3,9 m/s de media (estimación a partir del código; antes ~5,0). Garita → P02 (~45 m): **~10 s** (antes ~8). **Llega a tiempo** (28,5 s); la conclusión de R7b («cada guardia cubre una salida, 2-3 no cubren las 4») no cambia.
- Aviso final (`lockdown_warn_at` 10 s): a 5,1 m/s son ~50 m, más que la ruta más larga (~45 m). Sigue valiendo.
- R7c, reparar una caja con las rejas cerradas: ~8-10 s de carrera (antes ~7) más 8 s de reparación. El sabotaje compra unos segundos más de huida por salida.

**`heist.md`, sueño, café y patrulla**: el sueño sube por tiempo fuera de la garita, no por distancia, así que los bostezos y cabezadas llegan a la misma hora; lo que cambia es que en esos 3 minutos un guardia andando cubre ~540 m en vez de ~756 m (un 29 % menos de salas). Con el café (`fresh_time` 60 s), ir andando al ala más lejana (~60 m) cuesta 20 s en vez de ~14: sigue cabiendo. La IA patrulla igual (`ai_room_dwell` 4 s por sala); visita menos salas por minuto y su parada pesa más en su tiempo. `guard_patrol.tres` y `vision.md` no tienen tiempos que dependan de la velocidad.

**Asimetría (pilar 4)**:
- En calma el ladrón andando (5,0) saca 2 m/s al guardia (3,0): el ladrón decide el ritmo, como pide R5d.
- El ladrón en sigilo (2,4) sigue alejándose de un guardia que barre con la linterna (2,0), como antes (2,016). El guardia andando sigue alcanzando al ladrón en sigilo, pero solo por 0,6 m/s (antes 1,8).
- Persecuciones con alarma: el ladrón sin botín corre más (6,0 > 5,5) y, con 1 pieza, también (5,7). **Con 2 piezas o más, el guardia es más rápido mientras le dura la estamina** (antes solo con 4 piezas). En esos ~2,7 s gana como mucho ~1,1 m a un ladrón con 3 piezas y ~1,4 m a uno que anda (antes ~3,5 m): la captura en abierto depende más de cortar el paso que de correr. Después, a ~3,9 m/s de media, el guardia pierde terreno incluso con el ladrón andando.
- Para el ladrón, correr ya solo da un 20 % más de velocidad (antes un 50 %) a cambio de doblar el radio del paso: andar con alarma pasa a ser una opción real.

Ninguno de estos números hace imposible una regla. Lo que hay que vigilar son las capturas con alarma (pueden bajar) y que correr deje de compensar al ladrón.

## Cómo sabremos si funcionó
Preguntas del próximo playtest y eventos de telemetría (`stealth.md` y `heist.md`, «Qué medir»):
1. **Capturas con alarma**: cuántas persecuciones tras la alarma acaban en golpe o captura y cuántas en despiste o huida (`thief_sprint(duration, escaped)`, `melee_attempt`). Alarma si más del 80 % acaban en huida (los guardias no pillan a nadie) o menos del 20 % (correr ya no salva al ladrón). Hay que anotar cuántas piezas llevaba: con 2 o más, el guardia es más rápido unos segundos.
2. **Huidas a la carrera**: tiempo desde la alarma hasta la huida y segundos de cuenta atrás que sobran (`thief_fast_escape`); finales «ENCERRADO» frente a «HUIDA A MEDIAS». Debería bajar un poco el margen (unos 2 s) sin que crezcan los «ENCERRADO» por no llegar.
3. **IA cubriendo salidas**: segundos desde la alarma hasta que cada guardia de IA llega a su salida. Debe ser < 20 s (deja margen antes de los 28,5 s); con la estimación, ~10 s.
4. **Linterna frente al sigilo**: un guardia barriendo (2,0) y un ladrón en sigilo (2,4) en la misma sala. ¿El ladrón puede salir del haz sin correr? ¿El guardia siente que la linterna lo deja «clavado»? Pregunta al guardia humano.
5. **Ritmo en calma**: ¿el guardia andando a 3,0 se siente lento o pesado? ¿Cuántas salas recorre entre café y café? (`step_noise` por modo: si el guardia pasa > 70 % del tiempo en paso sin cubrir el ala, el ritmo es lento de más.)
6. **Uso de la carrera del ladrón**: parte del tiempo de movimiento en carrera (`step_noise(team, mode, …)`); si cae por debajo del 5 %, correr ya no compensa el ruido.

Si las capturas con alarma se desploman, el mando natural es la estamina del guardia, que hoy son constantes en `guard_controller_3d.gd`: pasarla a `movement_guard.tres` sería una tarea aparte (backlog), no esta TUNE.

## Verificación
- `./tools/ci/run_tests.sh` en verde. Si un test falla por comprobar un valor literal en vez de una relación, el test está mal: se reporta para corregirlo en otro paquete.
- Línea añadida a `docs/gdd/balance-changelog.md`.
