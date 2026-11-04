# Interacción: monitores CCTV y selección de interactivos

- **Estado**: aprobado (2026-10-24, con las 6 recomendaciones de «Decisiones abiertas»). Parte 1 de `interaction.md`: relojes de fichar (R) y monitores CCTV (M). **2026-10-30, #116: la parte R se retira** por decisión del usuario; la sustituyen el sueño nuevo y el final por tiempo de `heist.md` (R4, R5, R5c, R5d). Cajas fuertes, puertas, teléfonos y el panel de pilotos (O3 de `stealth.md`) quedan para partes siguientes.
- **Origen**: decisiones 3 y 5 de `docs/gdd/levels/museum_v2.md` (aprobadas por el usuario el 2026-10-24); MASTER_GSD §3.0 (relojes de 90 s); roadmap del PoC, cambio a internet con servidor dedicado (`docs/decisions/2026-10-23-roadmap-poc.md`).
- **Relacionado**: `stealth.md` (P2.2 luz, P2.3 percepción por guardia, P2.4 ruido, filtro de red); `heist.md` (sueño, café y final por tiempo desde #116); `match.md` (por crear); `docs/tasks/FEAT-014-red-minima-lan.md` (filtro del ladrón, `net_state`); `vision.md` (las imágenes CCTV no llevan niebla; los pilotos se ven a través de ella). Código actual: `security_camera_3d.gd`, `cctv_monitor_3d.gd`, `core/game_manager.gd` (`time_clock_3d.gd` y `src/systems/rounds/` se borran con #116).
- **Alcance**: PoC, 1 ladrón contra 2 guardias por internet; el servidor dedicado decide todo lo que aquí se describe.

## Fantasía
- **Guardias**: en la garita, "Desde aquí lo veo todo... menos lo que tengo detrás". (Desde #116, la tira de papel de los relojes ya no existe.)
- **Ladrón**: "Cuando el piloto rojo de la cámara se enciende, alguien está mirando".

# Parte R: relojes de fichar y rondas (retirada el 2026-10-30, #116)

En el playtest con amigos fichar no era divertido: los guardias jugaban contra la tablilla y no contra el ladrón. El usuario decidió quitarlo en la entrevista de #116. **Ya no existen**:
- los relojes de fichar del mapa (R1-R8 de `museum_v2`), su campana de vencido y su banderola;
- las rutas por guardia, los tramos, el retraso y la hoja de faltas (antiguas R1-R3);
- el final por tiempo según la ronda (antigua R4): ya no hay `TIME_EXPIRED_BREACH` ni `TIME_EXPIRED_DRAW`;
- la tablilla de ronda del HUD, su pitido ámbar y la flecha al siguiente reloj (antiguas R6 y R6b, FEAT-042), y la ronda suspendida por la alarma (R2b);
- los relojes y las faltas del informe y de los puntos (`heist.md` R11);
- las rutas de ronda de la IA (`RoundPlanner`);
- el recurso `data/balance/time_clock_rules.tres`.

**Qué los sustituye** (fuente de verdad en `heist.md`):
- **El sueño** empuja a los guardias: fuera de la garita sube poco a poco y dentro se congela; el café lo deja a 0 (R5).
- **El final por tiempo** es de los guardias: si se acaba sin que el ladrón haya escapado, ganan (R4).
- **Correr** solo con la alarma (R5d).
- **La IA sin red** patrulla salas a su aire, sobre todo donde hay piezas, y vuelve a por café cuando le entra sueño (R5c).

El rastro sonoro que daban los relojes (fichar a 8,25 m para el ladrón, campana a 21 m) lo sustituyen los bostezos, la cafetera y la puerta de la garita (ver «Pilares»).

# Parte M: mirar los monitores CCTV

## Reglas
- **M1 Activación**: en la garita, ante la mesa (alcance del interactor del guardia), `interact` entra en **mirando** tras `monitor_enter_time` (sentarse, girar el selector). Sale al instante con `interact`, cualquier input de movimiento, la porra (que no golpea en ese input) o el fin de partida. Una sola silla: si otro guardia ya mira, la mesa dice "ocupado". El servidor valida la distancia y el estado.
- **M2 HUD**: las 3 imágenes en fila en la mitad superior, 4:3, de alto `feed_height_frac` de la pantalla (a 1080p, 3 × 576 × 432 px, el 90 % del ancho), con el shader CRT, su rótulo ("CAM-1 VESTÍBULO") y marco rojo si esa cámara detecta. La mitad inferior sigue mostrando el mundo, y la taza del sueño sigue visible (la tablilla de ronda desapareció con #116). Comprobación: a 9,5 m, la imagen cubre ~6,7 m de alto; un ladrón de 1,7 m ocupa ~110 px, legible.
- **M3 Qué deja de hacer**: no se mueve (moverse es salir) y mira fijo a la mesa, de espaldas a la ventana V1 y a P20. La linterna conserva su estado (sin ruido) y alumbra la mesa: el ladrón la ve. **Visión apagada**: ni linterna ni luz (`lit_sight_range`) le detectan al ladrón. **Siguen**: el oído y la proximidad, con su arco ciego trasero (`stealth.md`).
- **M4 Rastro (pilar 2)**: mientras alguien mira, las 3 cámaras encienden un **piloto rojo de grabación**, visible en el mundo para quien las tenga en pantalla. Es la contramedida del ladrón: sabe cuándo le miran y cuándo la garita está distraída.
- **M5 Qué ve una cámara**: detecta al ladrón con su cono y su línea de visión actuales **y solo si está iluminado** (lámpara de P2.2 o haz de una linterna). Un CCTV de 1984 no ve en la oscuridad (pilar 1): apagar la sala ciega la cámara, y la imagen sale negra.
- **M1b El ladrón también mira** (FEAT-042): se sienta en la misma mesa de la garita, con la misma silla (si un guardia mira, para él está ocupada, y al revés). Ve lo mismo que un guardia: las imágenes de las cámaras, y en ellas a los guardias que alguna cámara ve con luz (una lámpara o su linterna), solo en las imágenes, nunca en la vista del mundo. Con red le llegan marcados «solo CCTV» (`vision.md` R4). Las cámaras se comportan igual las use quien las use: con el ladrón sentado también se encienden los pilotos de grabación (M4) y la mesa sale ocupada, así que un guardia que ve los pilotos sin ningún compañero en la mesa puede deducir que el ladrón está en la garita. Es el riesgo de esa jugada (decisión del usuario, 2026-10-30).
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

# Selección de interactivos (2026-10-30, #113)

- **E en abanico**: la E actúa sobre un objeto interactivo válido a menos de 2 m y dentro de un abanico total de 120° delante del personaje. El alcance y el ángulo se miden en horizontal hasta el centro de la forma del objeto, a su altura (así llegan los cuadros eléctricos y los interruptores de pared). Si el cursor no señala a ninguno, gana el más cercano.
- **Cursor**: si el cursor cae a menos de `cursor_snap_distance` (0,75 m) de algún candidato válido, gana el más cercano al cursor; si no, el cursor no cuenta. El cursor llega proyectado al suelo y se lleva a la altura de cada objeto con la inclinación fija de la cámara isométrica (constantes `VIEW_FORWARD_H` y `VIEW_RUN_PER_DROP` de `Interactor3D`: si cambia la cámara, hay que cambiarlas). Esta preferencia no cambia la orientación corporal definida en `stealth.md`. El cliente envía el punto del cursor junto a la intención fiable de E; el servidor lo sanea y vuelve a validar alcance, abanico, estado y muros antes de ejecutarla.
- **Oclusión**: los muros y tabiques siguen bloqueando; los muebles no. Las partes del propio objeto (la hoja de una puerta) no lo tapan. Entre una pieza y el candado que la guarda gana la pieza, que ya abre su dial.
- **Puertas**: su área cubre todo el hueco y 1,1 m a cada lado, incluidos los extremos. Vale para ladrón y guardias, respetando el `can_interact` de cada objeto.
- **Foco visible**: el objeto elegido muestra un contorno suave ámbar además del texto de interacción. Texto y contorno consultan el mismo foco y desaparecen al perderlo o al cambiar de personaje local. El contorno no atraviesa muros ni sustituye los materiales de las piezas.

Los números comunes viven en `data/balance/interaction_rules.tres`: `reach_distance = 2,0`, `fan_angle_degrees = 120,0` y `cursor_snap_distance = 0,75`.

# Común
## Contrajuego
| Acción | Quién | Qué percibe el otro | Respuesta |
|---|---|---|---|
| Mirar monitores | guardia | pilotos rojos, linterna fija en la garita | apagar las luces de las salas con cámara o cruzar el pasillo de servicio a su espalda |
| Apagar la luz de una sala con cámara | ladrón | imagen negra, sala a oscuras en el mundo | ir a encenderla (deja la garita) o patrullarla con linterna |

## Pilares
| Pilar | Cómo lo cumple |
|---|---|
| 1. 1984 | CRT, piloto de grabación; el CCTV no ve a oscuras (los relojes Detex se fueron con #116) |
| 2. Sonido | Mirar se ve (pilotos). Desde #116, lo que antes delataban los relojes (dónde está cada guardia) lo delatan los bostezos, la cafetera y la puerta de la garita (`heist.md` R5) |
| 3. Información frente a número | Los guardias ganan las cámaras quedándose ciegos y quietos; el ladrón ve los pilotos |
| 4. Respuesta | Tabla de contrajuego; ninguna acción sin fila |
| 5. Partidas cortas | Desde #116 el tiempo presiona al ladrón (si no escapa, ganan los guardias) y el sueño, a los guardias (`heist.md` R4 y R5) |
| 6. No violento | Sin cambios; el guardia mirando es vulnerable a ser esquivado, no atacado |

## Qué medir
| Evento | Pregunta | Señal de alarma |
|---|---|---|
| Segundos mirando por partida | ¿Los monitores valen? | < 20 s seguidos en todas, o un guardia > 50 % de la partida en la silla |
| Detecciones por cámara con alguien mirando | ¿Las cámaras aportan? | 0 en 5 partidas |

## Estado
- **Parte R** (FEAT-016, integrada el 2026-10-24; ampliada en FEAT-034 y FEAT-042): **retirada el 2026-10-30 (#116)**. El código y `time_clock_rules.tres` se borran en la FEAT de #116.
- **Parte M** (FEAT-017): mesa de la garita, «mirando» con visión apagada, imágenes CRT en el HUD, cámaras que necesitan luz, pilotos y filtro de red `cctv_only`. Los números están en `cctv_rules.tres`.
- **Precisión del invariante 5 de la parte M**: los pilotos se encienden cuando el guardia ya mira, no mientras se sienta (la silla sí queda reservada).

## Decisiones (usuario, 2026-10-28; FEAT-034; sin efecto desde #116)
- Fichar de uno en uno, con una ruta distinta para cada guardia (R1).
- Tramo medido por la distancia andando, × 1,8 + 15 s; faltas de equipo, 2 por guardia; 8 relojes; el ladrón no ve las rutas; la IA sigue la suya.

## Decisiones (aprobadas por el usuario el 2026-10-24; la 1, la 2, la 3 y la 6 quedan sin efecto desde #116)
1. Las faltas son irreversibles.
2. El ladrón no sabe que la ronda está rota; lo deduce por las campanas.
3. Ronda rota y ladrón sin la Pieza al acabar el tiempo: empate.
4. El CCTV necesita luz para ver al ladrón (M5).
5. Una sola silla en la garita (M1).
6. `round_duration` es global (`time_clock_rules.tres`); las excepciones por reloj, más adelante como dato de nivel.
7. Un guardia sentado no golpea: la porra primero lo levanta, igual que moverse, y ese golpe no se da. El que mira las pantallas sigue siendo vulnerable a que lo esquiven (pilar 6).
