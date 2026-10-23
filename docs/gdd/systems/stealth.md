# Sigilo: modos de movimiento, ruido de pasos y percepción cercana

- **Estado**: aprobado por el usuario: parte 1 el 2026-10-22 y parte 2 (linterna, luz, información entre guardias y anillos) el 2026-10-23.
- **Origen**: MASTER_GSD §2 (asimetría), §4.1 (acústica de superficies), §5.3 (visibilidad); FEAT-005 (posturas); auditoría de la Fase 1 (`docs/decisions/2026-10-22-fase-1-auditoria.md`, "Decisiones de diseño pendientes"). 2026-10-22.
- **Relacionado**: `characters.md` (altura de los modelos, que fija los puntos de visibilidad); `roles.md` (velocidades por rol), `gadgets.md` (molde de cera, hilo con campanillas, láseres) e `interaction.md` (cobertura baja de los niveles), que todavía no existen.
- **Alcance**: modos de movimiento, ruido de pasos, superficies, quién ve qué anillo (solo la regla), proximidad, puntos de visibilidad y alcance de la porra. **Segunda parte** (abajo): el cono de la linterna, las lámparas y el detalle de la visibilidad de los anillos (colores, duración, ruido de objetos).

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
- **Percepción cercana, porra, oído de la IA y anillos por alcance**: implementados en FEAT-008 (hecha, 2026-10-23). Están en `PerceptionProfile`, `PerceptionRules` y `perception_guard.tres`, con tests de los invariantes 7, 8, 9, 11 y 12. Pendiente: un épsilon en el borde exacto del arco ciego.
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
- Resueltas en la parte 2: anillos entre guardias (D4) y cono de linterna y lámparas (P2).

---

# Parte 2: linterna, luz y sombra, información entre guardias y anillos

- **Estado**: aprobado por el usuario el 2026-10-23 (todas las opciones recomendadas). No modifica ninguna regla ni número de la parte 1.
- **Origen**: MASTER_GSD §2 (visión de cada bando, "desenroscar bombillas", "encender interruptores"), §3.1 (cuerda de piano que apaga lámparas), §3.2 (Maglite, walkie-talkie de 6 m, silbato), §5.3 (visibilidad por luz o línea de visión), §5.4 (ondas de sonido); preguntas abiertas de la parte 1; escena actual `scenes/entities/guard_player.tscn` (`MagliteSpotLight`: alcance 9 m, semiángulo 32°, a 0,9 m de altura).
- **Relacionado**: `gadgets.md` (walkie-talkie, silbato, cuerda de piano: por crear), `interaction.md` (interruptores, bombillas, panel de pilotos: por crear), `characters.md` (la Maglite en la mano), niveles (`/level`: reparto de luz y sombra).
- **Alcance**: cono de la linterna, zonas iluminadas por lámparas, apagar y encender luces, qué se comparte entre guardias y reglas de legibilidad de los anillos. Fuera: shaders, colores concretos (paleta de UI de `vfx-ui-engineer`), varios pisos.

## Fantasía (parte 2)
- **Ladrón**: "La sombra es mía; la luz es de ellos". Ve cada haz de linterna y cada anillo; cruzar una sala iluminada es una apuesta, y apagarla es una declaración.
- **Guardias**: "Mi linterna es lo único que tengo en la oscuridad, y el ladrón la ve venir". Cada guardia sabe lo que su linterna, sus ojos y sus oídos le dicen; el resto llega por la radio, y la radio se oye.

## Reglas (parte 2)

### P2.1 Cono de la linterna
La linterna es un **sector horizontal**: la inclinación del haz hacia el cursor es solo visual. Así el cono que el ladrón ve dibujado en el suelo es exactamente el área de detección (pilar 3) y la altura solo cuenta para la oclusión, como en la proximidad de la parte 1.

Un guardia ve al ladrón con la linterna si se cumplen las tres condiciones:

```
d_h(G, L) ≤ F_alcance   y   ángulo_h(frente_G, L − G) ≤ F_semiángulo   y   rayo libre desde O_linterna hasta algún punto de visibilidad de L
```

| Variable | Significado | Fuente |
|---|---|---|
| `d_h(G, L)` | Distancia horizontal entre los centros de guardia y ladrón | geometría |
| `ángulo_h` | Ángulo en el plano XZ entre el frente del guardia y la dirección al centro del ladrón | geometría |
| `F_alcance` | Alcance de la linterna | `perception_guard.tres` → `flashlight_range` (nuevo) |
| `F_semiángulo` | Semiángulo del cono | `perception_guard.tres` → `flashlight_half_angle_deg` (nuevo) |
| `O_linterna` | Origen del haz: centro del guardia a `flashlight_height` | `perception_guard.tres` → `flashlight_height` (nuevo) |
| Puntos de visibilidad | Los de la parte 1 según el modo (`stand_points` / `crouch_points`) | `perception_guard.tres` |

- Rango de salida: booleano. El área cubierta va de ~19 m² (7 m, 22°) a ~74 m² (11 m, 35°); con los valores iniciales, 9 m y 32°: π·9²·(64/360) ≈ **45 m²**.
- Ejemplos resueltos (valores iniciales, linterna a 1,4 m):
  - Ladrón de pie a 8 m, 20° fuera del eje, sin obstáculos: 8 ≤ 9, 20 ≤ 32, rayo libre → **visto**.
  - Ladrón agachado a 3 m, en el eje, tras una vitrina de 1,0 m situada a 0,3 m de él: el rayo de 1,4 m al punto de 0,9 m cruza la vitrina a 1,4 − 0,5 × 2,7/3 = 0,95 m < 1,0 → bloqueado; el punto de 0,6 m también → **no visto**. De pie, la cabeza (1,6 m) asoma → **visto**.
  - Ladrón de pie a 9,5 m en el eje: 9,5 > 9 → **no visto** por la linterna (puede verlo la luz de una lámpara, P2.2).
- El cono vive dentro del campo frontal: nunca entra en el arco ciego trasero (invariante 13). El molde de cera no se ve afectado.
- La linterna **no depende de la luz ambiente**: mismo alcance en sombra y en una sala iluminada. En la luz manda P2.2, que ya ve más lejos.
- La `SpotLight3D` visible toma `spot_range` y `spot_angle` de estos mismos campos: lo que se ve iluminado es lo que detecta (invariante 14). El haz tiene que leerse hasta su borde: la atenuación no puede dejar el último 20 % del alcance a oscuras.
- El borde pertenece al cono (como en el arco ciego de la parte 1).
- **El ladrón ve todos los haces encendidos**, también tras los muros, como silueta del sector en el suelo (MASTER_GSD §2, pilar 3).
- **Apagar la linterna**: el guardia la alterna con un clic que emite un anillo de `flashlight_toggle_noise_radius`. Apagada, el guardia solo ve por proximidad y por P2.2, y su haz desaparece para el ladrón.

### P2.2 Lámparas y zonas de luz
- **Base oscura**: el museo de noche no tiene luz ambiente que detecte. Un punto de visibilidad está **iluminado** si alguna lámpara encendida cumple `d_h(lámpara, punto) ≤ lit_radius` y el rayo desde la bombilla hasta el punto está libre. Los muebles proyectan sombra: agacharse tras una vitrina en una sala iluminada también oculta.
- **Ver con luz sin linterna**: un guardia ve al ladrón si algún punto de visibilidad está iluminado, el centro del ladrón queda fuera de su arco ciego trasero (`rear_blind_arc_deg`, el mismo de la parte 1), `d_h(G, L) ≤ lit_sight_range` y hay rayo libre desde los ojos del guardia (`eye_height`) a ese punto.
- Ejemplo resuelto: lámpara de techo (`lit_radius` 4,0 m), ladrón de pie a 3 m de ella; guardia a 11 m, de lado (90° de su frente) y con rayo libre: iluminado, fuera del arco ciego (90 < 120), 11 ≤ 12 → **visto**. El mismo ladrón a 4,5 m de la lámpara: no iluminado → solo lo vería la linterna o la proximidad.
- Una detección es la unión de tres fuentes: proximidad (parte 1), linterna (P2.1) y luz (P2.2). Cualquiera basta.
- **Tipos de lámpara** (un nivel asigna tipos, nunca números sueltos, como con las superficies), cada uno en `data/balance/lamp_<id>.tres` (nuevos):

| Tipo | `lit_radius` | ¿Interruptor? | ¿Bombilla desenroscable? | Uso en nivel |
|---|---|---|---|---|
| `lamp_ceiling` (lámpara de techo) | 4,0 m | sí, por circuito | no (fuera de alcance) | salas principales |
| `lamp_desk` (flexo, lámpara de mesa) | 2,0 m | cadenilla propia | sí | despachos, recepción |
| `lamp_street` (farola tras ventana) | 3,0 m | no | no | luz fija: la sombra no siempre se compra |

- **Apagar y encender**:
  - **Interruptor de pared** (ladrón y guardias): `switch_time` 0,5 s; clic con anillo de `switch_noise_radius` 2,0 m. Apaga o enciende todas las lámparas de su circuito. El guardia lo deshace con la misma acción.
  - **Desenroscar la bombilla** (solo ladrón, solo tipos desenroscables): `unscrew_time` 2,0 s, anillo de `unscrew_noise_radius` 1,0 m. La lámpara queda apagada hasta que un guardia la vuelva a enroscar (`rescrew_time` 3,0 s); el interruptor no la arregla.
  - **Cuerda de piano** (MASTER_GSD §3.1): apaga a distancia una lámpara desenroscable; su ruido y sus tiempos los fija `gadgets.md`, con la misma regla de rastro.
- **Rastro visible** (pilar 2): una lámpara que cambia de estado cambia la luz del mundo; cualquier guardia que tenga esa zona en pantalla lo ve. No hay aviso global (ver O3).
- **El ladrón sabe si está iluminado** (requisito de legibilidad): el ladrón ve la luz del mundo; lo que no ve con claridad es si su punto bajo queda en sombra (ver O1).
- **Requisito de nivel** (para `/level`): cada sala iluminada tiene al menos un bolsillo de sombra alcanzable (cobertura baja o zona fuera de `lit_radius`) y su interruptor a la vista de una entrada; ninguna ruta obligatoria atraviesa solo zonas de luz fija (`lamp_street`).

### P2.3 Información entre guardias
- **La percepción es por guardia**: lo que detecta un guardia (proximidad, linterna, luz) solo hace visible al ladrón en la pantalla de ese guardia, y lo que oye solo lo ve él (regla de la parte 1). Un guardia **no ve** los anillos que alcanzan a sus compañeros.
- **Walkie-talkie: ping** (MASTER_GSD §3.2): el guardia marca un punto de su pantalla; todos los guardias ven un marcador allí durante `ping_marker_time` 3,0 s; el walkie del que marca emite estática con anillo de `ping_noise_radius` 6,0 m (de forma discontinua, ver P2.4). Enfriamiento `ping_cooldown` 1,5 s.
- **Voz**: hablar por el walkie es pulsar para hablar; al empezar y cada `voice_pulse_interval` 2,0 s mientras se habla, el walkie emite el mismo anillo de estática.
- **Supuesto de diseño**: los guardias pueden hablar por un canal externo (Discord). El balance no puede depender de que no lo hagan; por eso lo que se comparte de verdad (posiciones exactas en pantalla) es la percepción por guardia, y lo que la voz externa no da es el marcador preciso del ping.
- **Silbato**: sin cambios respecto al GSD; lo detalla `gadgets.md`.

### P2.4 Aspecto y legibilidad de los anillos
Solo reglas; el shader y la paleta son de `vfx-ui-engineer`.
- **Verdad geométrica**: el radio final dibujado es exactamente el radio emitido; el anillo se centra en el origen y se dibuja completo, también tras muros y en la oscuridad (MASTER_GSD §5.4). Oír se decide en el instante de la emisión; el crecimiento es presentación.
- **Forma por categoría de fuente**, distinguible en escala de grises (el color nunca es la única pista):

| Categoría | Ejemplos | Forma |
|---|---|---|
| Paso | pasos de cualquier modo | anillo fino continuo |
| Golpe u objeto | porra, captura, monedas, jarrón | anillo grueso o doble |
| Mecanismo | walkie, teléfono, despertador, interruptor, bombilla, linterna | anillo discontinuo |

- **Color**: hay dos papeles, **propio** (lo que emite quien mira o sus gadgets) y **ajeno**. El ladrón, además, distingue **guardia** frente a **propio** (pilar 3). Los guardias ven todos los anillos ajenos en un mismo color neutro: no distinguen por el anillo a un compañero del ladrón. No hay color por superficie ni por modo: la superficie y el modo ya se leen en el radio y la cadencia.
- **Tiempos**: el anillo crece en `ring_grow_time` 0,4 s y vive `ring_lifetime_step` 1,4 s (pasos) o `ring_lifetime_event` 2,0 s (golpes y mecanismos), desvaneciéndose al final. Una fuente sostenida (despertador, voz) emite pulsos cada `pulse_interval` 0,6 s, no un anillo largo.
- **Rastro legible**: la vida de un anillo de paso cubre al menos dos pasos consecutivos del modo más lento, para que se lea la dirección de marcha (invariante 22).
- **Tamaño mínimo**: un anillo de `min_radius` (0,5 m) se distingue del personaje y tiene al menos 2 px de trazo a 1080p con la cámara de tamaño 14 (evidencia por captura).
- **Fuera de pantalla**: si un anillo alcanza a quien mira y su origen queda fuera de su pantalla, aparece un marcador en el borde de la pantalla que apunta al origen durante la vida del anillo.
- **Límite**: como mucho `max_rings` 48 anillos vivos por cliente; si se superan, se acortan los más viejos, nunca se descarta uno nuevo.

### P2.5 Añadidos para cerrar el sistema
O1, O2 y O4 entran ahora; O3 queda aplazado a `interaction.md`.
- **O1 Indicador de exposición del ladrón**: el HUD muestra tres estados, sombra, iluminado (P2.2) o en un haz (P2.1), calculados con sus propios puntos de visibilidad. Sin él, el agachado en una sala iluminada es una adivinanza.
- **O2 Última posición vista**: cuando un guardia deja de percibir al ladrón, en su pantalla queda una silueta fija en la última posición durante `last_seen_linger` 1,5 s. Solo en ese guardia; compartirla es el ping.
- **O3 Panel de pilotos** (aplazado a `interaction.md`): en la sala de seguridad, un panel de bombillas piloto muestra qué circuitos están apagados (tecnología de 1984). Es la única vía para que un guardia sepa de un apagón fuera de su pantalla, y obliga a ir a mirarlo. Se detalla en `interaction.md`.
- **O4 Ruidos que no son pasos a `.tres`**: la porra (4,5 m) y la captura (8,0 m) son hoy constantes en `guard_controller_3d.gd`; pasan a `perception_guard.tres` → `baton_swing_noise_radius` y `capture_noise_radius` sin cambiar valores, con la categoría de P2.4.

### Interacciones (parte 2)
- **Agachado**: no reduce el ángulo ni el alcance de la linterna; solo protege con oclusión. En abierto, agachado en el haz = visto.
- **Molde de cera**: el cono y la luz respetan el arco ciego; en una sala iluminada el molde sigue siendo posible por la espalda.
- **Botín pesado**: no cambia los puntos de visibilidad (pendiente de `loot.md` si el cuadro debe asomar).
- **Disfraz de guardia**: cambia este filtro de visibilidad; su documento debe decir si un ladrón disfrazado e iluminado se ve como guardia.
- **IA**: usa las mismas tres fuentes y la misma percepción por guardia; no recibe información que un humano no tendría (sin pings implícitos entre IA).
- **Red**: el servidor decide la detección por guardia y solo envía al cliente de ese guardia la posición del ladrón (paquete F de la auditoría). El estado de cada lámpara y de cada linterna se replica a todos.

### Casos límite (parte 2)
- Ladrón en el borde exacto del alcance o del semiángulo: dentro.
- Lámpara apagada a mitad de un paso por la sala: cuenta el estado en el instante de la comprobación de visibilidad.
- Dos guardias activan el mismo interruptor a la vez: gana el último; los dos clics suenan.
- Un guardia enrosca una bombilla mientras el ladrón está en su `lit_radius`: el ladrón queda iluminado en cuanto acaba `rescrew_time`.
- Linterna apagada y ladrón en proximidad: la proximidad sigue funcionando.
- Interrumpir el desenroscado: no apaga y el anillo ya emitido no se retira.

## Números (parte 2)
Todos nuevos. Los de linterna arrancan con los valores actuales de la escena.

| Mando | Recurso y campo | Tipo | Rango aceptable | Valor inicial y por qué |
|---|---|---|---|---|
| Alcance de la linterna | `perception_guard.tres` → `flashlight_range` | sensación | 7-11 m, > `proximity_radius` | 9,0 (actual). Cabe en pantalla con la cámara de tamaño 14 y deja al ladrón ver el haz antes de entrar. |
| Semiángulo del cono | `perception_guard.tres` → `flashlight_half_angle_deg` | sensación | 22-35° | 32 (actual). Un barrido de ~64° obliga a apuntar sin cubrir media sala. |
| Altura del haz | `perception_guard.tres` → `flashlight_height` | sensación | 0,9-1,5 m | 1,4. Agarre policial sobre el hombro; hace real el contrajuego "linterna desde arriba". Hoy 0,9. |
| Clic de la linterna | `perception_guard.tres` → `flashlight_toggle_noise_radius` | curva | 0,5-1,5 m, ≥ `min_radius` | 1,0. Solo lo oye quien está encima. |
| Vista con luz | `perception_guard.tres` → `lit_sight_range` | sensación | 9-15 m, ≥ `flashlight_range` | 12. La luz de sala ve más lejos que la linterna: es la herramienta de la oscuridad. |
| Radio de luz por tipo | `lamp_<id>.tres` → `lit_radius` | curva | techo 3-5 m; mesa 1,5-2,5 m; farola 2-4 m | 4,0 / 2,0 / 3,0. Islas de luz, no salas enteras. |
| Tiempo de interruptor | `light_rules.tres` → `switch_time` | ritmo | 0,3-1,0 s | 0,5. Un gesto, no una espera. |
| Clic de interruptor | `light_rules.tres` → `switch_noise_radius` | curva | 1,5-3,0 m | 2,0. Se oye en la sala, no en la de al lado. |
| Desenroscar bombilla | `light_rules.tres` → `unscrew_time` | ritmo | 1,5-3,0 s, > `switch_time` | 2,0. Más lento a cambio de durar. |
| Ruido al desenroscar | `light_rules.tres` → `unscrew_noise_radius` | curva | 0,5-1,5 m, ≤ `switch_noise_radius` | 1,0. Más discreto que el clic. |
| Volver a enroscar | `light_rules.tres` → `rescrew_time` | ritmo | 2,0-4,0 s, ≥ `unscrew_time` | 3,0. Arreglarlo cuesta tiempo de ronda. |
| Marcador del ping | `guard_radio.tres` → `ping_marker_time` | ritmo | 2-5 s | 3,0 (GSD, igual que el silbato). |
| Estática del walkie | `guard_radio.tres` → `ping_noise_radius` | curva | 5-8 m | 6,0 (GSD). |
| Enfriamiento del ping | `guard_radio.tres` → `ping_cooldown` | ritmo | 1-3 s | 1,5. Evita el spam sin impedir dos avisos seguidos. |
| Pulso de voz | `guard_radio.tres` → `voice_pulse_interval` | ritmo | 1,5-3,0 s | 2,0. Una frase corta ya delata. |
| Crecimiento del anillo | `noise_rings.tres` → `ring_grow_time` | sensación | 0,25-0,8 s | 0,4. El GSD dice 0,8; a la cadencia de carrera (0,28 s) eso deja el anillo dos pasos por detrás. |
| Vida del anillo de paso | `noise_rings.tres` → `ring_lifetime_step` | sensación | 1,2-2,0 s | 1,4. ≥ 2 × 0,60 s (sigilo, el paso más lento): siempre hay al menos dos anillos de la misma estela a la vista. |
| Vida del anillo de evento | `noise_rings.tres` → `ring_lifetime_event` | sensación | 1,5-3,0 s | 2,0. Un golpe o un clic se tienen que poder buscar. |
| Pulso de fuente sostenida | `noise_rings.tres` → `pulse_interval` | sensación | 0,4-1,0 s | 0,6. |
| Anillos vivos | `noise_rings.tres` → `max_rings` | sensación | 32-64 | 48. Cuatro guardias corriendo más el ladrón no lo alcanzan. |
| Última posición vista (O2) | `perception_guard.tres` → `last_seen_linger` | sensación | 1-3 s | 1,5. |

### Invariantes (parte 2)
Comprueban relaciones leyendo los `.tres`, no valores literales.
13. **Cono en el campo frontal**: `flashlight_range` > `proximity_radius` y `flashlight_half_angle_deg` ≤ (360 − `rear_blind_arc_deg`) / 2.
14. **El haz es la verdad**: la `SpotLight3D` del guardia tiene `spot_range` = `flashlight_range` y `spot_angle` = `flashlight_half_angle_deg`.
15. **Borde del cono**: con rayo libre, el ladrón a `flashlight_range` − 0,01 m en el eje se detecta y a + 0,01 m no; a `flashlight_half_angle_deg` − 0,5° se detecta y a + 0,5° no (fuera de proximidad y sin luz).
16. **Agacharse oculta de la linterna**: con una cobertura de 1,0 m a 0,3 m del ladrón agachado y el guardia a ≥ 2 m, ningún punto de `crouch_points` es visible desde `flashlight_height`; de pie, la cabeza sí.
17. **La luz detecta sin linterna**: ladrón iluminado, fuera del arco ciego, a `lit_sight_range` − 0,01 m y con rayo libre → visto con la linterna apagada; el mismo ladrón sin luz, fuera de proximidad y del cono → no visto.
18. **Los muebles dan sombra**: un punto con el rayo desde la bombilla bloqueado no está iluminado, aunque esté dentro de `lit_radius`.
19. **La luz ve más que la linterna**: `lit_sight_range` ≥ `flashlight_range`.
20. **Apagar deja rastro y ninguna vía domina**: `switch_noise_radius`, `unscrew_noise_radius` y `flashlight_toggle_noise_radius` ≥ `min_radius`; `unscrew_time` > `switch_time` y `unscrew_noise_radius` ≤ `switch_noise_radius`; `rescrew_time` ≥ `unscrew_time`.
21. **Percepción por guardia**: con dos guardias, si solo A cumple alguna condición de detección, el ladrón es visible en el cliente de A y no en el de B; un anillo que alcanza a A y no a B no se dibuja para B.
22. **Rastro legible**: `ring_lifetime_step` ≥ 2 × el mayor `step_interval_<modo>` de los dos bandos, y `ring_grow_time` < `ring_lifetime_step`.
23. **La radio se oye**: cada ping y cada pulso de voz emiten un anillo de `ping_noise_radius` > `proximity_radius`.
24. **Anillo exacto**: el radio final dibujado = radio emitido (tolerancia de 1 cm).

## Contrajuego (parte 2)
| Acción | Quién | Qué percibe el otro bando | Cómo puede responder |
|---|---|---|---|
| Barrer con la linterna | guardia | El sector del haz, también tras muros | Esperar a que pase, ir por la espalda, agacharse tras cobertura alta respecto al haz. |
| Apagar la linterna | guardia | Clic de 1 m y el haz que desaparece; sus pasos siguen | Leer sus anillos; desconfiar de una zona oscura donde un haz se apagó. |
| Cruzar una zona iluminada | ladrón | Visible a 12 m en 240° | Apagarla antes, rodearla, usar la sombra de los muebles, ir por la espalda. |
| Apagar por interruptor | ladrón | Clic de 2 m y la sala que se oscurece en su pantalla | Volver a encender con el mismo gesto; vigilar el interruptor. |
| Desenroscar bombilla | ladrón | Anillo de 1 m y la lámpara apagada | Enroscarla (3 s de ronda); usar la linterna en esa sala. |
| Ping de walkie | guardia | Estática discontinua de 6 m en su posición | Alejarse del guardia que avisa; el ladrón sabe que le han localizado. |
| Hablar por walkie | guardia | Estática cada 2 s mientras habla | Igual que el ping; además sabe que hay coordinación en curso. |
| Lanzar un ruido señuelo (monedas, despertador) | ladrón | Un guardia ve el anillo si le alcanza, sin color de bando | Comprobar si coincide con pasos; mandar a uno solo; pedir confirmación por ping. |

## Qué medir (parte 2)
| Evento de telemetría | Pregunta que responde | Señal de alarma |
|---|---|---|
| `thief_detected(cause: proximity\|cone\|light, mode, lit)` | ¿Qué fuente detecta más? | Una fuente con > 70 % de las detecciones, o la luz con < 5 %. |
| `lamp_state_changed(by_team, method, circuit)` | ¿Se juega con la luz? | El ladrón apaga < 1 lámpara por partida (sobra) o > 10 (la luz no vale). |
| `lamp_restored(delay)` | ¿Los guardias responden a los apagones? | Retardo medio > 60 s (nadie lo ve) o < 5 s (el apagón no compra nada). |
| `flashlight_toggled(on, duration_off)` | ¿Apagar la linterna es una táctica o un abuso? | Guardias > 50 % del tiempo con la linterna apagada. |
| `walkie_ping(dist_to_thief)` y `voice_seconds` | ¿Pagan los guardias por coordinarse? | Ningún ping por partida, o > 1 por guardia y minuto. |
| `thief_exposure_seconds(state)` | ¿Hay sombra suficiente en el nivel? | Ladrón iluminado > 40 % del tiempo de movimiento. |

## Autorrevisión (parte 2)
Veredicto: `APROBABLE`. Alcance: L (percepción, niveles, red y UI).
- Pilar 1: lámparas de 1984, interruptores, bombillas, walkie y panel de pilotos; sin visión nocturna.
- Pilar 2: todo cambio de luz y toda comunicación dejan anillo; el único silencio es un guardia quieto con la linterna apagada, que sigue siendo visible al ladrón por línea de visión.
- Pilar 3: el ladrón ve haces, anillos con bando y luz; los guardias solo saben lo propio y pagan la radio.
- Pilar 4: cada acción nueva tiene fila de contrajuego; ninguna vía de apagar domina (invariante 20).
- Pilar 5: los tiempos de interacción son ≤ 3 s; el reloj de fichar sigue empujando a los guardias fuera de las salas iluminadas.
- Pilar 6: apagar luces y señuelos no son violencia.
- Tensión declarada: la luz con 240° es fuerte; se compensa con islas de `lit_radius` y el requisito de nivel de P2.2.

## Decisiones (parte 2)
Tomadas por el usuario el 2026-10-23, todas con la opción recomendada:
- D1: sin linterna, un guardia ve con luz en todo salvo el arco ciego (240°) hasta `lit_sight_range`.
- D2: el ladrón apaga por interruptor o desenroscando bombillas; la caja de fusibles queda para `interaction.md` si un nivel la pide.
- D3: la linterna se puede apagar, con un clic de `flashlight_toggle_noise_radius`.
- D4: cada guardia ve solo los anillos que le alcanzan; se comparte por ping de walkie, que suena.
- D5: voz por walkie con estática al empezar y cada `voice_pulse_interval`.
- D6: anillos con forma por categoría y color propio/ajeno; el ladrón distingue además a los guardias; sin tinte por superficie.
- D7: O1, O2 y O4 entran ahora; O3 (panel de pilotos) con `interaction.md`.
