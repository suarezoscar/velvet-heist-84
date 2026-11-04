# Interacción: monitores CCTV y selección de interactivos

- **Estado**: aprobado (2026-10-24, con las 6 recomendaciones de «Decisiones abiertas»). Parte 1 de `interaction.md`: relojes de fichar (R) y monitores CCTV (M). **2026-10-30, #116: la parte R se retira** por decisión del usuario; la sustituyen el sueño nuevo y el final por tiempo de `heist.md` (R4, R5, R5c, R5d). **2026-11-04, #118: la parte M se reescribe** (una cámara en cada sala menos la garita; en la mesa, una imagen cada vez que se pasa con ← →; solo la cámara en pantalla ve al ladrón y enciende su piloto). Las reglas las decidió el usuario en la entrevista de #118; la lista de cámaras, `feed_height_frac` y las decisiones de #118 las aprobó el 2026-11-04. Cajas fuertes, puertas y teléfonos quedan para partes siguientes; el panel de pilotos (O3 de `stealth.md`) sale del juego con #119 (pendiente de aprobación, `heist.md` R9d).
- **Origen**: decisiones 3 y 5 de `docs/gdd/levels/museum_v2.md` (aprobadas por el usuario el 2026-10-24); MASTER_GSD §3.0 (relojes de 90 s); roadmap del PoC, cambio a internet con servidor dedicado (`docs/decisions/2026-10-23-roadmap-poc.md`).
- **Relacionado**: `stealth.md` (P2.2 luz, P2.3 percepción por guardia, P2.4 ruido, filtro de red); `heist.md` (sueño, café y final por tiempo desde #116); `match.md` (por crear); `docs/tasks/FEAT-014-red-minima-lan.md` (filtro del ladrón, `net_state`); `vision.md` (las imágenes CCTV no llevan niebla; los pilotos se ven a través de ella). Código actual: `security_camera_3d.gd`, `cctv_monitor_3d.gd`, `core/game_manager.gd` (`time_clock_3d.gd` y `src/systems/rounds/` se borran con #116).
- **Alcance**: PoC, 1 ladrón contra 2 guardias por internet; el servidor dedicado decide todo lo que aquí se describe.

## Fantasía
- **Guardias**: en la garita, "Desde aquí veo cualquier sala... pero solo una cada vez, y nunca lo que tengo detrás" (2026-11-04, #118; antes, "lo veo todo... menos lo que tengo detrás"). (Desde #116, la tira de papel de los relojes ya no existe.)
- **Ladrón**: "El piloto rojo me dice qué sala están mirando; las demás son mías" (2026-11-04, #118).

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

# Parte M: mirar los monitores CCTV (reescrita el 2026-11-04, #118)

En el playtest con amigos había 5 cámaras para 21 salas y se veían las 5 a la vez. El usuario decidió en la entrevista de #118 poner una cámara en cada sala y que en la mesa se vean de una en una: lo que gana la garita en alcance lo pierde en atención, y el ladrón sabe qué sala vigilan. Estas reglas sustituyen a las de la parte M del 2026-10-24 (FEAT-017 y FEAT-042); lo que cambia lleva «#118».

## Reglas
- **M0 Una cámara en cada sala (2026-11-04, #118)**: cada sala interior del nivel lleva una cámara, menos la garita (la sala con `"guard_post": true`). El exterior (el callejón, `"exterior": true`) no lleva. En `museum_v2` son 20 (lista propuesta en el «Anexo: las 20 cámaras de museum_v2»). Cada cámara tiene un número y un nombre corto, y se rotula «CAM 07 · PIEZA MAESTRA». La numeración es el orden en que se pasan en la mesa (M2b).
- **M1 Activación**: en la garita, ante la mesa (alcance del interactor del guardia), `interact` entra en **mirando** tras `monitor_enter_time` (sentarse, girar el selector). Hay una sola mesa con una sola silla: si otro guardia ya mira, la mesa dice «ocupado». El servidor valida la distancia y el estado.
  - **Levantarse (2026-11-04, #118)**: sale al instante con E (`interact`), W o S, la porra (que no golpea en ese input, decisión 7) o el fin de partida. A y D ya no lo sacan: pasan de cámara (M2b).
- **M2 HUD (2026-11-04, #118)**: **una sola imagen**, casi a pantalla completa, 4:3, de alto `feed_height_frac` de la pantalla, con el shader CRT, su rótulo («CAM 07 · PIEZA MAESTRA») y marco rojo si esa cámara detecta. En el margen que queda siguen la taza del sueño y el resto del HUD propio. Antes: las imágenes en fila en la mitad superior y el mundo en la mitad inferior. Comprobación: con `feed_height_frac` 0,90 a 1080p, la imagen mide 1296 × 972 px; a 9,5 m cubre ~6,7 m de alto, así que un ladrón de 1,7 m ocupa ~250 px.
- **M2b Pasar de cámara (2026-11-04, #118)**: sentado, ← o A pasa a la cámara anterior y → o D a la siguiente, en el orden de su número y en bucle (después de la última, la primera). Cambia una cámara por pulsación. Arranca en la última que se vio en la mesa (CAM 01 al empezar la partida). Al cambiar, `switch_time` s de nieve en los que la cámara nueva aún no detecta (decisiones de #118).
- **M3 Qué deja de hacer**: no se mueve (W y S lo levantan; A y D cambian de cámara) y mira fijo a la mesa, de espaldas a la ventana V1 y a P20. La linterna conserva su estado (sin ruido) y alumbra la mesa: el ladrón la ve. **Visión apagada**: ni linterna ni luz (`lit_sight_range`) le detectan al ladrón. **Siguen**: el oído y la proximidad, con su arco ciego trasero (`stealth.md`).
- **M4 Rastro (pilar 2; 2026-11-04, #118)**: mientras alguien mira, **solo la cámara que está en pantalla** enciende su **piloto rojo de grabación**, visible en el mundo para quien la tenga en pantalla (y a través de la niebla, `vision.md` D5). Es la contramedida del ladrón: sabe qué sala vigilan ahora y ve cuándo cambian (el piloto se apaga en una sala y se enciende en otra). Sin nadie sentado no se enciende ninguno. Antes: se encendían todas las cámaras a la vez.
- **M5 Qué ve una cámara (2026-11-04, #118; sustituye a la regla anterior)**: **solo la cámara que se está mirando puede ver al ladrón**. Las demás graban, pero nadie las mira: no detectan, no descubren rastros, no hacen saltar la alarma y no avisan a nadie, tampoco a la IA. La que está en pantalla detecta al ladrón con su cono y su línea de visión **y solo si está iluminado** (lámpara de P2.2 o haz de una linterna). Un CCTV de 1984 no ve en la oscuridad (pilar 1): apagar la sala ciega la cámara, y la imagen sale negra. Antes: detectaban las cámaras a la vez mientras alguien miraba.
- **M1b El ladrón también mira** (FEAT-042; 2026-11-04, #118): se sienta en la misma mesa de la garita, con la misma silla (si un guardia mira, para él está ocupada, y al revés), y **pasa cámaras igual, con ← → o A D**. Ve lo mismo que un guardia: una imagen, y en ella a los guardias que esa cámara ve con luz (una lámpara o su linterna), solo en la imagen, nunca en la vista del mundo. Con red le llegan marcados «solo CCTV» (`vision.md` R4). Las cámaras se comportan igual las use quien las use: con el ladrón sentado también se enciende el piloto de la cámara en pantalla (M4) y la mesa sale ocupada, así que un guardia que ve un piloto encendido sin ningún compañero en la mesa puede deducir que el ladrón está en la garita. Es el riesgo de esa jugada (decisión del usuario, 2026-10-30).
- **M6 Visibilidad y red (2026-11-04, #118)**: el servidor decide. Para un guardia en **mirando**, `percibe = su percepción propia O la cámara en pantalla detecta al ladrón`. Solo entonces y solo a ese peer le envía el estado del ladrón, marcado «solo CCTV»: su cliente lo dibuja **solo en la imagen**, nunca en la vista del mundo. Al tick siguiente de perderlo (también al cambiar de cámara), deja de enviarlo; sin silueta de última posición en la imagen. El guardia que no mira no recibe nada por las cámaras (ve, como hoy, el cono que se pone rojo si lo tiene en pantalla). El servidor sabe en todo momento qué cámara tiene cada mesa en pantalla.
- **M7 IA (2026-11-04, #118)**: `SignalBus.thief_spotted` de una cámara solo sale de la cámara en pantalla y solo vale para el guardia de IA que esté mirando (coherencia con `stealth.md`: la IA no sabe más que un humano). La IA no se sienta en la mesa, así que hoy no pasa cámaras (decisión 6 de #118).
- **M8 Rendimiento (2026-11-04, #118)**: solo se renderiza la cámara que se ve, y solo en el cliente de quien está sentado; con la mesa vacía no se renderiza ninguna. La detección (M5) la calcula el servidor con el cono, los rayos y la luz, sin render, así que no depende de la imagen. Como mucho una cámara renderiza a la vez en todo el juego.

### Casos límite
- Salir de mirando con el ladrón en la imagen: deja de recibirlo en ese tick, salvo que lo perciba él.
- Pasar de cámara con el ladrón en la imagen (#118): igual que salir; si la nueva también lo ve, sigue recibiéndolo.
- Ladrón en una sala cuya cámara no está en pantalla (#118): esa cámara no lo ve, aunque esté a plena luz y dentro de su cono.
- Dos guardias: solo uno mira; el otro puede quedarse de pie detrás (ve el mundo, no la imagen).
- Desconexión mirando: sale de mirando; el actor queda quieto (FEAT-014). El piloto se apaga.
- Ladrón tras el guardia que mira: solo le delatan su ruido y la proximidad fuera del arco ciego.

## Números (`data/balance/cctv_rules.tres`)
| Mando | Campo | Tipo | Rango | Valor inicial y por qué |
|---|---|---|---|---|
| Tiempo de sentarse | `monitor_enter_time` | sensación | 0,2-0,8 s | 0,4. Mirar a ratos cuesta algo: «o miras las pantallas o el pasillo» |
| Cambio de cámara | `switch_time` | sensación | 0,1-0,5 s | 0,25 (#118). Nieve al pasar de cámara; la nueva no detecta hasta acabar |
| Alto de la imagen | `feed_height_frac` | sensación | 0,80-0,95 de pantalla (#118; antes 0,30-0,45) | **0,90** (aprobado el 2026-11-04, #118); antes 0,40, el alto de cada imagen de la fila. Casi a pantalla completa, con margen para la taza del sueño |

Alcance (9,5 m), FOV (52°) y barrido (65°) siguen siendo datos de cada cámara en el nivel (`museum_v2.md` §6); la condición de luz usa `light_rules.tres` sin números nuevos.

## Invariantes medibles
1. Un guardia que no está mirando no recibe nunca estado del ladrón por una cámara.
2. El estado «solo CCTV» no aparece nunca en la vista del mundo del cliente.
3. Con el ladrón en sombra dentro del cono, la cámara no detecta.
4. Mirando, ningún input mueve al personaje: W, S y E lo levantan; ←, →, A y D solo cambian de cámara (#118).
5. El piloto de una cámara está encendido ⇔ alguien está mirando y esa cámara está en su pantalla. Como mucho hay un piloto encendido en todo el mapa (#118).
6. Una cámara que no está en pantalla no detecta nunca: ni rastro, ni alarma, ni `thief_spotted` (#118).
7. Como mucho una cámara se renderiza a la vez (#118).

## Anexo: las 20 cámaras de museum_v2 (aprobada el 2026-11-04, #118)
Propuesta de diseño; el JSON (`data/levels/museum_v2.json`, sección `cameras`) se cambia en la FEAT de #118. El orden recorre el museo en un bucle de salas vecinas: entrada, ala oeste, antesala y cámara acorazada, ala este y vuelta por el ala de servicio; de la 20 se pasa a la 01, que también es vecina.

Convención, la de las cámaras actuales: `pos` [x, y] en coordenadas de diseño del JSON (y crece hacia el sur), a 0,5 m de los dos muros de la esquina; dirección = (sin(yaw), −cos(yaw)), así que yaw 0 mira al norte, 90 al este, 180 al sur y 270 al oeste. Las nuevas miran al centro de su sala: yaw = atan2(cx − x, −(cy − y)). Las 5 que ya existen conservan su sitio y su yaw (`museum_v2.md` §6) y cambian de número. Ejemplo resuelto, la 07: centro de VLT (24, 5) menos (16,5, 9,5) = (7,5, −4,5); atan2(7,5, 4,5) = 59°.

| N.º | Sala | Rótulo | `pos` | `yaw_deg` | Qué cubre y qué deja fuera |
|---|---|---|---|---|---|
| 01 | VES | CAM 01 · VESTÍBULO | [31.5, 26.5] | 225 | Es CAM-1: taquilla, P01 y P06; fuera, la franja oeste y P05 |
| 02 | ROT | CAM 02 · ROTONDA | [16.5, 25.5] | 45 | Es CAM-2: mitad sur, P04 y P07; fuera, P08 y P09 |
| 03 | GSW | CAM 03 · PINTURA MODERNA | [15.5, 24.5] | 234 | P10 y la pieza T17; el tabique de y = 32 deja sombra al sur |
| 04 | GW | CAM 04 · RETRATOS | [15.5, 14.5] | 239 | Mitad norte y P07; el tabique de y = 19 tapa la mitad sur |
| 05 | ANT | CAM 05 · ANTIGÜEDADES | [0.5, 0.5] | 131 | T3 y T11 (a ~7,5 m); fuera, T20 y P12 |
| 06 | ANTE | CAM 06 · ANTESALA | [31.5, 10.5] | 270 | Es CAM-3: x 22-31 y P13; fuera, P12 y el panel de C3/C4 |
| 07 | VLT | CAM 07 · PIEZA MAESTRA | [16.5, 9.5] | 59 | P13 y el pedestal (a ~9 m, al límite); fuera, P14, la puerta de servicio |
| 08 | ARC | CAM 08 · ARCHIVO | [39.5, 13.5] | 332 | A lo largo de las estanterías; las filas se tapan entre sí |
| 09 | OFF | CAM 09 · DESPACHO DEL CONSERVADOR | [40.5, 13.5] | 28 | T6 (a ~6 m) y P17; fuera, P25 |
| 10 | ORI | CAM 10 · ARTE ORIENTAL | [65.5, 0.5] | 225 | Es CAM-5 (yaw actual) |
| 11 | BIB | CAM 11 · BIBLIOTECA | [58.5, 14.5] | 142 | T9 y T19 (#119: el cuadro eléctrico del ala este sale del juego) |
| 12 | TAP | CAM 12 · TAPICES | [65.5, 24.5] | 204 | P32 y T18 (a ~8 m) |
| 13 | PAT | CAM 13 · PATIO | [50.5, 24.5] | 135 | Es CAM-4 (yaw actual) |
| 14 | JOY | CAM 14 · JOYAS Y RELOJES | [57.5, 14.5] | 218 | T7, T8 y P31 |
| 15 | EPS | CAM 15 · PASILLO DE SERVICIO ESTE | [49.5, 14.5] | 183 | Tramo norte (P26, P29, P35); fuera, el tramo sur (P34, P36, P37) |
| 16 | DOCK | CAM 16 · MUELLE DE CARGA | [47.5, 30.5] | 252 | P03 (salida) y P37; fuera, el extremo oeste y P23 |
| 17 | VEST | CAM 17 · VESTUARIO | [42.5, 29.5] | 45 | La sala entera (6 × 6 m) |
| 18 | MNT | CAM 18 · MANTENIMIENTO | [40.5, 23.5] | 38 | Movida (decisión 9). #119: el cuadro eléctrico sale del juego; la cámara se queda donde está |
| 19 | TAL | CAM 19 · TALLER | [39.5, 14.5] | 209 | T5 y P19 |
| 20 | PS | CAM 20 · PASILLO DE SERVICIO | [33.5, 14.5] | 184 | Tramo norte (P15, P09, P18); fuera, el tramo junto a la garita (P20, P06, P23): sigue valiendo «cruzar el pasillo a su espalda» |

Comprobaciones pendientes para la FEAT: que la esquina de la 02 quede dentro del círculo de la rotonda y la de la 07 fuera de las columnas; y que ninguna cámara quede encima de una puerta que tape su cono (los cuadros eléctricos quedaban fuera de todas, decisión 9; con #119 salen del juego).

Rótulos todo en mayúsculas («CAM 07 · PIEZA MAESTRA»), como el resto (`estilo-de-textos.md` §5); la sala VLT se rotula «PIEZA MAESTRA» para no confundirla con una cámara de vigilancia. La porra sigue levantando y ↑ ↓ cuentan como W S (usuario, 2026-11-04).

## Decisiones de #118 (aprobadas por el usuario el 2026-11-04, como las recomendó `game-designer`)
1. **Con qué cámara arranca la mesa**: recomendación, la última que se vio en esa mesa (el selector se queda donde lo dejaron); al empezar la partida, la CAM 01. Así quien se sienta después, también el ladrón, hereda la sala que miraba el anterior.
2. **¿Más de una mesa?**: recomendación, no. Sigue habiendo una mesa y una silla (decisión 5 de 2026-10-24), así que solo un piloto puede estar encendido.
3. **¿El ladrón en la mesa enciende el piloto?**: recomendación, sí, como ya decía M1b: es el riesgo de sentarse, y un piloto que se mueve sin compañero en la mesa le delata.
4. **¿Cambiar de cámara hace ruido o tiene retardo?**: recomendación, sin ruido (el rastro es el piloto que salta de sala) y con un corte de nieve de 0,25 s (`switch_time`, sensación, 0,1-0,5 s, en `cctv_rules.tres`) en el que la cámara nueva aún no detecta. Evita pasar las 20 en 3 s barriendo el museo, y se siente de 1984.
5. **¿Mantener ← o → pasa cámaras seguidas?**: recomendación, no: una por pulsación, por la misma razón que el punto 4.
6. **Cómo pasa cámaras la IA sentada**: recomendación, en orden, `ai_camera_dwell` s en cada una (ritmo, 3-8 s, propuesto 5), y salta antes a la de una sala donde oyó un ruido. Sin red la IA patrulla a su aire (`heist.md` R5c); si nunca se sienta, basta con dejarlo anotado.
7. **¿Qué ve el guardia alrededor de la imagen?**: la imagen casi a pantalla completa quita la mitad inferior del mundo, y el que mira se entera aún menos de quién se le acerca. Recomendación: margen oscuro, sin mundo, con la taza del sueño y el HUD propio; el oído y la proximidad siguen avisando (M3).
8. **Las cámaras que «graban»**: recomendación, sin efecto en el juego por ahora (no hay cintas que rebobinar). Unas cintas VHS que revisar serían una mecánica nueva, al backlog.
9. **Cámaras y cuadros eléctricos**: la propuesta deja el cuadro de servicio dentro de la CAM 18 y el del ala este fuera de la CAM 11. Recomendación: que ninguna cámara vea un cuadro, para que cortar la corriente dependa del oído y las patrullas, no de acertar la sala; habría que mover la CAM 18 a la esquina suroeste, [40.5, 23.5] con yaw 38 (el cuadro queda a ~10,7 m, fuera de alcance). **#119** (pendiente de aprobación): los cuadros salen del juego y la razón desaparece; la CAM 18 se queda en la esquina suroeste, que cubre bien Mantenimiento.
10. **Los monitores de la mesa en el mundo**: hoy hay 5 CRT, uno por cámara. Con una imagen cada vez, recomendación: que se encienda uno con la imagen en pantalla y los demás queden apagados (también por M8).
11. **¿Rastros con el ladrón sentado?**: R6 de `heist.md` dice «mientras alguien mira». Recomendación: con el ladrón en la mesa, la cámara no descubre rastros ni hace saltar la alarma (él no da parte); solo un guardia mirando.

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
| Mirar monitores | guardia | el piloto rojo de la sala que mira (#118), linterna fija en la garita | evitar esa sala, apagar su luz o cruzar el pasillo de servicio a su espalda |
| Pasar de cámara (#118) | guardia o ladrón sentado | el piloto se apaga en una sala y se enciende en otra | leer el patrón y entrar en la sala que acaba de dejar; un piloto que salta sin ningún guardia en la mesa delata al ladrón en la garita |
| Apagar la luz de una sala | ladrón | imagen negra si esa cámara está en pantalla, sala a oscuras en el mundo | ir a encenderla (deja la garita) o patrullarla con linterna |

## Pilares
| Pilar | Cómo lo cumple |
|---|---|
| 1. 1984 | CRT, piloto de grabación; el CCTV no ve a oscuras (los relojes Detex se fueron con #116) |
| 2. Sonido | Mirar se ve (pilotos). Desde #116, lo que antes delataban los relojes (dónde está cada guardia) lo delatan los bostezos, la cafetera y la puerta de la garita (`heist.md` R5) |
| 3. Información frente a número | Los guardias ganan las cámaras quedándose ciegos y quietos, y desde #118 solo una sala cada vez; el ladrón ve qué sala vigilan por su piloto |
| 4. Respuesta | Tabla de contrajuego; ninguna acción sin fila |
| 5. Partidas cortas | Desde #116 el tiempo presiona al ladrón (si no escapa, ganan los guardias) y el sueño, a los guardias (`heist.md` R4 y R5) |
| 6. No violento | Sin cambios; el guardia mirando es vulnerable a ser esquivado, no atacado |

## Qué medir
| Evento | Pregunta | Señal de alarma |
|---|---|---|
| Segundos mirando por partida | ¿Los monitores valen? | < 20 s seguidos en todas, o un guardia > 50 % de la partida en la silla |
| Detecciones por cámara con alguien mirando | ¿Las cámaras aportan? | 0 en 5 partidas |
| Cambios de cámara por minuto en la mesa (#118) | ¿Se mira o se barre? | Más de 20 por minuto (barren sin mirar) o menos de 2 (se quedan en una) |
| Salas donde una cámara detecta (#118) | ¿Sobran cámaras? | Más del 70 % de las detecciones en 3 cámaras |

## Estado
- **Parte R** (FEAT-016, integrada el 2026-10-24; ampliada en FEAT-034 y FEAT-042): **retirada el 2026-10-30 (#116)**. El código y `time_clock_rules.tres` se borran en la FEAT de #116.
- **Parte M** (FEAT-017): mesa de la garita, «mirando» con visión apagada, imágenes CRT en el HUD, cámaras que necesitan luz, pilotos y filtro de red `cctv_only`. Los números están en `cctv_rules.tres`.
- **#118** (2026-11-04): parte M reescrita, a falta de su FEAT (20 cámaras en `museum_v2.json`, una imagen con ← →, detección y piloto solo de la cámara en pantalla, un solo render).
- **Precisión del invariante 5 de la parte M**: los pilotos se encienden cuando el guardia ya mira, no mientras se sienta (la silla sí queda reservada).

## Decisiones (usuario, 2026-10-28; FEAT-034; sin efecto desde #116)
- Fichar de uno en uno, con una ruta distinta para cada guardia (R1).
- Tramo medido por la distancia andando, × 1,8 + 15 s; faltas de equipo, 2 por guardia; 8 relojes; el ladrón no ve las rutas; la IA sigue la suya.

## Decisiones (aprobadas por el usuario el 2026-10-24; la 1, la 2, la 3 y la 6 quedan sin efecto desde #116)
1. Las faltas son irreversibles.
2. El ladrón no sabe que la ronda está rota; lo deduce por las campanas.
3. Ronda rota y ladrón sin la Pieza al acabar el tiempo: empate.
4. El CCTV necesita luz para ver al ladrón (M5).
5. Una sola silla en la garita (M1). Desde #118, también una sola mesa: un solo piloto encendido.
6. `round_duration` es global (`time_clock_rules.tres`); las excepciones por reloj, más adelante como dato de nivel.
7. Un guardia sentado no golpea: la porra primero lo levanta, igual que moverse, y ese golpe no se da. El que mira las pantallas sigue siendo vulnerable a que lo esquiven (pilar 6).

## Decisiones (usuario, 2026-11-04, #118, entrevista tras el playtest con amigos)
1. Una cámara en cada sala interior menos la garita (20 en `museum_v2`); el callejón no lleva.
2. En la mesa, una sola cámara casi a pantalla completa con su nombre («CAM 07 · PIEZA MAESTRA»); ← → (o A D) pasan a la anterior o la siguiente; te levantas con E, W o S.
3. Solo la cámara que se está mirando puede ver al ladrón y hacer saltar la alarma; las demás graban, pero nadie las mira. Sustituye a la regla anterior de la parte M.
4. El piloto rojo de grabación solo se enciende en la cámara que se está viendo: el ladrón sabe qué sala vigilan.
5. El ladrón sentado en la mesa también pasa cámaras con ← →.
6. Solo se renderiza la cámara que se ve.
