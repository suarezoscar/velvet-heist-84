# Interacción: relojes de fichar y monitores CCTV

- **Estado**: aprobado (2026-10-24, con las 6 recomendaciones de «Decisiones abiertas»). Parte 1 de `interaction.md`: solo relojes de fichar (R) y monitores CCTV (M). Cajas fuertes, puertas, teléfonos y el panel de pilotos (O3 de `stealth.md`) quedan para partes siguientes.
- **Origen**: decisiones 3 y 5 de `docs/gdd/levels/museum_v2.md` (aprobadas por el usuario el 2026-10-24); MASTER_GSD §3.0 (relojes de 90 s); roadmap del PoC, cambio a internet con servidor dedicado (`docs/decisions/2026-10-23-roadmap-poc.md`).
- **Relacionado**: `stealth.md` (P2.2 luz, P2.3 percepción por guardia, P2.4 ruido, filtro de red); `match.md` (por crear: adopta la tabla de final por tiempo de R4); `docs/tasks/FEAT-014-red-minima-lan.md` (filtro del ladrón, `net_state`); `vision.md` (las imágenes CCTV no llevan niebla; los pilotos se ven a través de ella). Código actual: `src/systems/time_clock_3d.gd`, `security_camera_3d.gd`, `cctv_monitor_3d.gd`, `core/game_manager.gd`.
- **Alcance**: PoC, 1 ladrón contra 2 guardias por internet; el servidor dedicado decide todo lo que aquí se describe.

## Fantasía
- **Guardias**: "La central lee la tira de papel de los relojes. Si fallamos la ronda, que no nos pillen sin el ladrón en la mano". Y en la garita: "Desde aquí lo veo todo... menos lo que tengo detrás".
- **Ladrón**: "Cada campana que suena es un guardia que no está donde debería. Y cuando el piloto rojo de la cámara se enciende, alguien está mirando".

# Parte R: relojes de fichar con consecuencia

## Reglas
- **R1 Relojes y ventana**: cada mapa tiene sus relojes (museo v2: R1-R4). Cada uno cuenta atrás desde `round_duration` al empezar la partida (`IN_PROGRESS`); en el lobby no corren. Fichar (`interact`, solo guardias) devuelve ese reloj a `round_duration`. **Cuenta por equipo**: cualquier guardia vale para cualquier reloj (permite el reparto "operador más corredor" que el museo v2 da por legítimo).
- **R2 Vencimiento y faltas (la hoja de ronda)**: un reloj a 0 pasa a **vencido** y apunta una falta en la hoja del equipo; mientras sigue vencido, apunta otra cada `round_duration`. Fichar un reloj vencido lo apaga, pero **las faltas no se borran**.

```
F = Σ por cada episodio de vencimiento (1 + floor(v / T))
```
| Variable | Significado | Fuente |
|---|---|---|
| `F` | Faltas del equipo en la partida | resultado, entero ≥ 0 |
| `v` | Segundos que un reloj pasó vencido en ese episodio | simulación |
| `T` | Ventana de ronda | `time_clock_rules.tres` → `round_duration` |

Rango: 0 a ~4 × (duración de la partida / `T`) = 24 con los valores iniciales (cada reloj, 1 + floor(510 / 90) = 6). Ejemplo (`T` 90 s): R4 vence a 3:10 y se ficha a 3:50 (v = 40 s) → 1 falta. R2 vence a 7:00 y nadie lo ficha hasta el final, 10:00 (v = 180 s) → 1 + 2 = 3. F = 4.
- **R3 Ronda al día**: al día ⇔ `F ≤ allowed_misses` **y** ningún reloj vencido en el instante final. La primera condición impide ignorar los relojes 8 minutos y fichar los cuatro en el último ciclo; la segunda vuelve frenético el último minuto. Si `F` supera `allowed_misses`, la ronda queda **rota** para toda la partida: los guardias ya solo ganan capturando.
- **R4 Final por tiempo** (al llegar `match_timer` a 0; la captura y la huida no cambian):

| Ronda | Ladrón con la Pieza Maestra | Ladrón sin la Pieza |
|---|---|---|
| Al día | ganan los guardias (`TIME_EXPIRED`) | ganan los guardias (`TIME_EXPIRED`) |
| No al día (rota o con un reloj vencido) | gana el ladrón (nuevo `TIME_EXPIRED_BREACH`) | empate (nuevo `TIME_EXPIRED_DRAW`) |

- **R5 Aviso y rastro**: fichar suena a `punch_noise_radius` (mecanismo, P2.4). Vencido: la campana se mantiene, a `alarm_noise_radius` cada `alarm_pulse_interval`, y el reloj baja una banderola roja visible en el mundo. Son ruidos de equipo `guard`: el ladrón los oye a ×`thief_hearing_mult` (`noise_feedback.tres`).
- **R6 HUD del guardia** (los dos, siempre, también mirando monitores): una tablilla de ronda con R1-R4, sus segundos restantes y un estado (normal, ámbar a `warning_time` o menos, rojo vencido), y el contador "Faltas F / `allowed_misses`". Al entrar un reloj en ámbar suena un pitido de reloj de pulsera solo para los guardias (UI, no ruido del mundo: es información propia, no una acción). Con `F = allowed_misses`, aviso "Una falta más y la central no os cubre"; al romperse, "Ronda rota: solo vale capturarlo".
- **R7 HUD del ladrón**: nada. Se entera por las campanas, los fichajes que oye y las banderolas que tiene en pantalla (pilar 3: oye más lejos). La pantalla final muestra la hoja de ronda a todos.
- **R8 Red**: el servidor lleva `time_left`, `expired` y `F`. A los guardias les llegan los cuatro relojes y `F`; al ladrón solo `expired` de cada reloj (para dibujar la banderola), **nunca `time_left` ni `F`**.

### Casos límite
- **Dos guardias fichan a la vez**: el servidor aplica las dos acciones en orden; el reloj queda en `round_duration` y suenan los dos fichajes. Ninguna falta cambia.
- **Mismo tick**: un reloj que llega a 0 en el tick final cuenta como vencido (borde = vencido). Un fichaje recibido en ese tick se aplica antes de evaluar R3.
- **Guardia "capturado"**: no existe (pilar 6, el ladrón nunca ataca). Si el capturado es el ladrón, la partida acaba en `THIEF_CAPTURED` y los relojes no cuentan.
- **Guardia desconectado**: la regla no cambia; un guardia solo ficha los cuatro en ~39 s de cada 90 (museo v2 §8), así que sigue siendo posible. Un guardia de IA (puesto sin humano) **debe** incluir los relojes en su patrulla o la regla castiga a su compañero (requisito para la FEAT).
- **Ladrón junto a un reloj**: no puede ficharlo ni sabotearlo (sabotaje, si llega, en `gadgets.md` con su contramedida). Esperar junto a un reloj es apostar a que viene un guardia: un riesgo, no un escondite.

## Números (nuevo recurso `data/balance/time_clock_rules.tres`)
| Mando | Campo | Tipo | Rango | Valor inicial y por qué |
|---|---|---|---|---|
| Ventana de ronda | `round_duration` | ritmo | 60-120 s | 90 (GSD). Sustituye a `DEFAULT_ROUND_DURATION` y al campo del nodo. Ronda de un guardia solo = 43 % del ciclo |
| Faltas toleradas | `allowed_misses` | ritmo | 0-4 | 2. Perdona un descuido por una persecución, no ignorar un reloj (90 s vencido ya son 2) |
| Aviso ámbar | `warning_time` | sensación | 10-30 s | 20. Andando son ~84 m: basta para llegar a cualquier reloj del museo v2 desde casi cualquier punto |
| Ruido de fichar | `punch_noise_radius` | sensación | 4-7 m | 5,5 (constante actual). El ladrón lo oye a 8,25 m |
| Campana de vencido | `alarm_noise_radius` | sensación | 10-18 m | 14 (constante actual). El ladrón la oye a 21 m: un hueco en la ronda se oye media ala |
| Pulso de campana | `alarm_pulse_interval` | sensación | 2-5 s | 3 (constante actual) |

## Invariantes medibles
1. `F` nunca baja dentro de una partida; fichar no la modifica.
2. Un reloj vencido v segundos aporta exactamente `1 + floor(v / round_duration)` faltas.
3. El resultado por tiempo sigue la tabla R4 en todos sus casos (test por casilla).
4. El cliente del ladrón no recibe nunca `time_left` ni `F` (prueba de red, como el escenario `secret` de FEAT-014).
5. Nivel: la ronda de un solo guardia por los cuatro relojes, andando, ≤ 0,5 × `round_duration`.

# Parte M: mirar los monitores CCTV

## Reglas
- **M1 Activación**: en la garita, ante la mesa (alcance del interactor del guardia), `interact` entra en **mirando** tras `monitor_enter_time` (sentarse, girar el selector). Sale al instante con `interact`, cualquier input de movimiento, la porra (que no golpea en ese input) o el fin de partida. Una sola silla: si otro guardia ya mira, la mesa dice "ocupado". El servidor valida la distancia y el estado.
- **M2 HUD**: las 3 imágenes en fila en la mitad superior, 4:3, de alto `feed_height_frac` de la pantalla (a 1080p, 3 × 576 × 432 px, el 90 % del ancho), con el shader CRT, su rótulo ("CAM-1 VESTÍBULO") y marco rojo si esa cámara detecta. La mitad inferior sigue mostrando el mundo, y la tablilla de ronda sigue visible. Comprobación: a 9,5 m, la imagen cubre ~6,7 m de alto; un ladrón de 1,7 m ocupa ~110 px, legible.
- **M3 Qué deja de hacer**: no se mueve (moverse es salir) y mira fijo a la mesa, de espaldas a la ventana V1 y a P20. La linterna conserva su estado (sin ruido) y alumbra la mesa: el ladrón la ve. **Visión apagada**: ni linterna ni luz (`lit_sight_range`) le detectan al ladrón. **Siguen**: el oído y la proximidad, con su arco ciego trasero (`stealth.md`).
- **M4 Rastro (pilar 2)**: mientras alguien mira, las 3 cámaras encienden un **piloto rojo de grabación**, visible en el mundo para quien las tenga en pantalla. Es la contramedida del ladrón: sabe cuándo le miran y cuándo la garita está distraída.
- **M5 Qué ve una cámara**: detecta al ladrón con su cono y su línea de visión actuales **y solo si está iluminado** (lámpara de P2.2 o haz de una linterna). Un CCTV de 1984 no ve en la oscuridad (pilar 1): apagar la sala ciega la cámara, y la imagen sale negra.
- **M6 Visibilidad y red**: el servidor decide. Para un guardia en **mirando**, `percibe = su percepción propia O alguna cámara detecta al ladrón`. Solo entonces y solo a ese peer le envía el estado del ladrón, marcado "solo CCTV": su cliente lo dibuja **solo en las imágenes**, nunca en la vista del mundo (aunque esté en pantalla, como el vestíbulo junto a la garita). Al tick siguiente de perderlo, deja de enviarlo; sin silueta de última posición en las imágenes. El guardia que no mira no recibe nada por las cámaras (ve, como hoy, el cono que se pone rojo si lo tiene en pantalla).
- **M7 IA**: `SignalBus.thief_spotted` de una cámara solo vale para un guardia de IA que esté mirando (coherencia con `stealth.md`: la IA no sabe más que un humano). Hoy avisa a todas: hay que corregirlo.

### Casos límite
- Salir de mirando con el ladrón en una imagen: deja de recibirlo en ese tick, salvo que lo perciba él.
- Dos guardias: solo uno mira; el otro puede quedarse de pie detrás (ve el mundo, no las imágenes).
- Desconexión mirando: sale de mirando; el actor queda quieto (FEAT-014).
- Ladrón tras el guardia que mira: solo le delatan su ruido y la proximidad fuera del arco ciego.

## Números (nuevo recurso `data/balance/cctv_rules.tres`)
| Mando | Campo | Tipo | Rango | Valor inicial y por qué |
|---|---|---|---|---|
| Tiempo de sentarse | `monitor_enter_time` | sensación | 0,2-0,8 s | 0,4. Mirar a ratos cuesta algo: "o miras las pantallas o el pasillo" |
| Alto de cada imagen | `feed_height_frac` | sensación | 0,30-0,45 de pantalla | 0,40. El ladrón se lee (~110 px a 1080p) y queda media pantalla de mundo |

Alcance (9,5 m), FOV (52°) y barrido (65°) siguen siendo datos de cada cámara en el nivel (`museum_v2.md` §6); la condición de luz usa `light_rules.tres` sin números nuevos.

## Invariantes medibles
1. Un guardia que no está mirando no recibe nunca estado del ladrón por una cámara.
2. El estado "solo CCTV" no aparece nunca en la vista del mundo del cliente.
3. Con el ladrón en sombra dentro del cono, la cámara no detecta.
4. Mirando, ningún input de movimiento mueve al guardia; el primero lo saca del estado.
5. Piloto encendido ⇔ algún guardia mirando.

# Común
## Contrajuego
| Acción | Quién | Qué percibe el otro | Respuesta |
|---|---|---|---|
| Fichar | guardia | clic a 8,25 m: "ahí hay uno y este reloj tiene 90 s" | cruzar lejos de los relojes recién fichados |
| Dejar vencer un reloj | guardias | campana a 21 m y banderola | aprovechar el hueco de esa ala; con la ronda rota, aguantar con la Pieza |
| Acampar el coche | guardia | sin linterna en la ronda; el compañero ficha solo | rodear al corredor, que pasa siempre por lo mismo |
| Mirar monitores | guardia | pilotos rojos, linterna fija en la garita | apagar las luces de las salas con cámara o cruzar el pasillo de servicio a su espalda |
| Apagar la luz de una sala con cámara | ladrón | imagen negra, sala a oscuras en el mundo | ir a encenderla (deja la garita) o patrullarla con linterna |

## Pilares
| Pilar | Cómo lo cumple |
|---|---|
| 1. 1984 | Relojes Detex con tira de papel, banderola mecánica, CRT, piloto de grabación; el CCTV no ve a oscuras |
| 2. Sonido | Fichar y vencer suenan; mirar se ve (pilotos). **Silencio justificado**: el pitido ámbar es solo de UI |
| 3. Información frente a número | El ladrón infiere la ronda de oído; los guardias ganan las cámaras quedándose ciegos y quietos |
| 4. Respuesta | Tabla de contrajuego; ninguna acción sin fila |
| 5. Partidas cortas | La hoja castiga ignorar relojes en cualquier minuto y la regla final calienta el último ciclo |
| 6. No violento | Sin cambios; el guardia mirando es vulnerable a ser esquivado, no atacado |

## Qué medir
| Evento | Pregunta | Señal de alarma |
|---|---|---|
| `clock_expired`, `F` final | ¿Los relojes mandan? | `F` = 0 en 5 de 5 partidas (sobra holgura) o ronda rota antes del minuto 4 en 3 de 5 |
| Resultado por tiempo | ¿El final por tiempo es justo? | Más de 2 empates en 5 partidas |
| Segundos mirando por partida | ¿Los monitores valen? | < 20 s seguidos en todas, o un guardia > 50 % de la partida en la silla |
| Detecciones por cámara con alguien mirando | ¿Las cámaras aportan? | 0 en 5 partidas |

## Estado
- **Parte R** (FEAT-016, integrada el 2026-10-24): faltas, final por tiempo R4, tablilla del guardia, banderola y filtro de red. Los números están en `time_clock_rules.tres`.
- **Parte M** (FEAT-017): mesa de la garita, «mirando» con visión apagada, imágenes CRT en el HUD, cámaras que necesitan luz, pilotos y filtro de red `cctv_only`. Los números están en `cctv_rules.tres`.
- **Precisión del invariante 5 de la parte M**: los pilotos se encienden cuando el guardia ya mira, no mientras se sienta (la silla sí queda reservada).

## Decisiones (aprobadas por el usuario el 2026-10-24)
1. Las faltas son irreversibles.
2. El ladrón no sabe que la ronda está rota; lo deduce por las campanas.
3. Ronda rota y ladrón sin la Pieza al acabar el tiempo: empate.
4. El CCTV necesita luz para ver al ladrón (M5).
5. Una sola silla en la garita (M1).
6. `round_duration` es global (`time_clock_rules.tres`); las excepciones por reloj, más adelante como dato de nivel.
7. Un guardia sentado no golpea: la porra primero lo levanta, igual que moverse, y ese golpe no se da. El que mira las pantallas sigue siendo vulnerable a que lo esquiven (pilar 6).
