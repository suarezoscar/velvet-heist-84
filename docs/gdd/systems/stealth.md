# Sigilo: modos de movimiento, ruido de pasos y percepción cercana

- **Estado**: aprobado por el usuario el 2026-10-22 (parte 1; el cono de linterna y la visibilidad de anillos entre guardias quedan para la parte 2).
- **Origen**: MASTER_GSD §2 (asimetría), §4.1 (acústica de superficies), §5.3 (visibilidad); FEAT-005 (posturas); auditoría de la Fase 1 (`docs/decisions/2026-10-22-fase-1-auditoria.md`, "Decisiones de diseño pendientes"). 2026-10-22.
- **Relacionado**: `characters.md` (altura de los modelos, que fija los puntos de visibilidad); `roles.md` (velocidades por rol), `gadgets.md` (molde de cera, hilo con campanillas, láseres) e `interaction.md` (cobertura baja de los niveles), que todavía no existen.
- **Alcance**: modos de movimiento, ruido de pasos, superficies, quién ve qué anillo (solo la regla), proximidad, puntos de visibilidad y alcance de la porra. **Segunda parte, pendiente**: el cono de la linterna, las lámparas y el detalle de la visibilidad de los anillos (colores, duración, ruido de objetos).

## Fantasía
- **Ladrón**: "Si me lo pienso, nadie me oye; si tengo prisa, todo el edificio se entera". Cada metro tiene un precio en tiempo o en ruido, y esconderse tras una vitrina es una decisión, no un truco gratis.
- **Guardias**: "Puedo acercarme sin avisar, pero eso me hace lento y el reloj de ronda no espera". Las botas y el manojo de llaves pesan más que las zapatillas del ladrón.

## Reglas

### Modos de movimiento
Un modo es la combinación de **marcha** (cuánto corre) y **altura** (cuánto asoma). Cada personaje está en un solo modo cada vez.

| Modo | Quién | Entrada | Altura | Notas |
|---|---|---|---|---|
| Paso (`walk`) | ambos | por defecto | de pie | Referencia: velocidad y ruido ×1. |
| Sigilo (`sneak`) | ambos | mantener `sneak` | de pie | Sustituye a TIPTOE. Puede reutilizar la animación `tiptoe_walk`. |
| Carrera (`sprint`) | ambos | mantener `sprint` | de pie | El guardia gasta estamina; el ladrón no (aplazado A3). |
| Agachado (`crouch`) | solo ladrón | alternar `crouch` | baja | Anula `sneak` y `sprint` mientras dura: es un modo, no un modificador que se suma. Más lento que el sigilo, mismo ruido, puntos de visibilidad bajos. |

- No existen otras posturas. TIPTOE se elimina; PRONE y WALL_COVER quedan aplazados (A1, A2). Los guardias no tienen `crouch`.
- `crouch` → de pie solo si hay espacio libre sobre la cabeza. Si no lo hay, el ladrón sigue agachado y el HUD lo indica.
- Con `sneak` y `sprint` pulsados a la vez gana `sneak` (la intención más prudente). Pulsar `sprint` agachado no hace nada.
- Cambiar de modo no emite ruido por sí mismo.

### Ruido de pasos
Cada paso emite `noise_emitted_3d` con este radio:

```
r_paso = max(r_min, R_base × g_modo × s_superficie × t_bando)
```

| Variable | Significado | Fuente |
|---|---|---|
| `R_base` | Radio de un paso normal en suelo neutro | `data/balance/step_noise.tres` → `base_radius` (nuevo) |
| `g_modo` | Multiplicador del modo (`walk` = 1) | `step_noise.tres` → `sneak_mult`, `sprint_mult`, `crouch_mult` (nuevos) |
| `s_superficie` | Multiplicador del suelo bajo los pies (1 si no hay dato) | `data/balance/surface_*.tres` → `noise_multiplier` |
| `t_bando` | Peso de botas y llaves | `data/balance/movement_thief.tres` / `movement_guard.tres` → `team_noise_mult` (nuevo; ladrón = 1) |
| `r_min` | Suelo del pilar 2: moverse nunca es silencio absoluto | `step_noise.tres` → `min_radius` (nuevo) |

- Rango de salida con los valores iniciales: de `r_min` (ladrón agachado o en sigilo sobre alfombra) a ~12,6 m (guardia corriendo por parqué). Con todos los mandos en su máximo de rango, ~23,8 m (4,5 × 2,2 × 1,6 × 1,5), más que el arranque del coche de huida (16 m): no se deben subir a la vez `base_radius`, `sprint_mult` y `team_noise_mult` hasta su techo.
- Ejemplos resueltos con los valores iniciales (`R_base` 3,5; `sneak` 0,3; `sprint` 2,0; guardia 1,2; superficies del GSD):
  - Ladrón en sigilo sobre parqué: 3,5 × 0,3 × 1,5 × 1,0 = **1,58 m**.
  - Ladrón agachado sobre alfombra: 3,5 × 0,3 × 0,2 × 1,0 = 0,21 → **0,5 m** (`r_min`).
  - Guardia andando sobre mármol: 3,5 × 1,0 × 1,2 × 1,2 = **5,04 m**.
- Parado no se emite ruido: no moverse no es una acción.
- La cadencia (un paso cada `step_interval` s) vive en el `.tres` de movimiento de cada bando, por modo.

### Quién ve qué anillo
- El **ladrón** ve todos los anillos de sonido del mapa, a través de muros (pilar 3).
- Un **guardia** ve un anillo solo si le alcanza: su distancia horizontal al origen es ≤ el radio del anillo.
- La **IA** de los guardias oye con la misma regla, sin factor extra: oye exactamente lo que dibuja el anillo.
- El detalle (si un guardia ve los anillos de sus compañeros fuera de su alcance, aspecto, duración) queda para la segunda parte.

### Superficies
- Cada tipo de suelo es un `.tres` en `data/balance/surface_<id>.tres`. Un nivel asigna a cada sala un **tipo de superficie**, nunca un número suelto.
- Orden obligatorio: alfombra < 1 ≤ mármol ≤ parqué (el parqué cruje y delata más que el eco del mármol, GSD §4.1).
- Un tipo nuevo (grava del exterior, linóleo de la sala de seguridad) se añade como otro `.tres` con su rango en este documento.

### Percepción cercana (proximidad) y puntos de visibilidad
- **Distancia horizontal**: la proximidad compara la distancia en el plano XZ entre los centros de guardia y ladrón con `proximity_radius`. La altura no entra en la distancia.
- **Arco ciego trasero**: la proximidad no cubre un arco de `rear_blind_arc_deg` centrado en la espalda del guardia. Ahí solo le avisa el oído.
- **Línea de visión**: además de la distancia y el arco, hace falta un rayo libre desde los ojos del guardia hasta **al menos uno** de los puntos de visibilidad del ladrón.
- **Puntos de visibilidad**: dos por altura (cabeza y pecho de pie; dos puntos bajos agachado). Los mismos puntos sirven para el cono de la linterna. De pie, la cabeza asoma sobre una vitrina; agachado, la vitrina oculta.

### Porra
- El golpe acierta si la distancia horizontal entre centros es ≤ `melee_range` y hay línea de visión de torso a torso.
- `melee_range` < `proximity_radius`: un guardia nunca golpea a quien no podría percibir de frente.

### Interacciones
- **Botín pesado**: multiplica la velocidad en todos los modos y no cambia el ruido (pendiente de `loot.md`). Se puede ir agachado con botín pesado.
- **Talco del guardia**: las huellas salen en cada paso, en cualquier modo.
- **Hilo con campanillas**: el GSD habla de "modo sigilo/agachado"; con este diseño, `sneak` y `crouch` del ladrón lo cruzan sin que suene. Lo confirmará `gadgets.md`.
- **Molde de cera**: es posible gracias al arco ciego, siempre que la distancia del molde sea < `proximity_radius`. Sus pasos se siguen oyendo: en parqué o mármol, el sigilo del ladrón llega a 1,2 m; en alfombra queda en `r_min`.
- **Silbato ("Nervioso")**: no cambia los modos.
- **Red**: el modo de cada personaje se replica; el servidor calcula los puntos de visibilidad a partir de él.

### Casos límite
- Agacharse bajo un techo bajo y querer levantarse: sigue agachado hasta que haya espacio.
- Cambiar de superficie a mitad de paso: cuenta la superficie bajo los pies en el instante del paso.
- Ladrón justo en el borde del arco ciego: cuenta el ángulo entre el frente del guardia y la dirección horizontal al centro del ladrón; el borde pertenece al arco visible.
- Captura durante `crouch`: la captura no depende del modo.
- Fin de partida en cualquier modo: sin efecto.

## Números
Los `.tres` marcados como nuevos los crea el paquete B (balance a `.tres`) con los valores actuales del código; los cambios respecto a lo actual entran después como `TUNE` o en la FEAT de mecánicas de sigilo.

| Mando | Recurso y campo | Tipo | Rango aceptable | Valor inicial y por qué |
|---|---|---|---|---|
| Paso del ladrón | `movement_thief.tres` → `walk_speed` (nuevo) | sensación | 4,5-5,5 m/s | 5,0 (actual). Más rápido que el guardia para que la huida sea posible. |
| Paso del guardia | `movement_guard.tres` → `walk_speed` (nuevo) | sensación | 3,8-4,6 m/s | 4,2 (actual). |
| Sigilo / paso | `movement_*.tres` → `sneak_ratio` (nuevo) | sensación | 0,40-0,55 | 0,48 (actual). Lento como para que cueste tiempo de reloj. |
| Carrera / paso | `movement_*.tres` → `sprint_ratio` (nuevo) | sensación | 1,40-1,60 | 1,5 en ambos bandos (hoy el guardia va a 1,48). |
| Agachado / paso (ladrón) | `movement_thief.tres` → `crouch_ratio` (nuevo) | sensación | 0,30-0,45, siempre < `sneak_ratio` | 0,40. Paga en velocidad lo que gana en perfil. |
| Cadencia de pasos | `movement_*.tres` → `step_interval_<modo>` (nuevo) | sensación | 0,25-0,75 s | `walk` 0,42, `sprint` 0,28, `sneak` 0,60, `crouch` 0,55. |
| Radio base del paso | `step_noise.tres` → `base_radius` (nuevo) | curva | 2,5-4,5 m | 3,5 (actual). |
| Ruido en sigilo | `step_noise.tres` → `sneak_mult` | curva | 0,20-0,40 | 0,3 (actual). |
| Ruido en carrera | `step_noise.tres` → `sprint_mult` | curva | 1,6-2,2, siempre > `sprint_ratio` | 2,0 (actual). Correr hace más ruido por metro que andar. |
| Ruido agachado | `step_noise.tres` → `crouch_mult` | curva | 0,25-0,40, = `sneak_mult` | 0,3. Igual que el sigilo: el agachado se diferencia en velocidad y perfil. |
| Radio mínimo en movimiento | `step_noise.tres` → `min_radius` (nuevo) | curva | 0,3-0,8 m | 0,5. Algo más que el radio de la cápsula (0,35): se ve, pero solo lo oye quien casi te toca. |
| Peso de botas y llaves | `movement_guard.tres` → `team_noise_mult` (nuevo) | curva | 1,0-1,5 | 1,2. El ladrón vale 1,0 fijo. |
| Alfombra | `surface_carpet.tres` → `noise_multiplier` | curva | 0,2-0,5 | El del `.tres` (GSD). |
| Parqué | `surface_wood_parquet.tres` → `noise_multiplier` | curva | 1,2-1,6, ≥ mármol | El del `.tres` (GSD). |
| Mármol | `surface_marble.tres` → `noise_multiplier` | curva | 1,0-1,4 | El del `.tres` (GSD). |
| Radio de proximidad | `perception_guard.tres` → `proximity_radius` (nuevo) | sensación | 1,5-2,2 m horizontales | 1,8 (GSD). |
| Arco ciego trasero | `perception_guard.tres` → `rear_blind_arc_deg` (nuevo) | sensación | 90-150° | 120°. Deja la espalda como hueco para el molde de cera sin que el guardia esté ciego de lado. |
| Puntos de visibilidad de pie | `perception_guard.tres` → `stand_points` (nuevo) | sensación | cabeza 1,5-1,7 m; pecho 1,0-1,3 m | 1,6 y 1,2. Hoy un único punto a 0,9 m. |
| Puntos de visibilidad agachado | `perception_guard.tres` → `crouch_points` (nuevo) | sensación | 0,8-1,0 m; 0,5-0,7 m | 0,9 y 0,6. Por debajo de una cobertura baja de nivel de 1,0 m. |
| Alcance de la porra | `perception_guard.tres` → `melee_range` (nuevo) | sensación | 1,3-1,7 m horizontales, < `proximity_radius` | 1,5 (GSD; hoy 1,6). Deja ~0,8 m entre las superficies de las cápsulas. |
| Oído de la IA | `perception_guard.tres` → `ai_hearing_factor` (nuevo) | sensación | 1,0 fijo | 1,0. El anillo es la verdad; hoy 1,5. |

### Invariantes que deben comprobar los tests
Comprueban relaciones leyendo los `.tres`, no valores literales.
1. **Orden de marchas**, por bando: velocidad `sneak` < `walk` < `sprint`, y el mismo orden en `g_modo`.
2. **Ningún modo domina a otro**: para dos modos A y B del mismo bando, no puede cumplirse a la vez velocidad(A) ≥ velocidad(B), ruido(A) ≤ ruido(B) y altura visible(A) ≤ altura visible(B) con alguna desigualdad estricta. Se recorren todos los pares.
3. **Nunca silencio en movimiento**: con cualquier modo, bando y superficie, un paso emite un radio ≥ `min_radius` > 0. Parado no emite pasos.
4. **Correr es más ruidoso por metro**: `sprint_mult` > `sprint_ratio`.
5. **Agachado**: `crouch_ratio` < `sneak_ratio` y `crouch_mult` = `sneak_mult`; con `crouch` activo, `sneak` y `sprint` no cambian ni velocidad ni ruido.
6. **Asimetría de botas**: a igual modo y superficie, el radio del guardia ≥ el del ladrón (`team_noise_mult` del guardia ≥ 1).
7. **Porra dentro de la percepción**: `melee_range` < `proximity_radius`.
8. **Molde de cera posible**: `rear_blind_arc_deg` > 0, y la distancia del molde < `proximity_radius` solo se acepta con ese arco.
9. **Agacharse oculta tras cobertura baja**: los dos puntos de `crouch_points` < 1,0 m y la cabeza de `stand_points` > 1,0 m (altura de referencia de la cobertura baja de nivel).
10. **Superficies ordenadas**: alfombra < 1 ≤ mármol ≤ parqué.
11. **El anillo es la verdad**: la IA oye un ruido si y solo si su distancia horizontal al origen es ≤ el radio emitido; un guardia humano ve el anillo con la misma condición.
12. **Proximidad horizontal**: con los dos personajes en el suelo, el ladrón a `proximity_radius` − 0,01 m de frente se detecta y a `proximity_radius` + 0,01 m no; dentro del arco ciego no se detecta por proximidad a ninguna distancia.

## Contrajuego
| Acción | Quién | Qué percibe el otro bando | Cómo puede responder |
|---|---|---|---|
| Sigilo | ladrón | Anillos pequeños; en parqué, de ~1,6 m | Patrullar parqué, quedarse quieto y escuchar, talco en entradas. |
| Carrera | ladrón | Anillos grandes y frecuentes | Converger por radio (pagando la estática del walkie), cortar salidas. |
| Agachado tras cobertura baja | ladrón | Nada si no se mueve; anillo mínimo al moverse | Linterna desde arriba o desde el lateral de la cobertura; rodearla; más guardias. |
| Acercarse por la espalda (molde de cera) | ladrón | Solo sus pasos: en parqué o mármol se oyen a 1,2 m; en alfombra, no | Girarse a menudo, no detenerse en alfombra, ir en pareja. |
| Sigilo | guardia | Anillos medianos (botas), mayores que los del ladrón en el mismo suelo | El ladrón los ve siempre; el guardia lento pierde tiempo de ronda. |
| Carrera | guardia | Anillos muy grandes; se gasta estamina | Esconderse y dejar que pase; aprovechar el hueco en su ruta. |

## Qué medir
| Evento de telemetría | Pregunta que responde | Señal de alarma |
|---|---|---|
| `step_noise(team, mode, surface, radius)` | ¿Qué parte del recorrido hace cada bando en cada modo? | Un modo con > 70 % o < 5 % del tiempo de movimiento del ladrón. |
| `thief_detected(mode, cause: proximity\|cone, distance)` | ¿Agacharse protege lo justo? | Detecciones agachado ≈ 0 (demasiado fuerte) o ≈ de pie (inútil). |
| `noise_heard_by_guard(mode, surface, radius)` | ¿El ruido llega a los guardias? | Menos de una detección por oído por partida. |
| `wax_mold_progress(result)` | ¿El arco ciego hace posible el molde? | Éxito > 80 % (sobra el arco) o 0 % (imposible). |
| `melee_attempt(distance, hit)` | ¿El alcance de la porra se siente justo? | Fallos frecuentes con distancia < `melee_range` + 0,1 m. |
| `thief_sprint(duration, escaped)` | ¿La carrera ilimitada del ladrón rompe las persecuciones? (A3) | Más del 80 % de las persecuciones en abierto acaban en huida. |

## Estado
- **Modos de movimiento y ruido de pasos**: implementados en FEAT-007 (hecha, 2026-10-23). Están en `MovementProfile`, `StepNoiseProfile` y `data/balance/movement_*.tres` y `step_noise.tres`, con tests de los invariantes 1-6 y 10.
- **Percepción cercana, porra, oído de la IA y anillos por alcance**: en FEAT-008 (código integrado, tests de aceptación en curso), con `PerceptionProfile`, `PerceptionRules` y `perception_guard.tres`. Invariantes 7, 8, 9, 11 y 12.
- **Superficies por tipo en el museo**: pendiente; el museo sigue con 9 multiplicadores sueltos (`src/generation/floorplan_blueprint.gd`). Va con `/level`.
- **Indicador de modo en el HUD**: pendiente; `PlayerBase3D` ya emite `crouch_changed` y `stand_up_blocked`.
- **Red**: el modo y la detección no se replican; va con la red autoritativa.

## Decisiones
Tomadas por el usuario el 2026-10-22, todas con la opción recomendada:
- Modos: ladrón con sigilo, paso, carrera y agachado; guardias con paso, sigilo y carrera. Se elimina TIPTOE.
- `r_min` 0,5 m y peso de botas de los guardias ×1,2.
- Arco ciego trasero de 120°.
- El guardia ve solo los anillos que le alcanzan; el ladrón ve todos; la IA oye con factor 1.
- Proximidad horizontal de 1,8 m con puntos de visibilidad por altura; porra a 1,5 m.
- Carrera: ruido ×2,0 y velocidad ×1,5 en los dos bandos. Superficies del GSD con rangos.

### Aplazados
- **A1 PRONE**: vuelve solo cuando existan láseres o conductos que le den un uso, con colisión horizontal y su propio `/design`. Hasta entonces, el ladrón no pasa bajo los láseres (afecta a `gadgets.md`).
- **A2 WALL_COVER**: vuelve solo con muro obligatorio y un beneficio propio que no pise al espejo de dentista.
- **A3 Carrera ilimitada del ladrón**: se mantiene; se revisa con el evento `thief_sprint` y, si salta la alarma, `/design` en `roles.md`.

### Efectos en otras partes del GDD (sin editar aquí)
- **MASTER_GSD §3.2 y §5.3**: la proximidad deja de ser de 360°; hay que anotar el arco ciego trasero, y que es "periférica" en el sentido de este documento.
- **MASTER_GSD §3.1, molde de cera**: queda viable gracias al arco ciego; su documento (`gadgets.md`) debe citar el invariante 8.
- **MASTER_GSD §3.2, hilo con campanillas**: el "modo sigilo/agachado" que lo esquiva son `sneak` y `crouch` de este documento.
- **MASTER_GSD §4.1**: los valores de superficie del GSD se mantienen y ganan rangos; el "modo sigilo con `Shift`" es `sneak`.
- **FEAT-005**: queda obsoleta en lo que respecta a posturas (TIPTOE, PRONE, WALL_COVER, posturas de los guardias y sus números).
- **`docs/gdd/pillars.md`**: sin cambios. Estas decisiones aplican los pilares 2, 3 y 4 sin modificarlos.
- **Niveles (`/level`)**: las salas se asignan por tipo de superficie y el nivel incluye piezas de cobertura baja de ~1,0 m.

## Preguntas abiertas
- ¿Un guardia ve los anillos de sus compañeros aunque no le alcancen? Segunda parte de este documento; la decide el usuario.
- Cono de linterna y lámparas: segunda parte de este documento.
