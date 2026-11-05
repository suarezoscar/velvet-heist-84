# El golpe: la lista del coleccionista, el café y la alerta

- **Estado**: aprobado por el usuario el 2026-10-28 (decisiones tomadas en conversación). **2026-11-04, #119, aprobado por el usuario el 2026-11-04**: R9 reescrita (todo lo necesario para robar está en la pieza: minijuego con E, Q a lo bruto; fuera las mesas de copias, cuadros eléctricos de las alas y panel de pilotos) y R1, R6, R7, R11, números, contrajuego y casos límite ajustados. **2026-10-30, #116**: R4, R5, R7 y R11 reescritas y R5c y R5d nuevas (fuera relojes y rondas; sueño fuera de la garita; IA de patrulla libre; correr solo con alarma). Las reglas las decidió el usuario en la entrevista de #116; los números nuevos los aprobó el 2026-11-04. **2026-11-04, #118**: «cámara vigilada» pasa a ser la cámara que está en pantalla en la mesa (una cada vez, `interaction.md` M5); R5, R6, R7 y el contrajuego ajustados.
- **2026-11-04, #120, aprobado por el usuario el 2026-11-04**: con la alarma, el ladrón tiene `lockdown_time` s para huir con lo que lleve; después bajan las rejas de las 4 salidas. R3 y R4 reescritas, R4b y R7b nuevas, R11 (informe y puntos, con «proteger» y «encerrado» traídos de #123), números, contrajuego, casos límite, red, nivel y «Qué medir» ajustados. La regla la decidió el usuario tras el playtest; los detalles los propuso `game-designer` y el usuario los aprobó (ver «Decisiones (usuario, 2026-11-04, #120)»).
- **2026-11-05, #121, aprobado por el usuario el 2026-11-05**: el ladrón puede sabotear la caja de la reja de cada salida para que esa reja no baje con la alarma. R7c nueva; R3, R4, R7b, R11 (puntos e informe), números, contrajuego, casos límite, red, nivel y «Qué medir» ajustados. La regla es del usuario (issue #121, tras el playtest); los detalles los propuso `game-designer` y el usuario los aprobó (ver «Decisiones (usuario, 2026-11-05, #121)»).
- **2026-11-05, #123, aprobado por el usuario el 2026-11-05**: los puntos de los dos bandos. Las reglas las decidió el usuario en la entrevista de #123 (2026-11-05): piezas por fracción del encargo, puntuación individual y de equipo, puntos nuevos de guardias y ladrón y puntuación en vivo. Los números, la definición de «puntos de equipo» y la tabla de escenarios los propone `game-designer`. R4b y R11 (puntos) reescritas; números, casos límite y «Qué medir» ajustados (ver «Puntos (#123)»).
- **Origen**: rediseño pedido por el usuario el 2026-10-28 para que los guardias no acampen en un sitio y para que su turno sea divertido. Temática: `docs/decisions/2026-10-28-tematica-caballero-ladron.md`.
- **Relacionado**: `interaction.md` (CCTV; su parte R, relojes de ronda, se retiró el 2026-10-30, #116), `vision.md` (niebla y filtro de red), `stealth.md` (percepción y ruido), `gentleman.md` (temática; sus M1-M3 quedan sustituidas por este documento), `docs/gdd/levels/museum_v2.md`.

## Fantasía
- **Ladrón**: «Un coleccionista me ha encargado tres piezas. Ellos no saben cuáles. Entro, me las llevo y salgo por donde menos me esperen».
- **Guardias**: «Sabemos que viene, no qué busca. Hay que patrullar, leer lo que deja a su paso y cerrarle el cerco cuando se delate. Y no dormirse».

## Por qué
Hasta ahora el ladrón necesitaba una pieza fija (la Pieza Maestra de la cámara acorazada) y volver a un coche fijo. Lo óptimo para los guardias era acampar en esos dos puntos. Este diseño ataca las tres causas:
- **no saber qué defender**: la lista;
- **no saber por dónde saldrá**: las salidas;
- **que alejarse mucho rato de la garita canse**: el sueño y el café (desde el 2026-10-30, #116; antes castigaba quedarse quieto).

Y da a los guardias un juego propio: los rastros y la alerta.

## Reglas

### R1. La lista del coleccionista
- El nivel marca **20 piezas candidatas** repartidas por todo el museo (FEAT-034; eran 6).
- Al empezar, el servidor **sortea** las piezas del encargo, de entre esas 20. Su número depende de los guardias:

  | Guardias | Piezas del encargo |
  |---|---|
  | 1 | 4 |
  | 2 | 3 |
  | 3 | 2 |

- **Quién sabe qué**:
  - **el ladrón** conoce sus piezas desde el principio (en la tarjeta de objetivo y en su plano);
  - **los guardias** saben cuáles son las candidatas y cuántas busca el ladrón, pero no cuáles: tienen que deducirlo por las zonas que frecuenta.
- **Robar** una pieza: E junto a ella abre el minijuego de su protección y Q la roba a lo bruto (R9, #119, aprobado por el usuario el 2026-11-04). Una pieza que no está en el encargo **no se puede robar**: el ladrón no pierde el tiempo con ella.
- Las piezas van al maletín, sin cargar en brazos. El botín pesado queda aparcado.
- Las **cajas fuertes** (2) son candidatas: si le toca una, la pieza está dentro y hay que abrirla con el dial.
- Desaparecen la **cuota de dinero** y la **Pieza Maestra fija**. El resto del botín del museo se retira del nivel.

### R2. La carta
Al empezar, los guardias ven en su tarjeta de objetivo:

> «Esta noche me llevaré **tres** piezas de su colección. Con mis respetos, —V.»

El número es el del encargo. La carta no da ninguna pista de cuáles son.

### R3. Escapar (#120, aprobado el 2026-11-04: huida con la alarma)
- En `museum_v2` hay **4 salidas exteriores** (FEAT-034): P01 (vestíbulo), P02 (galería suroeste), P03 (muelle) y P38 (patio). Las cuatro dan al callejón, que es «fuera». El coche queda como decorado.
- **Los conductos no son salidas**: todas las rejillas dan a salas de dentro (R10).
- **Sin alarma** (como hasta ahora): el ladrón huye y gana al **cruzar cualquier salida con todas las piezas del encargo**. Sin todas, las salidas no hacen nada y el callejón es un pasillo más.
- **Con la alarma** (R7b), mientras corre la cuenta atrás y la salida no tiene la reja bajada, o, ya cerradas las rejas, por una salida cuya reja no bajó porque su caja está saboteada (R7c, #121), el ladrón **huye en el acto en cuanto está fuera** (en una zona de salida o ya en el callejón) con:
  - **el encargo completo**: **huida completa**, la de siempre (gana el ladrón, sello «ESCAPADO»);
  - **al menos 1 pieza del encargo**: **huida a medias** (R4: gana quien tenga más puntos, sello «HUIDA A MEDIAS»);
  - **0 piezas**: no pasa nada; la salida no le deja huir sin botín (decisión 2 de #120). Si sigue así al bajar las rejas, ganan los guardias (R7b).
- **Por qué «fuera» y no solo «cruzar»**: el ladrón empieza en el callejón y puede salir a él con piezas antes de la alarma para rodear el edificio. Si la alarma lo pilla fuera con botín, ya ha huido; si lo pilla fuera sin nada, no pierde en el acto (tiene la cuenta atrás para entrar a por una pieza).
- **Peso del botín** (FEAT-033): cada pieza del encargo que lleva le quita `loot_slow` de velocidad, hasta un mínimo de `loot_min_speed`.

### R4. Cómo se gana (reescrita el 2026-10-30, #116)
| Resultado | Sello | Cuándo |
|---|---|---|
| **Gana el ladrón** | «ESCAPADO» | Huida completa (R3): sale con todo el encargo, con o sin alarma, antes de que acabe el tiempo y de que bajen las rejas |
| **Gana quien tenga más puntos**, o empate (#120; con #123, el ladrón contra la puntuación de equipo de los guardias, R4b) | «HUIDA A MEDIAS» | Huida a medias (R3): con la cuenta atrás en marcha, sale con al menos 1 pieza del encargo pero sin todas |
| **Ganan los guardias** | «CAPTURADO» | Lo atrapan (la porra, como hoy) |
| **Ganan los guardias** (#120) | «ENCERRADO» | Bajan las rejas (R7b) con el ladrón dentro del edificio, también si está en un conducto, y no queda ninguna salida abierta (con #121, R7c: también cuando baja la última reja saboteada al repararla) |
| **Ganan los guardias** (#120) | «SIN BOTÍN» | Bajan las rejas con el ladrón fuera, en el callejón, sin ninguna pieza y sin ninguna salida abierta (decisión 2 de #120; R7c) |
| **Ganan los guardias** | «AMANECE» | Se acaba el tiempo sin que haya huido (`TIME_EXPIRED`) |

- Desde #116 no hay «ronda rota» (`TIME_EXPIRED_BREACH` y `TIME_EXPIRED_DRAW` siguen sin uso). Con #120 vuelve a haber **empate, solo en la huida a medias**.
- **Por qué**: sin relojes, el tiempo es la presión del ladrón; la de los guardias es que, si se quedan en la garita, él se lleva el encargo sin que nadie lo vea (R5, «Presión sobre los guardias»). Con #120, la alarma deja de ser «ya da igual, que me pillen»: es el momento de decidir entre una pieza más o salir con lo puesto.

#### R4b. Quién gana la huida a medias (#120; reescrita con #123, aprobado por el usuario el 2026-11-05)
> Reglas del usuario (#123, entrevista del 2026-11-05): las piezas cuentan por fracción del encargo, con una bolsa de 300; cada jugador tiene su puntuación individual completa, y en la huida a medias el ladrón se compara con la **puntuación de equipo** de los guardias. La definición de «puntos de equipo», el redondeo y los números los propone `game-designer`.

**Puntos de equipo y puntos personales.** Los puntos de los guardias son de dos clases:
- **De equipo**: los que gana el equipo entero por cómo acaba la noche, no un guardia por lo que hace él. Son dos **bolsas**, y nada más:
  - **proteger**: `team_protect_pool` × (k − s) / k, con s piezas del encargo robadas (300 × lo que queda en su sitio);
  - **encerrado**: `team_lockdown_pool`, si la partida acaba en «ENCERRADO» (nunca en una huida a medias).
- **Personales**: todo lo que hace cada guardia (alarma, verlo, engaños, walkie, golpe, captura, reparar, cabezadas y el −30 por un robo cerca; R11). La captura y el golpe son de quien los da, aunque el cerco sea de todos.

Con eso salen dos puntuaciones:
- **Individual** de cada guardia (su ficha del informe, «MEJOR DE LA NOCHE» y, más adelante, las rondas): sus personales + **su parte** de cada bolsa, `redondear(bolsa / G)`.
- **De equipo** (solo en la huida a medias): las bolsas **una vez** + los personales de todos entre √G. No se suman las partes de las fichas: si se sumaran, la bolsa contaría dos veces.

```
P_ladrón = total individual del ladrón (R11)
P_equipo = redondear( team_protect_pool × (k − s) / k  +  (Σ personales de los guardias) / √G )
gana el ladrón si P_ladrón > P_equipo · ganan los guardias si P_ladrón < P_equipo · empate si son iguales
```
| Variable | Significado | Fuente |
|---|---|---|
| `P_ladrón` | Su total individual: piezas, huida a medias, huida rápida, despistes, robo limpio, sabotaje, alarmas, vistas y golpes (R11) | `score_rules.tres` |
| `P_equipo` | La puntuación de equipo, la que sale en el veredicto | resultado, entero |
| `k`, `s` | Piezas del encargo (R1) y piezas del encargo en el maletín al acabar | estado del golpe |
| `team_protect_pool` | La bolsa de las piezas: 300, la misma que la del ladrón (`thief_piece_pool`) | `score_rules.tres` |
| `Σ personales` | La suma de los puntos personales de cada guardia con ficha, con sus negativos | `score_rules.tres` |
| `G` | Guardias con ficha al acabar: humanos y de IA, los que siguen en la partida | estado de la partida |

- **Rango** (huida a medias): «proteger» va de 300 / k (s = k − 1) a 300 × (k − 1) / k (s = 1), de 75 a 225; los personales entre √G suman de −50 a +300 en partidas normales (tabla de escenarios: de 3 a 175). El ladrón va de ~90 (1 pieza de 4 y una persecución) a ~400 (3 de 4, sin descubrir y deprisa).
- **Redondeo**: uno solo, al final, al entero más cercano y con los ,5 hacia arriba (como en #120); √G y la división van sin redondear. La parte de cada ficha se redondea igual, por separado, así que las fichas pueden no sumar justo la bolsa (con 4 guardias y 150 de «proteger», 37,5 → 38 cada uno). Se compara lo que se enseña.
- **Por qué √G**: la media de #120 (dividir entre G) hacía que más guardias no sumaran más; sumar sin dividir haría que 3 guardias valieran el triple que uno. Con √G el equipo crece con su número, pero menos deprisa. Y lo que mueve una pieza de un bando a otro (600 / k: 150, 200 y 300 con 1, 2 y 3 guardias) crece al mismo ritmo que √G (150 / 1, 200 / 1,41 y 300 / 1,73 dan 150, 141 y 173): la misma partida pesa parecido sea cual sea el número de guardias.
- **El equilibrio** (lo pidió el usuario): una **huida limpia** (una alarma porque un guardia lo ve una vez, y nada más) empata justo en la mitad del encargo, s = k/2, con cualquier número de guardias. En s = k/2 las piezas se anulan (el ladrón cobra 150 y «proteger» vale 150), así que el empate pide que la huida a medias compense la alarma de los dos lados: `E(G) = −thief_alarm − thief_seen + guard_alarm / √G`. Con −15, −10 y +50, `E(G)` = **75, 60, 54 y 50** con 1, 2, 3 y 4 guardias (`thief_partial_escape_by_guards`). Como las piezas se anulan en s = k/2 para cualquier k, el empate se mantiene aunque un guardia se desconecte (k no cambia y G sí; `E` y √G usan el mismo G).

| Guardias | Encargo k | Una pieza para el ladrón (300 / k) | Huida a medias `E` | Huida limpia con s = k/2 | Con una pieza menos | Con una pieza más |
|---|---|---|---|---|---|---|
| 1 | 4 | 75 | 75 | s = 2: **empate a 200** | s = 1: guardias, 275 a 125 | s = 3: ladrón, 275 a 125 |
| 2 | 3 | 100 | 60 | s = 1,5 no existe: el corte cae entre 1 y 2 | s = 1: guardias, 235 a 135 | s = 2: ladrón, 235 a 135 |
| 3 | 2 | 150 | 54 | s = 1: **empate a 179** | — | — |
| 4 (k como con 3, R1) | 2 | 150 | 50 | s = 1: **empate a 175** | — | — |

Con 3 o 4 guardias el encargo es de 2, así que toda huida a medias es de 1 pieza, justo la mitad: la deciden solo las acciones de cada bando. Es lo que se busca (la huida a medias es un duelo de juego), y la tabla de escenarios («Puntos (#123): tabla de escenarios») comprueba que ninguna acción suelta la decide siempre.

Ejemplo (2 guardias, encargo de 3, la partida «media» de la tabla de escenarios): el ladrón roba 2 piezas. El guardia A lo ve (alarma) y después pone una marca de walkie que acierta; el guardia B lo vuelve a ver más tarde (segunda alarma), le da un golpe, repara una caja y da una cabezada. El ladrón los despista una vez y sale con 10 s de cuenta atrás.
- Ladrón: 300 × 2/3 + 60 − 15 × 2 − 10 × 2 − 20 + 25 + 2 × 10 = 200 + 60 − 30 − 20 − 20 + 25 + 20 = **235**.
- Personales: A, 50 + 30 = 80; B, 25 + 50 + 40 − 15 = 100. Equipo: 300 × 1/3 + 180 / √2 = 100 + 127,3 = 227,3 → **227**.
- Veredicto: «Huida a medias: gana el ladrón, 235 a 227». Fichas: A, 80 + 50 = 130; B, 100 + 50 = 150; el ladrón, 235, es «MEJOR DE LA NOCHE».
- Con la misma partida y 1 sola pieza: ladrón 135, equipo 200 + 127 = 327; ganan los guardias.

### R5. El sueño y el café (reescrita el 2026-10-30, #116; sustituye a la regla de acampar)
- **La garita** es la sala del nivel marcada como puesto de los guardias: en `museum_v2`, el rectángulo entero de GAR (8 × 6 m, con la cafetera y la mesa de monitores). Todo lo demás es «fuera», también el vestuario, el pasillo de servicio y el umbral de la puerta P20. Dato de nivel nuevo: `"guard_post": true` en la sala (`data/levels/museum_v2.json`).
- **El sueño** es una barra de 0 a 1:
  - **fuera de la garita sube** a `rise_rate` por segundo, ande o esté quieto;
  - **dentro de la garita se congela**: ni sube ni baja, mire los monitores o no;
  - no sube mientras está despejado por un café, con la alerta en «alarma» ni mientras percibe al ladrón (como hasta ahora);
  - solo baja con el café (y con la adrenalina, R5b).
- Desaparece **acampar**: ya no se mide dónde ha estado el guardia (fuera `window`, `radius`, `linger_ratio` y `CampingMeter`).

```
t_bostezo = drowsy_at / rise_rate        t_cabezada = exhausted_at / rise_rate
```
| Variable | Significado | Fuente |
|---|---|---|
| `t_bostezo`, `t_cabezada` | Segundos fuera de la garita, desde el sueño 0 y sin contar el rato despejado, hasta el primer bostezo o la primera cabezada | resultado |
| `rise_rate` | Subida por segundo fuera | `guard_sleep.tres` |
| `drowsy_at`, `exhausted_at` | Umbrales de somnoliento y agotado | `guard_sleep.tres` |

Rango: con `rise_rate` entre 1/300 y 1/180 por s y los umbrales aprobados (0,75 / 1,0), el primer bostezo llega entre 135 y 225 s fuera y la primera cabezada entre 180 y 300 s. Con los valores aprobados, a los 180 y 240 s (los 3 y 4 minutos que pidió el usuario). Ejemplo: un guardia sale de la garita a 0:00; a 1:30 vuelve 40 s a mirar los monitores (sueño 0,375, congelado) y sale a 2:10. Le quedan 90 s fuera hasta 0,75: bosteza a 3:40. Si no va a por café, da la primera cabezada a 4:40.

- **Niveles**:

  | Sueño | Nivel | Efecto |
  |---|---|---|
  | < `drowsy_at` | Despierto | Ninguno |
  | ≥ `drowsy_at` | Somnoliento | Bosteza cada `yawn_interval` s: un ruido de radio `yawn_radius` que oye todo el mundo (el ladrón, a ×1,5). Sus alcances de vista se multiplican por `drowsy_sight` |
  | ≥ `exhausted_at` | Agotado | Lo anterior, y además da cabezadas: cada `nod_interval` s, durante `nod_time` s, no ve nada (ni con la linterna ni la proximidad; si mira los monitores, tampoco las cámaras). Puede seguir andando. Sobre él sale el «Zzz» |

- **El café**: E en la **cafetera de la garita** (`coffee_time` s, que suenan con radio `coffee_radius`).
  - Deja el sueño a 0 y da `fresh_time` s **despejado**: no sube aunque salga. El rato despejado corre también dentro de la garita (no se guarda para después).
  - Al empezar la partida, los guardias salen de la garita con el sueño a 0 y sin rato despejado.
- El guardia ve su nivel de sueño en el HUD (una taza que se vacía). El ladrón no lo ve, pero lo oye bostezar.
- **Cabezadas a la vista** (FEAT-033): sobre un guardia que da una cabezada sale un «Zzz» que ve cualquiera que lo tenga a la vista (la niebla lo oculta como al cuerpo).
- **Presión sobre los guardias** (sin relojes): en la garita no se duermen, pero desde ella solo ven lo que enseña, con luz, la cámara que tienen en pantalla, una sala cada vez (#118); el ladrón roba en silencio y escapa sin que nadie lo vea. Fuera ven y oyen, pero cada 3-4 minutos el sueño los devuelve a la garita. El ritmo de los guardias es ese vaivén, y el ladrón lo oye (bostezos, café, la puerta que cruje).

### R5b. Somnífero, adrenalina y bajón (FEAT-033)
- **Somnífero**: el ladrón tiene `drug_doses` dosis por partida. Con E en la cafetera la droga en silencio (`drug_time` s, sin alejarse). Solo él sabe que está drogada.
  - El siguiente guardia que termina un café se queda **dormido** `drug_nap_time` s (no ve nada, «Zzz») y despierta agotado: necesita otro café, que ya es normal.
  - La alarma no despierta a un guardia drogado.
- **Adrenalina**: al pasar la alerta a «alarma», el sueño de todos los guardias vuelve a 0.
- **Bajón**: cuando se apagan unas luces de alarma, el sueño de todos los guardias sube de golpe hasta `crash_level` (salvo a quien esté despejado por un café). Encender las luces tiene precio.
  - 2026-10-30, #116: con la alarma el sueño ya no sube, así que el bajón se queda donde lo deja hasta el próximo café. Por eso `crash_level` tiene que ser ≥ `drowsy_at` (si no, el bajón no hace nada): 0,85, somnoliento sin cabezadas.

### R5c. La IA sin red patrulla salas (2026-10-30, #116; sustituye a las rutas de relojes)
- **Duerme como un humano**: los guardias de IA tienen el mismo sueño, bostezos, cabezadas y café que los humanos (hasta ahora no dormían). El somnífero del ladrón también les afecta.
- **Elige sala**: al empezar y cada vez que termina una sala, elige la siguiente al azar, con peso:

```
w(sala) = 1 + ai_piece_weight × n(sala)
```
| Variable | Significado | Fuente |
|---|---|---|
| `w` | Peso de la sala en el sorteo | resultado, ≥ 1 |
| `n` | Candidatas de esa sala que siguen siéndolo para los guardias (las descubiertas como robadas, R6, ya no cuentan; las robadas sin descubrir, sí: la IA no sabe más que un humano) | estado del golpe |
| `ai_piece_weight` | Cuánto tira cada pieza | `guard_patrol.tres` (nuevo) |

  - Quedan fuera del sorteo: la garita, los pasillos (PS y EPS solo se cruzan), las últimas `ai_room_memory` salas que visitó ese guardia y la sala a la que va otro guardia de IA.
  - Rango: una sala vacía pesa 1; con `ai_piece_weight` = 1,5, una con 3 piezas pesa 5,5. Ejemplo en `museum_v2` (14 salas con piezas, 20 piezas, 4 salas de destino vacías: ANTE, MNT, VEST y DOCK): suma 1 × 18 + 1,5 × 20 = 48; Antigüedades (3 piezas) sale el 11 % de las veces y alguna sala vacía, el 8 %.
- **En la sala**: va andando por el camino de salas y puertas (el grafo de salas), pasa junto a cada candidata de la sala (o por su centro, si no tiene) y se para `ai_room_dwell` s girando la linterna antes de elegir la siguiente.
- **A por café**: cuando su sueño llega a `ai_coffee_at`, deja lo que hace y va a la cafetera; al terminar el café elige sala. Perseguir e investigar mandan sobre el café. Con los valores aprobados va al primer bostezo: el ladrón la oye bostezar de camino a la garita.
- Con la alarma, el sueño no sube y la IA no necesita café; tras el bajón de las luces de alarma (R5b, `crash_level` ≥ `ai_coffee_at`) vuelve a por él, como haría un humano.

### R5d. Los guardias andan; solo corren con la alarma (2026-10-30, #116)
- Mientras la alerta no está en «alarma», el guardia no corre: la tecla de correr no hace nada (anda), y el HUD lo dice bajo la taza del sueño con «Correr: solo con la alarma» mientras mantiene la tecla. Puede andar o ir en sigilo.
- Desde que salta la alarma, y hasta el final porque la alerta nunca baja (R7), corre como hasta ahora, gastando estamina.
- La IA, igual: patrulla e investiga andando; con la alarma corre al perseguir y al investigar. Como ver al ladrón ya hace saltar la alarma (R7), toda persecución es con carrera.
- El ladrón no cambia: corre siempre (`stealth.md` A3).
- **Por qué**: sin rondas ya no hace falta correr para llegar a tiempo, y un guardia que corre en calma cruza el museo a 6,3 m/s. Andando (4,2 m/s), en calma el ladrón decide el ritmo; con la alarma, los guardias cierran el cerco.

### R6. Rastros
- Cada pieza robada deja su **pedestal vacío**, salvo el cambiazo, que deja una falsificación (R9b; no es rastro hasta que un guardia la examina). El de un sensor puenteado se anuncia como «sensor puenteado» (#119, aprobado por el usuario el 2026-11-04).
- Cuando un guardia lo ve, o lo ve la cámara que está en pantalla mientras alguien mira los monitores (2026-11-04, #118: las demás no ven nada, `interaction.md` M5), el rastro queda **descubierto**:
  - aparece en el plano de todo el equipo;
  - sube la alerta (R7);
  - esa pieza deja de ser candidata en el plano de los guardias. Saben que el ladrón la tenía en su lista y deducen cuántas le quedan.
- Un rastro solo se descubre una vez.

### R7. Nivel de alerta
| Nivel | Se llega con | Qué ganan los guardias |
|---|---|---|
| **Calma** | Al empezar | — |
| **Sospecha** | 1 rastro descubierto | Los rastros se ven en el plano del equipo (R6) |
| **Alarma** | 2 rastros descubiertos, que un guardia (o una cámara vigilada: desde #118, solo la que está en pantalla en la mesa) vea al ladrón, o un robo a lo bruto (R9) | Encender de golpe todas las luces de un ala durante 30 s (decisión 1). El sueño deja de subir. Pueden correr (R5d, desde el 2026-10-30). Empieza la cuenta atrás de las rejas (R7b, #120) |

- La alerta **nunca baja** durante la partida.
- Todos la ven, el ladrón también: sabe que le han descubierto, y la tensión sube.
- **Campanas en el plano** (2026-11-04, #117): cada vez que salta la alarma queda una campana con «hace m:ss» en el plano de los dos bandos (las 8 últimas). Va donde saltó:
  - un guardia o una cámara vigilada (la que está en pantalla, #118) ve al ladrón: donde estaba el ladrón en ese momento (excepción a la percepción por guardia, ver `stealth.md` P2.3);
  - robo a lo bruto: en la pieza;
  - 2 rastros descubiertos: en el último rastro, nunca donde está el ladrón.
- **Luz en el plano** (#117; #119: sin cuadros eléctricos que cortar): solo el ladrón ve en su plano cuánta luz da cada sala. El de los guardias enseña las lámparas siempre en estado normal: apagar una luz no se ve desde el plano, hay que ir o mirarla por la cámara en pantalla (pilar 3). Con el cursor sobre un interruptor se ven los cables a sus lámparas; desaparecen de las leyendas el icono del cuadro eléctrico y el de la mesa de copias.
- **Rastros para la alarma** (#119): solo cuentan las piezas descubiertas (R6); los cortes de corriente desaparecen.

### R7b. La cuenta atrás de las rejas (#120, aprobado por el usuario el 2026-11-04)
> Regla decidida por el usuario tras el playtest (#120): «con la alarma, 30 s para huir con lo puesto o quedar encerrado». Los detalles los propuso `game-designer` y el usuario los aprobó el 2026-11-04.

- **Cuándo empieza**: la primera vez que la alerta pasa a «alarma», por cualquier causa (lo ven, dos rastros, robo a lo bruto). Dura `lockdown_time` s.
- **No se para ni vuelve a empezar**: la alarma nunca baja (R7), así que la cuenta atrás tampoco. Las alarmas siguientes cuentan en el informe (−25 cada una) pero no la alargan ni la reinician. Ninguna acción de ningún bando la detiene (con #121, sabotear una caja no la para: solo deja abierta esa salida).
- **La ven los dos bandos**, grande, arriba en el centro de la pantalla: «REJAS 0:30» en mayúsculas de cabecera (`estilo-de-textos.md`). En los últimos `lockdown_warn_at` s late en rojo. La pausa no la detiene en red (como el reloj de la partida).
- **Si queda menos partida que cuenta atrás**: el número grande enseña lo que llegue antes (`t = min(lockdown_time − t_desde_alarma, match_timer)`). Si llega antes el final del tiempo, es «AMANECE» como siempre; la partida no se alarga (decisión 5 de #120).
- **El timbre**: desde que salta la alarma y hasta el final de la partida suena el timbre de alarma del museo, una campana eléctrica de 1984 (pilar 1), en todo el edificio y para todos por igual (no posicional). Es distinto de la campana corta de un robo a lo bruto (R9), que sí suena en la sala.
  - **No es un ruido de juego**: la percepción de los guardias (humanos o IA) no lo «oye», no despierta a nadie ni sube nada.
  - **No tapa la información** (pilar 2): se mezcla por debajo de los pasos, las puertas y las rejillas. Para eso suena a golpes (no un pitido continuo) y a volumen bajo. El ritmo de los golpes se acelera en los últimos `lockdown_warn_at` s. Bajar el volumen mientras suena un ruido de juego cercano queda para después del playtest, si hace falta.
  - El sonido se sintetiza en código (`AlarmBellSounds`, como los clics del dial): no hay archivo de sonido ni ficha de licencia (regla 02).
- **Las rejas**: cada salida exterior tiene una reja de barrotes de acero recogida sobre la puerta, a la vista de todos desde el principio (en P03, la propia persiana del muelle hace de reja).
  - Empiezan a bajar a los `lockdown_time − gate_drop_time` s, todas a la vez, con un chirrido metálico que se oye en su salida (radio `gate_radius`), y tocan el suelo a los `lockdown_time` s con un golpe seco.
  - **Mientras bajan, la salida sigue abierta**: se puede pasar por debajo hasta el último instante. Al tocar el suelo, la salida queda **cerrada**: no se cruza (tapa el paso a los dos bandos) y ya no deja huir. Entre los barrotes se ve: la reja tapa el paso, no la vista.
- **Al cerrarse las rejas**, si el ladrón no ha huido y no queda ninguna salida abierta (R7c), la partida acaba en el acto y ganan los guardias:
  - dentro del edificio, también en un conducto (R10): sello **«ENCERRADO»**;
  - fuera, en el callejón, sin ninguna pieza: sello **«SIN BOTÍN»** (con al menos una ya habría huido, R3).
- **La IA sin red** (decisión 7 de #120): durante la cuenta atrás, el guardia de IA que no persigue ni investiga va corriendo a la salida libre más cercana a la última campana (una salida por guardia, sin repetir la de otro) y espera allí girando la linterna. Con #121 (R7c), mira la caja de esa salida al llegar y, si está saboteada, la repara; con las rejas cerradas, solo cubre las salidas que siguen abiertas.
- **Orden en el mismo instante**: captura > huida > rejas > fin del tiempo. Quien está en una zona de salida con botín en el instante en que la reja toca el suelo, huye.
- **Con #121** (R7c, aprobado por el usuario el 2026-11-05): una salida con su caja saboteada no baja la reja. Si al cumplirse la cuenta atrás queda **alguna salida abierta**, la partida **no** acaba en el acto: sigue, con el timbre sonando, hasta que el ladrón huya por una salida abierta (con las mismas reglas de R3), lo atrapen o amanezca. «ENCERRADO» pasa a ser «bajan las rejas y no queda ninguna salida abierta».

```
t_rejas = min(lockdown_time − (t_ahora − t_alarma), match_timer)
```
| Variable | Significado | Fuente |
|---|---|---|
| `t_rejas` | Lo que enseña la cuenta atrás grande | resultado, de `lockdown_time` a 0 |
| `t_alarma` | Instante en que la alerta pasó a «alarma» por primera vez | `AlertDirector` |
| `lockdown_time` | Duración de la cuenta atrás | `heist_rules.tres` |
| `match_timer` | Lo que le queda a la partida | `GameManager` |

Rango: con `lockdown_time` entre 20 y 45 s. La ruta más larga de `museum_v2` desde una pieza hasta la salida más cercana ronda los 45 m (Arte Oriental → P38, la Cámara de la Pieza Maestra → P01); el ladrón corriendo con 3 piezas va a 7,5 × 0,85 = 6,4 m/s (R3, peso del botín), unos 7 s. Un guardia corriendo (6,3 m/s) va de la garita a la salida más lejana, P02 (~45 m), en unos 7 s: cada guardia llega a cubrir una salida, pero 2-3 guardias no cubren las 4. Ejemplo: salta la alarma a 7:12 de partida (le quedan 4:48); la cuenta atrás va de 0:30 a 0:00 y las rejas tocan el suelo a 7:42; empiezan a bajar a 7:40,5.

### R7c. Sabotear la caja de la reja (#121, aprobado por el usuario el 2026-11-05)
> Regla decidida por el usuario tras el playtest (#121): «sabotear la reja de una salida para poder huir aunque salte la alarma». Los detalles (el minijuego, qué se nota, qué hace la IA y los casos límite) los propuso `game-designer` y el usuario los aprobó el 2026-11-05.

- **No es un robo.** La caja de la reja no protege ninguna pieza ni hace falta para robar nada: la regla de R9 («todo lo necesario para robar una pieza está en la propia pieza») sigue intacta. Sabotear es **preparar la huida**, opcional y en otro sitio del mapa, como apagar una luz o abrir una rejilla. Por eso tiene sus propias reglas, que se parecen a R9a pero no son iguales (ver «Qué cambia respecto a R9a»).
- **La caja**: cada salida exterior tiene una **caja de la reja** en la pared de dentro, junto a la puerta (una caja de chapa gris con cuatro tornillos y una placa «REJA»), a la altura de la mano. Es el freno de la reja: mientras está entera, la reja baja con la alarma (R7b). En `museum_v2`, una por salida (P01, P02, P03 y P38: cuatro cajas). Sale en el plano de los dos bandos como un icono fijo, sin estado.
- **Por qué funciona** (pilar 1): la caja tiene un **circuito de seguridad**. Si se corta un cable fuera de orden, el relé salta (chispazo); si la tapa se queda abierta, su microinterruptor suelta el freno y la reja baja igual. Por eso hay que quitar la tapa, cortar en orden y volver a cerrarla.

#### El minijuego: «Sabotear la reja»
E junto a una caja entera abre el minijuego. Tres pasos seguidos, en este orden:

| Paso | Qué hace el ladrón | Teclas | Cómo se falla | Se oye |
|---|---|---|---|---|
| **1. Quitar la tapa** | Desatornilla los `box_screws` tornillos, uno tras otro, `box_screw_time` s cada uno, mientras mantiene E | Mantener E. Soltar E pausa: los tornillos ya quitados se quedan fuera y el que estaba a medias vuelve a empezar | No se falla: es tiempo | Un chirrido de tornillo de radio `work_noise_radius` (2 m) por tornillo |
| **2. Cortar los cables en orden** | Dentro hay `box_wires` cables de colores, enredados, que van de un lado (donde se cortan) a unos bornes numerados del 1 al 4 en el otro. Hay que cortar primero el que llega al borne 1, después el del 2, y así. Se elige el cable por su punta con ← → (o A D) y se corta con E | ← → o A D eligen; E corta | Cortar un cable que no toca: **chispazo** (ruido de fallo, `fail_noise_radius`, 7,5 m, como fallar un número del dial) y `box_splice_time` s empalmándolo, sin poder hacer nada. Los cables bien cortados siguen cortados | Un chasquido de 2 m por cable bien cortado |
| **3. Cerrar la tapa** | Vuelve a atornillar los tornillos, como en el paso 1 | Mantener E, igual que el paso 1 | No se falla | Igual que el paso 1 |

- **Al acabar el paso 3, la caja queda saboteada**. Antes no hace nada: con la tapa fuera, la reja baja igual.
- **Los cables**: el orden (qué cable llega a cada borne) lo sortea el servidor para cada caja al empezar la partida y otra vez cada vez que un guardia la repara, así que no se aprende de memoria. Cada cable bien cortado queda flojo en el dibujo, y lo que falta por seguir se ve más claro. Los cables se distinguen por el color **y por el dibujo** (liso, rayado, punteado, a cuadros), para no depender solo del color.
- **Duración**: unos 15-17 s si se hace bien, con cada fallo sumando unos 2 s (fórmula abajo). Es el doble que robar una pieza en silencio: sabotear es una inversión.
- **Textos** (`estilo-de-textos.md`): en una caja entera, «Sabotear la reja [E]»; a medias, «Seguir con la reja [E]»; saboteada, «Reja saboteada» (sin tecla). Mientras dura, «Quitando la tapa…», «Corta los cables por orden de borne» (con la línea de teclas «← → elegir · E cortar») y «Cerrando la tapa…». Con su reja ya bajando o bajada, «La reja ya ha bajado». Q no hace nada en la caja (no hay sabotaje a lo bruto) y no sale en el aviso.

```
T = 2 × box_screws × box_screw_time + box_wires × t_cable + f × box_splice_time
```
| Variable | Significado | Fuente |
|---|---|---|
| `T` | Segundos del sabotaje entero, sin interrupciones | resultado |
| `box_screws` | Tornillos de la tapa (se quitan en el paso 1 y se ponen en el 3) | `heist_rules.tres` |
| `box_screw_time` | Segundos por tornillo | `heist_rules.tres` |
| `box_wires` | Cables que hay que cortar | `heist_rules.tres` |
| `t_cable` | Lo que tarda el jugador en seguir un cable con la vista, elegirlo y cortarlo (~1-1,5 s; menos con cada cable cortado) | jugador |
| `f` | Cables mal cortados | jugador |
| `box_splice_time` | Segundos empalmando tras un fallo | `heist_rules.tres` |

Rango: con los valores propuestos (4 tornillos de 1,25 s, 4 cables, 2 s de empalme), los pasos 1 y 3 son 10 s fijos y el 2, de 4 a 6 s sin fallos: `T` va de 14 a 16 s, y con un fallo, de 16 a 18 s. Es la franja de 15-20 s que pidió el usuario. Ejemplo: `t_cable` = 1,25 s y un fallo: 2 × 4 × 1,25 + 4 × 1,25 + 1 × 2 = 10 + 5 + 2 = **17 s**.

#### Qué cambia respecto a R9a
- **Igual que R9a**: el ladrón está **quieto** mientras trabaja; lo **cancela** alejarse más de `task_leash` m, cualquier tecla de movimiento que el paso no use (en los pasos 1 y 3, todas; en el 2, W y S), Esc, un golpe de porra o la captura; cancelar **no hace ruido**; fallar suena a `fail_noise_radius` y **nunca hace saltar la alarma**; trabajar se oye a `work_noise_radius`; trabajando se le ve y se le oye como siempre (si lo ven, salta la alarma, R7, y puede terminar).
- **Distinto de R9a: se retoma.** Cancelar no lo devuelve a cero: el estado queda **en la caja** (los tornillos quitados siguen fuera y los cables cortados siguen cortados) y E lo retoma desde ahí. Solo se pierde el tornillo que estaba a medias. Es lo que pide el issue («se retoma desde el paso alcanzado») y es lo físico: lo hecho en la caja se queda hecho. En una pieza no tiene sentido porque el robo es un único gesto.
- **Q no hace nada** en la caja.

#### El efecto
- **Con la alarma**, una reja cuya caja está saboteada **no baja**: cuando las demás empiezan a bajar (a `lockdown_time − gate_drop_time` s), la suya suelta un zumbido del motor y un chasquido seco que se oyen en su salida (radio `gate_radius`, como el chirrido de las otras), y se queda recogida. La salida sigue **abierta**: se huye por ella con las reglas de R3, aunque la cuenta atrás haya terminado.
- **Lo que cuenta** es el estado de la caja en el instante en que las rejas empiezan a bajar. Una caja que se termina de sabotear después, con su reja ya bajando o bajada, no hace nada: **sabotear no vuelve a subir una reja**. Por eso, con la reja bajando o en el suelo, la caja ya no se puede sabotear («La reja ya ha bajado»). Si el ladrón está a mitad de sabotaje en ese instante, el minijuego se corta (sin ruido).
- **Durante la cuenta atrás** se puede sabotear (si da tiempo: unos 15 s de los 28,5 antes de que bajen). Es la jugada desesperada de quien está cerca de una caja.
- **Sin aviso**: la alarma, el timbre y la cuenta atrás suenan y se ven igual. Nada avisa a los guardias de que una caja está saboteada antes de que bajen las rejas: ni la garita, ni el plano, ni la cuenta atrás.
- **Al cerrarse las rejas con alguna salida abierta**:
  - la partida sigue (R7b), con el timbre sonando, hasta que el ladrón huya por una salida abierta, lo atrapen o amanezca;
  - la cifra grande cambia a «REJAS CERRADAS · 1 SALIDA ABIERTA» (o «2 SALIDAS ABIERTAS»…), para los dos bandos;
  - las salidas abiertas se marcan en el plano de los dos bandos. Ya no es un secreto: la reja recogida se ve desde la sala y el callejón y el chasquido se ha oído en la salida.
- **Sin límite de cajas**: el límite es el tiempo (el issue). Sabotear las cuatro cuesta más de un minuto (ver «El riesgo de sabotearlo todo»).

#### La contra: notarla y repararla
- **Se nota de cerca**:
  - **la tapa mal cerrada**: un guardia que tiene la caja en su zona visible (`vision.md` R1) y a menos de `box_notice_distance` m la ve torcida, con un tornillo flojo. Más lejos parece entera. Una caja a medias (tapa fuera o en el suelo, cables a la vista) se nota igual, a la misma distancia;
  - **la chispa**: una caja saboteada echa una chispa cada `box_spark_min`-`box_spark_max` s (al azar). Es un destello que ve cualquiera que tenga la caja en su zona visible, a cualquier distancia, y un chisporroteo de radio `box_spark_radius` m que se oye como cualquier ruido (pilar 2): la percepción de los guardias lo oye y la IA lo investiga. Nadie distingue una chispa de otro ruido pequeño hasta que va a mirar. Una caja a medias no echa chispas.
- **Reparar**: un guardia junto a una caja saboteada o a medias ve «Reparar la caja de la reja [E]» (en una caja entera no sale nada: no hay nada que revisar a ciegas). Son `box_repair_time` s quieto, con «Reparando la caja…» y un ruido de trabajo de 2 m cada segundo que el ladrón oye si está cerca. Se cancela como un minijuego (R9a) y, si se cancela, vuelve a empezar de cero (es un solo gesto, como examinar). Al acabar, la caja queda entera, con un orden de cables nuevo, y el guardia gana `guard_repair` (+40).
- **Reparar con las rejas ya bajando o en el suelo**: la reja de esa salida baja entonces, en `gate_drop_time` s y con su chirrido. Si era la última salida abierta, al tocar el suelo acaba la partida como en R7b («ENCERRADO» o «SIN BOTÍN», con +100 de «encerrado» a cada guardia). Reparar durante la cuenta atrás, antes de que bajen, deja la caja entera: la reja baja con las demás.
- **No es un rastro** (R6): notar o reparar una caja no sube la alerta ni sale en el plano del equipo. Para contarlo, el walkie (R8). Lo que gana el guardia es el +40 y saber que el ladrón piensa salir por ahí.
- **Las cámaras**: la cámara en pantalla ve al ladrón saboteando, como siempre (y salta la alarma). La tapa torcida no se distingue en el monitor; **la chispa sí**, porque es luz: un guardia que mira justo esa cámara puede verla. No es un aviso: hay que estar mirando esa sala en ese momento.
- **Lo que sabe el ladrón**: su plano marca sus cajas saboteadas tal como las vio por última vez (la memoria de `vision.md`). Si un guardia repara una a sus espaldas, no lo sabe hasta que pasa a verla, oye la reparación o, con la alarma, oye bajar esa reja.

#### La IA sin red
- **Patrulla** (R5c): en una sala con caja de reja (VES, GSW, DOCK y PAT), pasa junto a la caja como pasa junto a cada candidata. Sin peso extra en el sorteo de salas.
- **Nota y repara** como un humano: si ve una caja saboteada o a medias a menos de `box_notice_distance` m, o investiga una chispa y la encuentra, la repara (salvo si persigue o investiga otra cosa, que manda). No sabe más que un humano: no va a las cajas a tiro hecho.
- **Durante la cuenta atrás** (R7b, decisión 7 de #120): no sabe qué salidas están saboteadas, así que las cubre igual que hasta ahora; al llegar, la caja de su salida está a menos de 3 m de donde espera, así que la ve y, si está saboteada, la repara (8 s quieto en la salida).
- **Con las rejas cerradas y alguna salida abierta**: cubre solo las salidas abiertas (una por guardia, la más cercana a la última campana) y repara su caja al llegar. Si hay más guardias de IA que salidas abiertas, los que sobran persiguen, investigan o vuelven a patrullar.

#### El riesgo de sabotearlo todo (pilar 4)
- **Coste**: unos 15 s por caja y unos 25 s de camino entre las cuatro (por el callejón, que sin alarma es un pasillo más): **~85 s para las cuatro**, el 12 % de una partida de 12 minutos, quieto junto a salidas con cámara (las cuatro salas de salida tienen una) y con P03 a pocos metros de la garita.
- **Respuesta**: reparar cuesta 8 s, la mitad que sabotear, y da +40. Las cuatro cajas están en el muro sur, en salas por las que se pasa. Con las rejas cerradas, los guardias saben qué salidas siguen abiertas y corren a repararlas (~7 s de carrera y 8 s de reparación): el sabotaje compra **unos 15 s de huida extra por salida**, no una partida sin cuenta atrás. Con 2 guardias, sabotear 3 o 4 cajas sí los desborda: es el caso a vigilar («Qué medir»).
- **Sin alarma, el sabotaje no da nada** salvo los +30 por caja, que solo cuentan para «MEJOR DE LA NOCHE»: sin alarma no hay huida a medias (R3), y la huida completa o el final por tiempo deciden la partida sin puntos (R4b).

### R11. Informe de la noche (FEAT-041; sin relojes ni faltas desde el 2026-10-30, #116; puntos de #123 aprobados el 2026-11-05)
- Al acabar la partida, todos los personajes se quedan quietos y el informe ocupa la pantalla: primero un sello 1,5 s («ESCAPADO», «HUIDA A MEDIAS», «CAPTURADO», «ENCERRADO», «SIN BOTÍN» o «AMANECE»; #120 añade los tres nuevos), después el veredicto y una ficha por jugador.
- **Veredicto de la huida a medias** (#120; con #123, contra la puntuación de equipo): como siempre «HAS GANADO», «HAS PERDIDO» o «EMPATE» según el bando local, y debajo la cuenta de R4b: «Huida a medias: gana el ladrón, 235 a 227», «Huida a medias: ganan los guardias, 327 a 135» o «Huida a medias: empate a 179». El primer número es siempre el del bando que gana (en el empate, uno solo). Debajo, en pequeño, «Equipo: 100 de las piezas + 127 de lo que hicisteis» para que se entienda de dónde sale (texto a pulir en la FEAT con `estilo-de-textos.md`).
- **Ladrón**: (con #121) las rejas saboteadas al acabar y si huyó por una; cada pieza del encargo con ✔/✘, cómo se robó (abriendo el dial, a lo bruto, con el cambiazo, puenteando el sensor) y, con #123, si nadie la notó («robo limpio»); alarmas que hizo saltar, monedas, veces que lo vieron, golpes que recibió, veces que los despistó y la hora de la huida («Huida a medias» o «Huida», con los segundos de cuenta atrás que le sobraban).
- **Cada guardia**: (con #121) cajas reparadas; con #123, si dio la alarma, veces que vio al ladrón (cuenta cuando empieza a verlo; perderlo menos de 2 s no cuenta otra vez), falsificaciones descubiertas, marcas de walkie que acertaron, robos cerca de él, golpes de porra, captura, cabezadas y su parte de «proteger» y «encerrado».
- **Puntos** (#123, aprobado por el usuario el 2026-11-05; `score_rules.tres`). Deciden la huida a medias (R4b); en los demás finales solo dan «MEJOR DE LA NOCHE», la mayor puntuación **individual** (si empatan, el ladrón o el guardia de número más bajo, como hasta ahora). Cada jugador tiene la suya completa: es la que sumarán las rondas (fuera de #123, en su propio issue).

  **Ladrón**

  | Acción | Puntos | Campo | Cuándo exactamente | En vivo |
  |---|---|---|---|---|
  | Piezas robadas | 300 × s / k (75, 100 o 150 cada una con 1, 2 o 3 guardias) | `thief_piece_pool` (antes `thief_piece`, +100 por pieza) | Cada pieza del encargo en el maletín al acabar, acabe como acabe | Sí, al robarla |
  | Huida completa | +150 | `thief_escape` (sin cambios) | Sale con todo el encargo, con o sin alarma | Al acabar |
  | Huida a medias | +75, +60, +54 o +50 con 1, 2, 3 o 4 guardias (R4b) | `thief_partial_escape_by_guards` (antes `thief_partial_escape`, +50) | Huida a medias (R3), con G = guardias con ficha al acabar. No se suma a la huida completa | Al acabar |
  | Huida rápida | +2 por segundo entero de cuenta atrás que sobra | `thief_fast_escape` | Huida completa o a medias con la cuenta atrás en marcha: `floor(lockdown_time − (t_huida − t_alarma))` × 2, de 0 a 60. Sin alarma o con las rejas ya cerradas, 0 | Al acabar |
  | Despistar | +25 | `thief_lose_them` | Tras un rato en que algún guardia lo veía, `lose_them_time` (8) s seguidos sin que ningún guardia lo vea ni le golpee. Uno por cada vez que lo ven (vuelve a contar solo si lo ven otra vez). Si huye o acaba la partida antes de los 8 s, no cuenta | Sí |
  | Robo limpio | +20 por pieza | `thief_clean_piece` | Pieza robada con E (en silencio) cuyo rastro sigue sin descubrir al acabar (R6). Una falsificación sin examinar cuenta; una pieza robada a lo bruto, nunca | Solo en el informe |
  | Rejas saboteadas | +30 por caja | `thief_sabotage` (sin cambios, #121) | Caja saboteada al acabar | Al acabar |
  | Huida por una reja saboteada | +60 | `thief_sabotage_escape` (sin cambios, #121) | Huye por una salida con su caja saboteada después de cerrarse las demás rejas | Al acabar |
  | Alarma | **−15** (antes −25) | `thief_alarm` | Cada vez que salta la alarma (como hasta ahora: dos llamadas a menos de 3 s son la misma) | Sí |
  | Visto | −10 | `thief_seen` (sin cambios) | Cada vez que un guardia empieza a verlo (2 s, como hasta ahora) | Sí |
  | Golpe recibido | −20 | `thief_hit_taken` | Cada golpe de porra que recibe (con 2 golpes lo capturan, así que en una huida a medias es como mucho uno) | Sí |
  | Monedas | 0 | — | No puntúan (lo decidió el usuario) | — |

  **Guardias, personales**

  | Acción | Puntos | Campo | Cuándo exactamente | En vivo |
  |---|---|---|---|---|
  | Alarma | +50 | `guard_alarm` | Al guardia que hace pasar la alerta a «alarma»: lo ve él o lo ve la cámara que tiene en pantalla. Propuesta: también quien descubre el rastro que la hace saltar (el segundo). Una vez por partida. Un robo a lo bruto no da la alarma a nadie | Sí |
  | Verlo | +25 | `guard_seen` (sin cambios) | Cada vez que empieza a verlo tras 2 s sin verlo, salvo la vez que da la alarma (esa vale +50, no +75) | Sí |
  | Descubrir un engaño | +40 | `guard_examine_fake` | Examina una pieza y es una falsificación (R9b) | Sí |
  | Walkie que acierta | +30 | `guard_walkie` | A quien puso la marca, si en `walkie_hit_window` (10) s otro guardia empieza a verlo con el ladrón a menos de `walkie_hit_radius` (6) m de la marca. Una vez por marca | Sí |
  | Robo cerca | −30 | `guard_near_theft` | A cada guardia que está a menos de `near_theft_radius` (5) m de una pieza, en línea recta y sin muro entre medias, en el instante en que sale en silencio (E). Despierto o dando una cabezada | Solo en el informe |
  | Golpe | +50 | `guard_hit` (sin cambios) | Cada golpe de porra que acierta | Sí |
  | Captura | +150 | `guard_capture` (sin cambios) | Al que da el golpe que lo atrapa | Al acabar |
  | Reparar | +40 | `guard_repair` (sin cambios, #121) | Cada caja de reja saboteada o a medias que repara | Sí |
  | Cabezada | −15 | `guard_nap` (sin cambios) | Cada cabezada | Sí |

  **Guardias, de equipo** (bolsas, R4b): cada ficha lleva su parte, `redondear(bolsa / G)`; la puntuación de equipo, la bolsa entera una vez.

  | Bolsa | Puntos | Campo | Cuándo exactamente | En vivo |
  |---|---|---|---|---|
  | Proteger | 300 × (k − s) / k | `team_protect_pool` (antes `guard_protect`, +60 por pieza a cada guardia) | Piezas del encargo en su sitio al acabar, en cualquier final. Una falsificación, descubierta o no, no está en su sitio | Solo en el informe |
  | Encerrado | 150 | `team_lockdown_pool` (antes `guard_lockdown`, +100 a cada guardia) | Sello «ENCERRADO» (no con «SIN BOTÍN») | Al acabar |

  - **En vivo** (lo decidió el usuario): cada jugador ve solo **su** total individual en el HUD y, al puntuar, un aviso breve con el valor y el motivo («+25 VISTO», «−15 ALARMA», «+25 DESPISTADO»; los textos, en la FEAT con `estilo-de-textos.md`). Nunca el del rival ni el de los compañeros. Robo limpio, «proteger» y el −30 por un robo cerca solo salen en el informe, porque dan información oculta (cuántas piezas faltan, que un robo pasó a su lado sin que lo viera). El total en vivo del guardia no lleva su parte de las bolsas. Viaja en el estado privado de cada jugador (`get_net_state_private()`).
  - **Con #121**: la huida por una reja saboteada suma +90 al ladrón (30 + 60), y como la cuenta atrás ya ha acabado, sin huida rápida. Con 2 guardias y 1 pieza, en una huida limpia: 100 + 60 − 15 − 10 + 30 + 60 = **225**, contra 200 + 50 / √2 = **235**: ganan los guardias por 10, y un despiste (+25) o que la pieza siga sin descubrir (+20) le dan la vuelta. La preparación pesa casi una pieza, pero ya no gana sola (con los números de #120 ganaba con holgura). Si el guardia B llega antes y repara P02, la última salida abierta: «ENCERRADO»; fichas A 50 + 100 + 75 = 225 y B 40 + 100 + 75 = 215.
  - 2026-10-30, #116: fuera los puntos por reloj (`guard_clock`) y por falta (`guard_fault`); la hoja de ronda desaparece del informe.
  - **La garita**: un guardia que se queda toda la partida en ella y no ve al ladrón solo cobra su parte de «proteger», la misma que los que patrullan, pero nada de alarma, verlo, engaños ni reparar, que piden salir o estar atento a la cámara en pantalla. En la puntuación de equipo, sus personales a 0 no restan, pero tampoco suman.
- **Acciones**: «REVANCHA» (todos votan, mismos bandos), «VOLVER A LA SALA» (con red: cualquiera con bando lleva a todos a la sala sin desconectar, para cambiar de bandos) y «SALIR».

### R8. Una herramienta por bando
- **Ladrón: monedas.**
  - Tiene `coins` por partida.
  - Se apunta manteniendo el botón de lanzar: el ladrón ve el arco, un aro donde caerá (el punto del ratón, a `throw_range` m como máximo) y, tenue y discontinuo, hasta dónde se oirá (`coin_radius`). Al soltar se lanza; el clic izquierdo cancela sin gastarla (FEAT-038).
  - Vuela en arco `coin_flight_time` s a todo el alcance (menos si cae más cerca), por encima de los muebles bajos y por los vanos; se para contra muros y puertas cerradas.
  - Suena al caer, con radio `coin_radius`, y brilla en el suelo `coin_glint_time` s antes de desaparecer.
  - La moneda en vuelo la ve el ladrón y cualquier guardia que tenga la salida o la caída en su zona visible (`vision.md` R1): verla volar delata el señuelo y de qué lado viene. Quien solo ve la caída ve el arco desde donde entra en su vista, no desde dónde se lanzó.
  - Los guardias la oyen como cualquier ruido. Nadie distingue una moneda de un paso.
- **Guardias: walkie.**
  - Manteniendo su tecla apunta con el ratón; al soltarla marca ese punto en el plano de todo el equipo durante `ping_time` s (2026-10-30, #112: antes salía al pulsar).
  - El chasquido suena con radio `walkie_radius` alrededor de quien habla.
  - Espera `walkie_cooldown` s entre usos.

### R9. Protecciones de las piezas (reescrita con #119, aprobada por el usuario el 2026-11-04)
> Regla decidida por el usuario tras el playtest (#119): no se entendía tener que ir a por una copia al taller ni el cuadro eléctrico del ala. Los números y las decisiones de abajo los aprobó el 2026-11-04.

**Regla general: todo lo necesario para robar una pieza está en la propia pieza.** Ninguna protección pide ir a buscar algo a otro sitio del mapa. Interruptores, bombillas y monedas son ayudas opcionales, nunca requisito.

**Todo pasa en la pieza.** Cada candidata tiene **una sola protección**. Junto a la pieza, el ladrón tiene siempre dos opciones, y nada más:
- **E: robar en silencio.** Abre el minijuego de su protección. Si lo completa, la pieza va al maletín sin alarma.
- **Q: a lo bruto.** Instantáneo: suena la campana de alarma de esa sala (ruido de radio `brute_radius`) y la alerta pasa a «alarma» al momento (R7). **E nunca roba a lo bruto** (hasta ahora, E sin copia o sin corte robaba a lo bruto: eso confundía).

Reparto en `museum_v2` (FEAT-034, sin cambios): 7 de combinación (cinco vitrinas y dos cajas fuertes), 7 de presión (báscula) y 6 de sensor.

**Fuera del juego** (#119): las 2 mesas de copias del taller y del ala este, los 4 cuadros eléctricos de alarma de las alas y el panel de pilotos de la garita. Los interruptores de luz de cada sala, el cuadro de alumbrado de Mantenimiento (que solo duplica interruptores) y desenroscar bombillas **se quedan**: apagar la luz sigue siendo la herramienta de luz del ladrón, sala a sala (R9d).

| Protección | E: el minijuego | Qué deja | Contrajuego |
|---|---|---|---|
| **Combinación** (vitrina o caja fuerte) | «Abrir la vitrina [E]» o «Abrir la caja fuerte [E]»: **el dial de siempre** (3 números por los clics), sin cambios | La vitrina o la caja vacía: rastro normal (R6) | El rastro a la vista; los clics del dial y el ruido al fallar un número |
| **Presión: la báscula** | «Dar el cambiazo [E]»: **la balanza** (abajo). No pide nada más: el ladrón trae las copias consigo, y toda pieza de báscula de su encargo admite siempre el cambiazo | Una **falsificación** en el pedestal, con su fallo (color, tamaño o pose). El pedestal parece intacto: **no es rastro** hasta que la examinan | Comparar con la ficha del plano y **examinarla** (E, `inspect_time` s): «¡Es una falsificación!» (rastro descubierto, R6) o «Auténtica» |
| **Sensor** | «Puentear el sensor [E]»: **el piloto** (abajo) | El pedestal vacío con el puente a la vista: rastro normal (R6) que se anuncia como «sensor puenteado» | El rastro a la vista, como una vitrina vacía. Puentear y coger es una sola acción: no hay puente puesto sin pieza robada, ni nada que examinar |

#### R9a. Reglas comunes de los minijuegos
- **Duración**: 5-8 s cada uno si se hace bien (el dial, que ya existe, no se toca y dura lo que tarde el ladrón en oír los clics).
- **Quieto**: mientras dura, el ladrón no anda; las teclas que usa el minijuego no lo mueven (como en el dial).
- **Cancelar**: lo cancela alejarse más de `task_leash` m (un empujón), cualquier tecla de movimiento que el minijuego no use, Esc, un golpe de porra o la captura. Cancelar no hace ruido y no gasta nada: se vuelve a empezar de cero.
- **Fallar**: suena un ruido mecánico de radio `fail_noise_radius` (el mismo que fallar un número del dial) y se reintenta al momento. **Fallar nunca hace saltar la alarma**.
- **Trabajar se oye un poco** (pilar 2): cada minijuego hace un ruido suave de radio `work_noise_radius` mientras dura (el crujido de la balanza, el chasquido del puente), como los clics del dial. Al terminar, la pieza sale con el ruido suave de siempre (2,5 m).
- **Q en mitad de un minijuego**: lo abandona y roba a lo bruto (con alarma).
- **A la vista**: el ladrón trabajando se ve y se oye como siempre; el minijuego no lo esconde. Si lo ven a mitad, salta la alarma como siempre que lo ven (R7), pero puede terminarlo y la pieza sale en silencio.

#### R9b. La báscula: «Dar el cambiazo»
- **Las copias**: no son un objeto. No hay inventario, contador ni marca en la lista del encargo, y el HUD no dice nada de copias: en la pieza solo «Dar el cambiazo [E]» y «A lo bruto [Q]: salta la alarma».
- **El minijuego**: el ladrón **mantiene E** para deslizar la copia sobre la báscula mientras saca el original. Una barra de progreso se llena en `swap_time` s mientras E siga pulsada.
  - Una **aguja** de báscula se va hacia un lado o hacia el otro (cambia de sentido al azar cada `needle_flip_min`-`needle_flip_max` s) y cada vez más deprisa a medida que avanza el cambiazo (el peso pasa de una pieza a otra).
  - Con **← →** (o A D) el ladrón la empuja de vuelta, a `needle_correct_speed`.
  - Si la aguja **sale de la franja verde**, falla: ruido de fallo, la aguja vuelve al centro y el progreso a 0.
  - **Soltar E** pausa sin ruido: el progreso se queda, pero la aguja sigue yéndose, así que no sirve para descansar.
- **El fallo de la falsificación**: se sortea al completar el cambiazo, como hoy (color, tamaño o pose), y es lo que un guardia puede notar comparando con la ficha del plano.

```
d(p) = needle_drift_start + (needle_drift_end − needle_drift_start) × p
t_reacción = (needle_green_half − |a|) / d(p)
```
| Variable | Significado | Fuente |
|---|---|---|
| `p` | Progreso del cambiazo, de 0 a 1 | estado del minijuego |
| `a` | Posición de la aguja, de −1 a 1 (0 en el centro) | estado del minijuego |
| `d(p)` | Velocidad de la aguja cuando se va (unidades de esfera por segundo) | resultado |
| `t_reacción` | Segundos desde que la aguja cambia de sentido hasta que sale de la franja, si nadie la corrige | resultado |
| `needle_drift_start`, `needle_drift_end` | Velocidad de la aguja al empezar y al acabar | `steal_minigames.tres` (nuevo) |
| `needle_green_half` | Media anchura de la franja verde | `steal_minigames.tres` |

Rango: con los valores aprobados (0,15 → 0,40 por s; franja ±0,35), desde el centro hay 2,3 s para reaccionar al empezar y 0,9 s al final; el ladrón corrige a 0,9 por s, más del doble de lo que se va la aguja, así que siempre se puede salvar si se reacciona. Ejemplo: a mitad del cambiazo (`p` = 0,5, 3 s), `d` = 0,275 por s; con la aguja en +0,10 y yéndose hacia fuera, quedan (0,35 − 0,10) / 0,275 = 0,9 s antes de fallar.

#### R9c. El sensor: «Puentear el sensor»
- Junto a la pieza, un **piloto** del sensor se enciende y se apaga solo: encendido `pilot_on_min`-`pilot_on_max` s (al azar, para que no se pueda contar a ciegas) y apagado `pilot_off_time` s.
- El ladrón pulsa **E con el piloto apagado**: un acierto (y el chasquido del puente). Hacen falta **`bridge_hits` aciertos seguidos**.
- **Pulsar con el piloto encendido** es fallar: ruido de fallo y la cuenta vuelve a 0. Pulsar dos veces en el mismo apagado no cuenta (se ignora). Dejar pasar un apagado sin pulsar no cuenta ni falla.
- Al tercer acierto la pieza va al maletín sin alarma.

```
T ≈ bridge_hits × t_on + (bridge_hits − 1) × pilot_off_time + r
```
| Variable | Significado | Fuente |
|---|---|---|
| `T` | Segundos del minijuego sin fallos | resultado |
| `t_on` | Rato medio encendido, (`pilot_on_min` + `pilot_on_max`) / 2 | `steal_minigames.tres` |
| `pilot_off_time` | Ventana para pulsar | `steal_minigames.tres` |
| `bridge_hits` | Aciertos seguidos | `steal_minigames.tres` |
| `r` | Reacción del jugador al ver el piloto apagarse (~0,25-0,45 s) | jugador |

Rango: con los valores aprobados (1,2-1,8 s encendido, 0,5 s apagado, 3 aciertos), `T` va de 4,9 a 6,9 s; cada fallo añade unos 2 s. Ejemplo: t_on medio 1,5 s y r = 0,3 s: 3 × 1,5 + 2 × 0,5 + 0,3 = 5,8 s.

#### R9d. Luz, sin cuadros eléctricos
- Desaparece «cortar la corriente de un ala»: ya no apaga las luces de un ala de golpe ni enciende un piloto en la garita. El ladrón apaga la luz sala a sala con los interruptores (y el cuadro de alumbrado de Mantenimiento) o desenroscando bombillas, como hasta ahora.
- Las luces de alarma (R7) se encienden en cualquier sala: ya no hay alas sin corriente que no respondan.
- Un corte ya no es un rastro (antes contaba al verlo en el panel o al llegar al ala a oscuras). Lo que cuenta para la alerta (R7) son solo los rastros de las piezas.

- **Una falsificación sin descubrir no es rastro**: el pedestal parece intacto. Es la jugada elegante del caballero, y la única que no deja rastro a la vista; por eso es la que pide el minijuego más fino.
- Un guardia que examina una pieza auténtica pierde el tiempo. No compensa revisarlo todo a ciegas.

#### R9e. A lo bruto (Q) en cada protección
| Pieza | Q |
|---|---|
| Vitrina (combinación) | Rompe el cristal y coge la pieza: campana y alarma |
| Caja fuerte (combinación) | No se puede: no se rompe a lo bruto, y la segunda línea dice «La caja fuerte no se puede forzar» |
| Báscula | Coge la pieza sin dejar nada: campana y alarma |
| Sensor | Coge la pieza: campana y alarma |
| Pieza que no está en el encargo | Ni E ni Q (como hoy) |

**Textos** (`estilo-de-textos.md`): en la pieza, la línea de E («Abrir la vitrina [E]», «Abrir la caja fuerte [E]», «Dar el cambiazo [E]», «Puentear el sensor [E]») y debajo «A lo bruto [Q]: salta la alarma» (en la caja fuerte, «La caja fuerte no se puede forzar»).

### R10. Ventilación (FEAT-034)
- Tres redes de rejillas (servicio, oeste y este), de 3 o 4 rejillas cada una. Ninguna en la Cámara de la Pieza Maestra ni en la Garita.
- **Solo el ladrón** se cuela: E en una rejilla, `enter_time` s, con un ruido metálico de radio `hatch_radius`.
- Dentro **elige la salida** entre las rejillas de su red con izquierda y derecha, y va con E. Elegir la de entrada es volver a salir por ahí. Tiene `max_inside` s para elegir; después sale solo por donde entró (decisión del usuario, 2026-10-29).
- **Viaje**: la distancia en línea recta entre las dos rejillas a `travel_speed`, un `loot_slow` más lento por pieza. Mientras viaja, nadie lo ve (guardias ni cámaras) ni lo puede golpear, y las rejillas de la red retumban (`rumble_radius`).
- Al salir suena igual que al entrar. Las dos rejillas quedan **abiertas** `open_time` s: un rastro que cualquier guardia cierra con E.

### R11. La puerta de la garita (FEAT-034)
- La garita tiene **una sola puerta**, cerrada al empezar. Cerrada tapa el paso y la vista: quien mira los monitores no ve el pasillo.
- Los guardias la abren o cierran con E al momento, y la IA al acercarse. El ladrón **fuerza la cerradura** en `pick_time` s, en silencio.
- Al abrirse **cruje** (`creak_radius`) y se cierra sola a los `auto_close` s, si el hueco está libre.

## Números
Viven en `data/balance/heist_rules.tres` (`HeistRules`) salvo donde se indica otro recurso; los del sueño, en `guard_sleep.tres` (`GuardSleepRules`). Son valores iniciales para afinar jugando. Los marcados **aprobado 2026-11-04** (#116) los aprobó el usuario y ya están en sus `.tres`. Con #116 se borran de `guard_sleep.tres` `window`, `radius` y `linger_ratio`, y `data/balance/time_clock_rules.tres` entero.

| Mando | Campo | Tipo | Rango | Inicial |
|---|---|---|---|---|
| Candidatas | nivel (`targets`) | ritmo | 5-8 | 6 |
| Piezas del encargo según guardias | `pieces_by_guards` | ritmo | — | [4, 3, 2] |
| Subida del sueño fuera de la garita | `rise_rate` (`guard_sleep.tres`) | ritmo | 1/300-1/180 por s | **1/240 (0,004167)** (#116; antes 1/90 solo acampando). Bostezo a 180 s fuera y cabezada a 240 s, lo que pidió el usuario: unos 3 minutos de patrulla tranquila y uno de aviso audible antes de quedarse ciego a ratos |
| Umbrales | `drowsy_at` / `exhausted_at` (`guard_sleep.tres`) | ritmo | 0,6-0,85 / 1,0 | **0,75** / 1,0 (antes 0,5 / 1,0). Con un solo `rise_rate`, el cociente 0,75 da los 3 y 4 minutos |
| Puesto de los guardias | sala con `"guard_post": true` (nivel, nuevo) | — | una sala | GAR en `museum_v2` |
| Bostezo | `yawn_interval` / `yawn_radius` (`guard_sleep.tres`) | sensación | 6-15 s / 5-10 m | 8 / 7 (sin cambios): en el minuto de aviso son ~7 bostezos; el ladrón los oye a 10,5 m |
| Vista somnolienta | `drowsy_sight` (`guard_sleep.tres`) | ritmo | 0,6-0,9 | 0,8 (sin cambios) |
| Cabezadas | `nod_interval` / `nod_time` (`guard_sleep.tres`) | ritmo | 8-15 s / 1,5-4 s | 10 / **2,5 s** (antes 1,5). Ciego el 25 % del tiempo: saltarse el café tiene que costar, porque ya no es un castigo por acampar sino una elección; 2,5 s andando son 12 m de ladrón |
| Café | `coffee_time` / `coffee_radius` / `fresh_time` (`guard_sleep.tres`) | ritmo | 2-5 s / 6-10 m / 30-120 s | 3 s / 8 m / **60 s** (antes 120). Basta para volver andando al ala más lejana (~60 m, 15 s) y mirar una sala; da 2-3 cafés por guardia en 12 minutos |
| Somnífero | `drug_doses` / `drug_time` / `drug_nap_time` (`guard_sleep.tres`) | ritmo | 1-2 / 2-5 s / 5-12 s | 1 / 3 s / 8 s |
| Bajón tras las luces de alarma | `crash_level` (`guard_sleep.tres`) | ritmo | `drowsy_at`-0,95 | **0,85** (antes 0,6, que con el umbral nuevo no haría nada) |
| IA: cuándo va a por café | `ai_coffee_at` (`guard_sleep.tres`, nuevo) | ritmo | 0,6-1,0 | **0,75** (= `drowsy_at`): va al primer bostezo y se la oye de camino |
| IA: peso de cada pieza | `ai_piece_weight` (`guard_patrol.tres`, nuevo `GuardPatrolRules`) | ritmo | 0,5-3 | **1,5**: ~11 % a la sala con más piezas, ~8 % a alguna vacía |
| IA: salas que no repite | `ai_room_memory` (`guard_patrol.tres`) | ritmo | 1-5 | **3**: no vuelve enseguida, pero en 12 minutos pasa varias veces por las salas con piezas |
| IA: rato en cada sala | `ai_room_dwell` (`guard_patrol.tres`) | sensación | 2-8 s | **4 s**: una pasada de linterna a la sala |
| Peso del botín | `loot_slow` / `loot_min_speed` (`heist_rules.tres`) | ritmo | 0,03-0,1 / 0,6-0,85 | 0,05 por pieza / 0,7 |
| Ventilación | `enter_time` / `hatch_radius` / `travel_speed` / `open_time` / `rumble_radius` (`vent_rules.tres`) | ritmo | — | 1,5 s / 4 m / 2 m/s / 20 s / 5 m; `max_inside` 20 s |
| Puerta de la garita | `pick_time` / `creak_radius` / `auto_close` (`door_rules.tres`) | ritmo | — | 2 s / 6 m / 6 s |
| Duración de la partida | `match_minutes` (nivel) | ritmo | 10-15 | 12 en el museo ampliado |
| Monedas | `coins` / `throw_range` / `coin_radius` | ritmo | 2-5 / 6-14 m / 6-12 m | 3 / 10 / 9 |
| Vuelo y brillo de la moneda | `coin_flight_time` / `coin_glint_time` | sensación | 0,3-0,8 s / 1-5 s | 0,5 / 3 |
| Walkie | `ping_time` / `walkie_radius` / `walkie_cooldown` | ritmo | — | 8 s / 6 m / 10 s |
| Robo a lo bruto | `brute_radius` | sensación | 12-20 m | 15 |
| Examinar una pieza | `inspect_time` | ritmo | 1-3 s | 2 (sin cambios) |
| Distancia que cancela un minijuego | `task_leash` (`heist_rules.tres`) | sensación | 1-2 m | 1,5 (sin cambios): como el ladrón no anda durante el minijuego, solo lo cancela un empujón o el golpe |

**Huida con la alarma (#120, aprobado por el usuario el 2026-11-04).** Los de la cuenta atrás y las rejas, en `heist_rules.tres`; los puntos, en `score_rules.tres`. Ya están escritos en sus `.tres` con estos valores; la FEAT añade los campos a `HeistRules` y `ScoreRules` (hasta entonces Godot los ignora).

| Mando | Campo | Tipo | Rango | Propuesto |
|---|---|---|---|---|
| Cuenta atrás de las rejas | `lockdown_time` (`heist_rules.tres`) | ritmo | 20-45 s | **30 s** (lo pidió el usuario). Unos 7 s bastan para llegar corriendo a la salida más cercana desde cualquier pieza; los otros ~20 s son la decisión: una pieza más o salir. Por debajo de 20 no da para robar nada más; por encima de 45 los guardias tienen tiempo de cubrir las 4 salidas |
| Bajada de las rejas | `gate_drop_time` (`heist_rules.tres`) | sensación | 1-3 s | **1,5 s**: se ven bajar y da para pasar por debajo en el último instante, pero no para cruzar media sala |
| Aviso final | `lockdown_warn_at` (`heist_rules.tres`) | sensación | 5-10 s | **10 s**: el número late en rojo y el timbre se acelera; a 6,4 m/s son ~60 m, la salida más lejana desde casi cualquier sala |
| Chirrido de las rejas | `gate_radius` (`heist_rules.tres`) | sensación | 8-15 m | **10 m**: quien está cerca de una salida la oye bajar aunque no la vea |
| Huida completa | `thief_escape` (`score_rules.tres`) | curva | — | **150** (sin cambios; con #120 solo la huida completa, con o sin alarma) |
| Huida a medias | `thief_partial_escape` (`score_rules.tres`, nuevo) | curva | 0-100 | **50** (lo pidió el usuario; con #123 pasa a `thief_partial_escape_by_guards`, ver «Puntos (#123)»): un tercio de la huida completa; con las piezas, una huida a medias con 1 pieza vale 150 y con 2, 250, frente a 450 de un encargo de 3 completo |
| Proteger | `guard_protect` (`score_rules.tres`, nuevo, de #123) | curva | 40-80 | **60** (lo pidió el usuario en #123; con #123 pasa a la bolsa `team_protect_pool`): cada pieza que se queda vale algo más de la mitad de lo que gana el ladrón al llevársela, y pone el equilibrio de la huida a medias en torno a 1 pieza con 2 guardias (R4b) |
| Encerrado | `guard_lockdown` (`score_rules.tres`, nuevo, de #123) | curva | 50-150 | **100** (lo pidió el usuario en #123; con #123 pasa a la bolsa `team_lockdown_pool`): a cada guardia, como premio de equipo por cerrarle las salidas; menos que la captura (+150, a uno solo) |

**Minijuegos de robo (#119, aprobado por el usuario el 2026-11-04).** Viven en un recurso nuevo, `data/balance/steal_minigames.tres` (`StealMinigameRules`), para que `heist_rules.tres` no crezca más y quede junto a `safe_dial.tres`. Con #119 se borran de `heist_rules.tres` `swap_time` (pasa al recurso nuevo con otro valor), `cut_time`, `restore_time` y `pilot_sight`.

| Mando | Campo | Tipo | Rango | Aprobado |
|---|---|---|---|---|
| Duración del cambiazo | `swap_time` | ritmo | 5-8 s | **6 s** (antes 2 s sin minijuego). En medio de la franja que pidió el usuario: lo bastante para sentir que la balanza se tuerce, poco para que un guardia que pasa a 10 m llegue a verlo empezar y acabar |
| Franja verde | `needle_green_half` | curva | 0,25-0,5 | **0,35** (franja de −0,35 a +0,35 en una esfera de −1 a 1, un tercio largo de la esfera): se ve de un vistazo en la isométrica |
| Aguja al empezar / al acabar | `needle_drift_start` / `needle_drift_end` | curva | 0,1-0,25 / 0,3-0,6 por s | **0,15 / 0,40**: 2,3 s de margen al principio y 0,9 s al final; la tensión sube hacia el final del cambiazo |
| Cambios de sentido | `needle_flip_min` / `needle_flip_max` | sensación | 0,5-1,5 / 1,5-3 s | **0,8 / 2,0 s**: unos 4-5 cambios por cambiazo |
| Corrección del ladrón | `needle_correct_speed` | sensación | 0,7-1,2 por s | **0,9**: más del doble de la aguja más rápida, para que fallar sea despiste y no imposibilidad |
| Piloto encendido | `pilot_on_min` / `pilot_on_max` | ritmo | 0,8-2 s | **1,2 / 1,8 s**: al azar, para que haya que mirarlo y no contar |
| Ventana para pulsar | `pilot_off_time` | sensación | 0,35-0,7 s | **0,5 s**: el doble de una reacción normal, justo pero limpio |
| Aciertos seguidos | `bridge_hits` | ritmo | 2-4 | **3** (lo pidió el usuario): 4,9-6,9 s sin fallos |
| Ruido al fallar | `fail_noise_radius` | sensación | 5-10 m | **7,5 m**, el de fallar un número del dial (hoy una constante en `safe_box_3d.gd`; la FEAT la pasa a este recurso y el dial la lee de aquí): se oye desde la sala de al lado, nunca alarma |
| Ruido de trabajar | `work_noise_radius` | sensación | 1,5-3 m | **2 m**, cada `work_noise_interval` **1 s** en la balanza y en cada acierto del puente: como los clics del dial (1,8 m), solo lo oye quien está encima |

**Sabotear la caja de la reja (#121, aprobado por el usuario el 2026-11-05).** Los de la caja, en `heist_rules.tres` (campos `box_*`); los puntos, en `score_rules.tres`. Ya están escritos en sus `.tres` con estos valores; la FEAT añade los campos a `HeistRules` y `ScoreRules` (hasta entonces Godot los ignora). Reutiliza de `steal_minigames.tres` `fail_noise_radius` (7,5 m, el chispazo) y `work_noise_radius` (2 m, tornillos, cortes y reparación), y de `heist_rules.tres` `task_leash`, `gate_drop_time` y `gate_radius`.

| Mando | Campo | Tipo | Rango | Propuesto |
|---|---|---|---|---|
| Tornillos de la tapa | `box_screws` | ritmo | 3-6 | **4**: se cuentan de un vistazo; cada uno es un ruido pequeño |
| Segundos por tornillo | `box_screw_time` | ritmo | 0,75-1,5 s | **1,25 s**: 5 s por tapa, 10 s entre quitarla y ponerla. Es el mando principal de la duración: ±0,25 s mueven el total ±2 s |
| Cables | `box_wires` | curva | 3-5 | **4**: con 3 se adivina a la primera demasiado a menudo (1 de 6 órdenes); con 5 el enredo ya no se lee en la isométrica |
| Empalme tras cortar mal | `box_splice_time` | ritmo | 1-3 s | **2 s**: lo que cuesta un fallo de la balanza; junto al chispazo de 7,5 m, adivinar sale caro |
| Distancia a la que se nota | `box_notice_distance` | sensación | 2-4 m | **3 m**: hay que pasar junto a ella, pero el guardia que cubre una salida (a 1,5 m de la puerta) la ve; más lejos sería un aviso gratis desde la puerta de la sala |
| Chispa, cada | `box_spark_min` / `box_spark_max` | ritmo | 3-12 s | **5 / 9 s**: un guardia que cruza la sala andando (~10 s) ve u oye al menos una casi siempre; uno que solo asoma, no |
| Chisporroteo | `box_spark_radius` | sensación | 2-4 m | **3 m**: lo mismo que se nota la tapa; se oye al pasar, no desde la sala de al lado |
| Reparar | `box_repair_time` | ritmo | 5-10 s | **8 s** (lo pidió el usuario): la mitad que sabotear; un guardia que repara en la cuenta atrás se queda 8 s quieto en su salida |
| Caja saboteada al acabar | `thief_sabotage` (`score_rules.tres`) | curva | 0-50 | **30** (lo pidió el usuario): menos de un tercio de una pieza; sin alarma solo cuenta para «MEJOR DE LA NOCHE» |
| Huida por una reja saboteada | `thief_sabotage_escape` (`score_rules.tres`) | curva | 30-100 | **60** (lo pidió el usuario): con los +30, casi lo que vale una pieza en la huida a medias |
| Reparar una caja | `guard_repair` (`score_rules.tres`) | curva | 20-60 | **40** (lo pidió el usuario): más que los +30 que pierde el ladrón, a un solo guardia |

**Puntos (#123, aprobado por el usuario el 2026-11-05).** Todos en `score_rules.tres` (`ScoreRules`). La FEAT añade los campos nuevos, cambia `thief_piece`, `thief_partial_escape`, `guard_protect` y `guard_lockdown` por los de la tabla y escribe los valores en el `.tres`. Los de valor fijado por el usuario en la entrevista van con «(usuario)»; los demás los propone `game-designer` con la tabla de escenarios de abajo.

| Mando | Campo | Tipo | Rango | Propuesto |
|---|---|---|---|---|
| Bolsa de las piezas del ladrón | `thief_piece_pool` | curva | — | **300** (usuario): 300 × s / k. Un encargo entero vale lo mismo con cualquier número de guardias |
| Bolsa de «proteger» | `team_protect_pool` | curva | — | **300** (usuario): la misma que la del ladrón, para que en s = k/2 las piezas se anulen |
| Huida a medias | `thief_partial_escape_by_guards` | curva | 25-100 | **[75, 60, 54, 50]** con 1, 2, 3 y 4 guardias (antes +50 fijo). Sale de `−thief_alarm − thief_seen + guard_alarm / √G` redondeado: compensa la alarma de una huida limpia en los dos lados y deja el empate en s = k/2 (R4b). Si cambia `thief_alarm`, `thief_seen` o `guard_alarm`, se recalcula |
| Alarma (ladrón) | `thief_alarm` | curva | −10 a −30 | **−15** (antes −25). Cada vez que lo vuelven a ver tras perderlo es otra alarma; con −25, verlo y perderlo (−25 − 10 + 25 de despistar) le costaba 10 y una persecución movía el empate más de una pieza (de s = 2 a 3,5 con 1 guardia). Con −15, verlo y despistarlos le sale a 0 y lo que gana el equipo es el +25 del guardia |
| Visto (ladrón) | `thief_seen` | curva | −5 a −15 | **−10** (sin cambios) |
| Despistar | `thief_lose_them` / `lose_them_time` | curva / ritmo | 15-40 / 5-12 s | **25** (usuario) / **8 s** (usuario): lo mismo que gana el guardia al verlo; 8 s son ~60 m de carrera, salir de una sala y doblar una esquina |
| Robo limpio | `thief_clean_piece` | curva | 10-40 | **20** (usuario): un cuarto de la pieza más barata; premia el cambiazo sin descubrir y a la vez da a los guardias un motivo para mirar pedestales |
| Huida rápida | `thief_fast_escape` | curva | 1-3 por s | **2 por s** (usuario): de 0 a 60. Nunca vale una pieza (la más barata, 75), así que no compensa salir antes que robar otra si da tiempo; desempata cuando no la hay. Si «a lo bruto y correr» gana demasiado, es el primer mando a bajar (a 1) |
| Golpe recibido | `thief_hit_taken` | curva | −10 a −30 | **−20** (usuario) |
| Alarma (guardia) | `guard_alarm` | curva | 30-75 | **50** (usuario): el doble de verlo; con √G, entre 50 y 29 en la puntuación de equipo |
| Verlo | `guard_seen` | curva | 15-40 | **25** (usuario; sin cambios, ahora sin contar la vez que da la alarma) |
| Descubrir un engaño | `guard_examine_fake` | curva | 20-60 | **40** (usuario): con los +20 de robo limpio que le quita al ladrón, mueve unos 50 |
| Walkie que acierta | `guard_walkie` / `walkie_hit_window` / `walkie_hit_radius` | curva / ritmo / sensación | 15-50 / 6-15 s / 4-8 m | **30** / **10 s** / **6 m** (usuario): la ventana es la de la marca (`ping_time` 8 s) más el giro de cabeza; 6 m es el radio del chasquido |
| Robo cerca | `guard_near_theft` / `near_theft_radius` | curva / sensación | −15 a −50 / 3-8 m | **−30** / **5 m** (usuario): a 5 m lo vería si mirase (el trabajo del minijuego solo se oye a 2 m); es el precio de no mirar |
| Golpe, captura, cabezada, reparar | `guard_hit` / `guard_capture` / `guard_nap` / `guard_repair` | curva | — | **50 / 150 / −15 / 40** (sin cambios) |
| Bolsa de «encerrado» | `team_lockdown_pool` | curva | 100-300 | **150** (antes +100 a cada guardia): lo que vale la captura, que también acaba la partida; atraparlo entre todos vale lo que atraparlo uno. Con 2 guardias, 75 cada uno. No toca la huida a medias |

## Puntos (#123): tabla de escenarios
Comprueba los números de arriba (aprobados el 2026-11-05). En cada celda, **ladrón – equipo** y quién gana (L, G o =). `s*` es dónde se cruzan (las piezas a partir de las que gana el ladrón, en continuo); el objetivo es s* = k/2 en la huida limpia y que el juego de cada bando lo mueva menos de una pieza y media hacia cada lado.

**Los escenarios** (con G guardias; «otra alarma» es que lo vuelvan a ver tras perderlo más de 3 s: −15 y −10 al ladrón, +25 al guardia):

| Escenario | Guardias (personales) | Ladrón (aparte de piezas y huida a medias) |
|---|---|---|
| **Tranquila** (huida limpia) | Uno lo ve una vez: alarma, +50 | −15 (alarma), −10 (visto) |
| **Media** | Alarma (+50); lo vuelven a ver una vez (+25); un golpe (+50); repara una caja (+40); un walkie que acierta (+30, con 2 o más); una cabezada (−15). Suma 180 (150 con 1 guardia) | 2 alarmas (−30), 2 vistas (−20), un golpe (−20), un despiste (+25), sale con 10 s (+20): −25 |
| **Persecución** | Alarma (+50); lo vuelven a ver 2 + G veces (+25 cada una); un golpe (+50; el segundo sería la captura); un walkie (+30, con 2 o más). Suma 175, 230 y 255 | 4 alarmas (−60), 3 + G vistas, un golpe (−20), 2 despistes (+50), sale con 5 s (+10) |
| **Ladrón fino** | Alarma (+50), una cabezada (−15), uno estaba a < 5 m de un robo (−30). Suma 5 | Alarma y visto (−25), todas sus piezas sin descubrir (+20 cada una), un despiste (+25), sale con 15 s (+30) |
| **A lo bruto y correr** | Nada: nadie lo ve | Q a una pieza junto a una salida y fuera con 25 s (+50); alarma (−15); las otras piezas, descubiertas |

**Resultados** (ladrón – equipo):

| G (k) | Escenario | s = 1 | s = 2 | s = 3 | s* (k/2) |
|---|---|---|---|---|---|
| 1 (4) | Tranquila | 125 – 275 G | **200 – 200 =** | 275 – 125 L | **2,00** (2) |
| 1 (4) | Media | 125 – 375 G | 200 – 300 G | 275 – 225 L | 2,67 |
| 1 (4) | Persecución | 90 – 400 G | 165 – 325 G | 240 – 250 G | 3,07 |
| 1 (4) | Ladrón fino | 200 – 230 G | 295 – 155 L | 390 – 80 L | 1,18 |
| 1 (4) | A lo bruto y correr | 185 – 225 G | 260 – 150 L | 335 – 75 L | 1,27 |
| 2 (3) | Tranquila | 135 – 235 G | 235 – 135 L | — | **1,50** (1,5) |
| 2 (3) | Media | 135 – 327 G | 235 – 227 L | — | 1,96 |
| 2 (3) | Persecución | 90 – 363 G | 190 – 263 G | — | 2,36 |
| 2 (3) | Ladrón fino | 210 – 204 L | 330 – 104 L | — | 0,97 |
| 2 (3) | A lo bruto y correr | 195 – 200 G | 295 – 100 L | — | 1,02 |
| 3 (2) | Tranquila | **179 – 179 =** | — | — | **1,00** (1) |
| 3 (2) | Media | 179 – 254 G | — | — | 1,25 |
| 3 (2) | Persecución | 124 – 297 G | — | — | 1,58 |
| 3 (2) | Ladrón fino | 254 – 153 L | — | — | 0,68 |
| 3 (2) | A lo bruto y correr | 239 – 150 L | — | — | 0,70 |

Con 4 guardias (k = 2, `E` = 50) sale casi igual que con 3: tranquila 175 – 175, media 175 – 240, persecución 110 – 290, fino 250 – 153, a lo bruto 235 – 150.

**Lo que dice la tabla:**
- **La huida limpia empata en s = k/2 con 1, 2, 3 y 4 guardias**, como pidió el usuario. Con los números del issue (`E` = 50 y alarma −25) caía en s = 2,23, 1,60 y 1,05: con 1 guardia, 2 piezas de 4 perdían (165 – 200).
- **Los guardias mueven el resultado hacia arriba**, entre un cuarto de pieza (media con 3) y una (persecución con 1), y **el ladrón hacia abajo**, entre un tercio y cuatro quintos (fino o a lo bruto). Con los números del issue, la persecución lo movía hasta pieza y media (s* = 3,50 con 1 guardia: con 3 piezas de 4 perdía por 75); con la alarma a −15, se queda en una (3,07: pierde por 10, casi empate).
- **Ninguna acción suelta decide fuera de la mitad.** Lo que mueve cada acción la diferencia ladrón − equipo, con 1 / 2 / 3 guardias:

  | Acción | Mueve |
  |---|---|
  | Verlo otra vez, tras perderlo (otra alarma) | 50 / 43 / 39 hacia los guardias |
  | Lo ve a la vez otro guardia (sin otra alarma) | — / 28 / 24 |
  | Golpe | 70 / 55 / 49 |
  | Descubrir una falsificación (y quitarle el robo limpio) | 60 / 48 / 43 |
  | Reparar una caja que seguiría saboteada (+40 y −30) | 70 / 58 / 53; si era su salida tras las rejas, 90 más |
  | Walkie que acierta | — / 21 / 17 |
  | Cabezada, robo cerca | 15 / 11 / 9 y 30 / 21 / 17 hacia el ladrón |
  | Despistar, robo limpio | 25 y 20 por pieza hacia el ladrón |
  | Huida rápida | de 0 a 60 hacia el ladrón |
  | Q en vez de que lo vean al dar la alarma | 40 / 25 / 19 hacia el ladrón (no le ven, pero pierde el robo limpio de esa pieza) |
  | Huida por una reja saboteada | 90 hacia el ladrón |

  La mayor es 90; media pieza de distancia a la mitad (solo existe con k = 3, s = 1 o 2) son 100, y una pieza entera con k = 4, 150. Con s = k/2 cualquier cosa desempata: es lo que se busca.
- **Los +2/s no dominan**: como mucho 60, menos que la pieza más barata (75); en los escenarios dan 10-30. Salir antes nunca compensa dejar una pieza que da tiempo a robar.
- **Lo que hay que vigilar**: «a lo bruto y correr» con 3 o 4 guardias (s = 1 es la mitad): gana por ~89 si nadie lo ve antes de salir. Le hacen falta 2-3 vistas o un golpe a los guardias para darle la vuelta. Va a «Qué medir».

## Contrajuego
| Acción | Quién | Qué percibe el otro | Cómo responde |
|---|---|---|---|
| Plantarse junto a una candidata o una salida | Guardia | Su linterna; a los 3 minutos fuera, bostezos; después, el «Zzz» de las cabezadas | Robar las otras piezas, esperar a que vaya a por café o cruzar durante una cabezada |
| Ir a por café | Guardia | Los bostezos de camino, el crujido de la puerta de la garita y el ruido de la cafetera | Aprovechar el hueco: el ala que deja tarda ~15 s en volver a estar vigilada |
| Quedarse en la garita (#116: no da sueño) | Guardia | Si mira, el piloto rojo de la cámara que tiene en pantalla, una sala cada vez (#118); ninguna linterna fuera | Robar donde no está el piloto, o apagar la luz de la sala que miran, y robar en silencio: desde la garita solo se descubren rastros por la cámara en pantalla |
| Saltarse el café | Guardia | Bostezos y el «Zzz» | Cruzar durante la cabezada (2,5 s ciego cada 10 s) |
| Correr con la alarma (#116) | Guardia | Pasos fuertes (×2 de radio) | Esconderse y dejar que pase; romper la línea de visión |
| Drogar la cafetera | Ladrón | Nada, hasta que alguien cae dormido | Vigilar la garita de paso; no servirse café a ciegas tras un rato sin ver la cafetera |
| Encender las luces de alarma | Guardia | Todo iluminado 30 s, y después bostezos | Esperar a que pase y aprovechar el bajón |
| Robar una pieza | Ladrón | El pedestal vacío, si lo ven | Descartar candidatas y cerrar el cerco |
| Lanzar una moneda | Ladrón | Un ruido como cualquier otro | Mandar a uno solo a mirar, con el walkie |
| Usar el walkie | Guardia | El chasquido | Saber dónde está ese guardia |
| Salir | Ladrón | Nada antes de cruzar | Patrullar cerca de las salidas al final, sin poder cubrir las 4 |
| Huir con la alarma (#120) | Ladrón | La cuenta atrás y el timbre (los dos bandos); la campana del plano dice dónde saltó | Correr a las salidas más cercanas a la campana y cerrar el paso; cada guardia cubre una salida |
| Plantarse en una salida durante la cuenta atrás (#120) | Guardia | Su linterna y sus pasos de carrera (×2 de radio) | Ir a otra de las 4 salidas, o esconderse y esperar a que se mueva, sabiendo que el tiempo corre en su contra |
| Una pieza más con la alarma (#120) | Ladrón | La campana o el pedestal vacío, si se ve; el reloj sigue | Dejar una salida sin cubrir para ir a por él: si sale, es huida a medias |
| Dar el cambiazo (#119) | Ladrón | 6 s de crujidos suaves junto a la pieza; después, una falsificación con un fallo | Fijarse en ella, compararla con la ficha y examinarla |
| Puentear el sensor (#119) | Ladrón | Chasquidos suaves junto a la pieza; después, el pedestal vacío («sensor puenteado») | El rastro a la vista, como una vitrina vacía |
| Fallar un minijuego (#119) | Ladrón | Un ruido mecánico de 7,5 m, como fallar el dial | Acercarse a la sala de donde viene: el ladrón está quieto en una pieza |
| Robar a lo bruto | Ladrón | La campana y la alarma al momento | Ir todos hacia allí y cerrar las salidas de esa zona |
| Sabotear una caja (#121) | Ladrón | Tornillos y cortes de 2 m; el chispazo de 7,5 m si corta mal; después, la tapa torcida a 3 m y una chispa cada 5-9 s (vista desde lejos, oída a 3 m, también por la cámara en pantalla) | Pasar junto a las cajas al patrullar las salas de salida y repararlas (8 s, +40) |
| Dejar una caja a medias (#121) | Ladrón | La tapa fuera, a 3 m; sin chispas | Repararla igual (8 s, +40): el ladrón pierde lo hecho |
| Reparar una caja (#121) | Guardia | Ruido de trabajo de 2 m cada segundo; con la alarma, la reja que no baja o la que baja tarde | Volver a sabotearla cuando se vaya (sin alarma) o ir a otra salida abierta |
| La reja que no baja (#121) | Ladrón | El zumbido y el chasquido de su salida (10 m), «REJAS CERRADAS · N SALIDAS ABIERTAS» y la salida marcada en el plano | Correr a esa salida y repararla; si era la última, «ENCERRADO» |

## Casos límite
- **El ladrón roba la última pieza junto a una salida**: gana al cruzarla. Es lo que se busca: elegir bien el orden es parte del juego.
- **Golpe y escape a la vez**: si el ladrón cruza la salida en el mismo tick en que lo golpean, manda la captura.
- **Cambia el número de guardias a mitad de partida** (desconexión): el encargo ya sorteado no cambia.
- **La caja fuerte es candidata pero no está en el encargo**: no se puede abrir, como las demás piezas que no tocan. Su dial ni siquiera se activa.
- **Revancha**: nuevo sorteo.
- **Sin red** (2026-10-30, #116): los 2 guardias de IA patrullan salas (R5c), duermen y van a por café como un humano; no usan el walkie (más adelante).
- **El guardia en el umbral de la garita**: está fuera (el sueño sube). La garita es el rectángulo de la sala.
- **Cabezada mirando los monitores**: no puede pasar, porque en la garita el sueño se congela; si entra ya agotado, sigue dando cabezadas (no ve las cámaras en ellas) hasta que se toma el café.
- **Alarma con un guardia agotado**: la adrenalina lo despeja (R5b) y desde entonces el sueño no sube.
- **Se acaba el tiempo con el ladrón cruzando una salida**: aprobado: si cruza en el último tick, gana él (el escape se evalúa antes que el tiempo; la captura sigue mandando sobre el escape).
- **Huida con la alarma (#120)**:
  - **La alarma salta con el encargo ya completo**: tiene la misma cuenta atrás; si sale antes de las rejas es huida completa («ESCAPADO», +150); si no, «ENCERRADO».
  - **Completa el encargo durante la cuenta atrás**: al salir es huida completa.
  - **La alarma lo pilla en el callejón**: con botín, huye en el acto (a medias o completa); sin nada, tiene la cuenta atrás para entrar a por una pieza.
  - **Lo capturan durante la cuenta atrás**: «CAPTURADO», como siempre. La captura manda sobre la huida y sobre las rejas en el mismo instante.
  - **En un conducto al bajar las rejas**: «ENCERRADO». Como el viaje y la espera dentro (`max_inside`, 20 s) caben en la cuenta atrás, meterse con poco margen es una apuesta del ladrón.
  - **A mitad de minijuego al bajar las rejas**: no termina (como al acabarse la partida) y es «ENCERRADO».
  - **Pasa bajo la reja mientras baja**: huye; la reja solo cierra al tocar el suelo.
  - **Alarma con menos de `lockdown_time` s de partida**: manda el reloj de la partida; la cuenta atrás grande enseña lo que llegue antes y el final es «AMANECE».
  - **Huida a medias con los guardias en negativo** (cabezadas): la media puede ser negativa; se compara igual (con #123, la puntuación de equipo).
  - **Un guardia se desconecta**: su ficha no está en el informe y no cuenta en la media (`G` son los que siguen; con #123, ver «Puntos (#123)» abajo).
- **Sabotear la caja (#121)**:
  - **Sabotea antes de la alarma y la alarma nunca salta**: la reja no hace nada; la caja vale +30 si sigue saboteada al acabar (solo para «MEJOR DE LA NOCHE»: sin alarma, los puntos no deciden nada).
  - **Sabotea durante la cuenta atrás**: vale si termina antes de que las rejas empiecen a bajar. Si no le da tiempo, el minijuego se corta y la caja se queda a medias.
  - **Con la reja bajando o en el suelo**: no se puede sabotear («La reja ya ha bajado»); sabotear nunca vuelve a subir una reja.
  - **Reparar durante la cuenta atrás**: la caja queda entera y su reja baja con las demás. Si la reparación acaba durante la bajada, esa reja baja entonces, en `gate_drop_time` s.
  - **Reparar con las rejas cerradas**: esa reja baja en `gate_drop_time` s, con chirrido; se puede pasar por debajo hasta que toca el suelo (R7b). Si era la última salida abierta, al tocar el suelo es «ENCERRADO» (o «SIN BOTÍN»).
  - **Amanece con una salida abierta**: «AMANECE», como siempre; sin los +100 de «encerrado».
  - **El ladrón, en el callejón sin piezas al cerrarse las rejas, con una salida abierta**: no es «SIN BOTÍN»; la partida sigue y puede entrar a por una pieza por la salida abierta.
  - **En un conducto al cerrarse las rejas, con una salida abierta**: la partida sigue.
  - **Un guardia llega mientras el ladrón sabotea**: lo ve (alarma, R7); no puede reparar una caja en la que está trabajando el ladrón. Si el ladrón se va, la repara con lo que haya hecho.
  - **Dos guardias en la misma caja**: la repara el primero; el segundo no ve el aviso mientras tanto.
  - **Huida a medias por una salida saboteada durante la cuenta atrás** (con todas las rejas aún arriba): es una huida a medias normal; los +60 solo cuentan con las rejas cerradas (decisión 1 de #121). La caja sigue valiendo +30.
  - **Revancha**: las cajas vuelven enteras, con cables nuevos.
- **Minijuegos (#119)**:
  - **Un guardia lo ve a mitad de minijuego**: salta la alarma como siempre que lo ven (R7); el minijuego sigue si el ladrón no se va, y la pieza sale en silencio si lo termina (ya no hay alarma que ahorrar, pero sí el rastro: la falsificación sigue sin ser rastro hasta que la examinen).
  - **Se acaba la partida a mitad**: no termina nada (como `TimedTask` hoy).
  - **Dos piezas a menos de `reach_distance`**: la E va a la que señala el cursor (`interaction.md`, selección de interactivos); el minijuego es de esa.
  - **Con red**: el servidor lleva el estado del minijuego (aguja, progreso, piloto, aciertos) y decide fallos y aciertos; el cliente del ladrón manda las teclas, como con el dial. El sorteo de la aguja y del piloto lo hace el servidor.
- **Puntos (#123, aprobado por el usuario el 2026-11-05)**:
  - **Empate en la huida a medias**: «EMPATE», como en #120 («Huida a medias: empate a 179»). Con la huida limpia en s = k/2 es exacto (1 guardia con 2 piezas de 4; 3 o 4 guardias con 1 de 2); cualquier otra acción lo rompe.
  - **Empate en «MEJOR DE LA NOCHE»**: el ladrón, o el guardia de número más bajo (sin cambios).
  - **Un guardia se desconecta**: su ficha no sale y sus personales no cuentan (como en #120). *Pendiente*: hoy su personaje se queda en la escena y sigue contando (issue #158). `G` son los que siguen al acabar: las bolsas se reparten entre ellos y `E(G)` y √G usan ese mismo G. El encargo (k) no cambia, y como en s = k/2 las piezas se anulan para cualquier k, la huida limpia sigue empatando (3 guardias y k = 2; se va uno: ladrón 150 + 60 − 25 = 185, equipo 150 + 50 / √2 = 185). Si se fue justo el que dio la alarma, sus +50 se pierden con su ficha y el ladrón sale ganando: es raro y no se corrige.
  - **Sin ningún guardia con ficha** (no debería pasar: la partida se cierra antes): `P_equipo` = la bolsa de «proteger» y `E` la de 1 guardia.
  - **Guardias de IA**: puntúan igual que un humano, con la misma ficha. No usan el walkie (R5c), así que nunca cobran sus +30; el −30 por un robo cerca y las cabezadas, sí. Sin red, 2 guardias de IA: G = 2.
  - **La alarma la ven dos guardias a la vez**: los +50 son del primero que procesa el servidor (en el mismo instante, el de número más bajo); el otro cobra +25 por verlo. El ladrón, −10 por cada uno y −15 una vez.
  - **Alarma a lo bruto**: nadie cobra los +50; el primero que lo ve después cobra +25.
  - **Alarma por dos rastros** (decisión 6): los +50, a quien descubre el segundo, en persona o con la cámara en pantalla.
  - **La alarma lo pilla fuera con botín**: huye en el acto (R3) con toda la cuenta atrás: +60 de huida rápida. Para llegar ahí tiene que dejarse ver desde fuera o tener a alguien que descubra dos rastros; se mide («Qué medir»).
  - **Despistar en un conducto**: cuenta (nadie lo ve dentro, R10). Si huye o acaba la partida antes de los 8 s, no cuenta.
  - **Robo limpio en cualquier final**: cuenta para su ficha («MEJOR DE LA NOCHE»), también si lo capturan.
  - **Varios guardias cerca de un robo**: −30 a cada uno. Uno al otro lado de un muro, a menos de 5 m, no.
  - **Walkie**: si el que lo ve es el mismo que puso la marca, no cuenta; dos marcas a la vez pueden cobrar cada una. Con la cámara en pantalla de un compañero, también cuenta (decisión 7).
  - **Puntuación de equipo negativa** (muchas cabezadas y robos cerca): se compara igual.
  - **El aviso «−10 VISTO»** le dice al ladrón que lo están viendo. La primera vez ya lo dice la alarma; las siguientes es información que el ladrón no siempre tenía (pilar 3: él sabe más). Si en el playtest se nota como un chivato, el aviso de las restas del ladrón puede esperar a que deje de verlo.
  - **Revancha**: todo a 0.

## Red
- **Al ladrón**: su encargo, como estado privado (`#private`, igual que la caja fuerte), y el estado de su minijuego (#119).
- **A los guardias**: las candidatas, el número de piezas y los rastros descubiertos. Nunca el encargo.
- **A todos**: la alerta, los ruidos (bostezos, café, monedas, walkie) y si cada pedestal está ocupado o vacío. Estos últimos solo se dibujan si se ven, por la niebla y la memoria de `vision.md`.
- **Al propio guardia**: su sueño, como estado privado.
- **#121**: el servidor lleva el estado de cada caja (tornillos, cables cortados, saboteada), el orden de sus cables y la reparación, y decide aciertos y fallos; el cliente del ladrón manda las teclas, como en R9.
  - **Al ladrón**, como estado privado: el estado completo de la caja en la que trabaja, con el orden de sus cables (nunca a los guardias), y el de sus cajas para su plano.
  - **A todos**: si cada caja está entera, a medias o saboteada (para dibujar la tapa y la chispa; el cliente del guardia solo dibuja la tapa torcida a menos de `box_notice_distance` m, como el pedestal vacío, que solo se dibuja si se ve), las chispas como ruido y el estado de cada reja por separado (arriba, bajando, cerrada, o recogida porque su caja la frena).
- **#123**: el servidor lleva todos los puntos. A cada jugador, como estado privado (`get_net_state_private()`), solo su total en vivo y sus avisos («+25 VISTO»); nunca los de otro. Lo oculto (robo limpio, «proteger», robos cerca) solo llega con el informe, al acabar, y el resultado de la huida a medias se calcula del informe en cada cliente, como en #120.
- **A todos (#120)**: el instante en que empezó la cuenta atrás (cada cliente la dibuja con su reloj) y el estado de cada reja (arriba, bajando, cerrada). El servidor decide la huida, el tipo de huida y el cierre; el resultado de la huida a medias sale del informe, que ya tienen todos (MatchScore lo calcula igual en cada cliente).

## Cambios en el nivel (`museum_v2`)
- 6 candidatas en alas distintas, a partir de lo que ya hay:
  - La Dama de Terciopelo, en la cámara acorazada;
  - el Retrato del Duque (galería oeste);
  - el Ánfora griega (antigüedades);
  - el Busto de bronce (despacho);
  - la Miniatura (taller);
  - la caja fuerte.
- Una cafetera en la garita.
- Protección de cada candidata (2 de combinación con la caja fuerte, 2 de presión y 2 de sensor), y, hasta #119, la mesa de copias del taller (TAL), un cuadro eléctrico de alarma por ala y el panel de pilotos en la garita.
  - #119: fuera de `data/levels/museum_v2.json` las secciones `replica_tables` (2 mesas), `wings` (4 cuadros; solo los usa `PowerBox3D`) y `pilot_panel`. Las protecciones de las 20 piezas no cambian.
- Las salidas exteriores P01, P02 y P03 marcadas como «salida» (FEAT-034 añadió P38: son 4, en `exits` de `data/levels/museum_v2.json`).
- #120: una reja recogida sobre cada una de las 4 salidas (en P03, la persiana). Sale de `exits`; no hace falta un dato nuevo en el nivel.
- #121 (aprobado por el usuario el 2026-11-05): una caja de la reja por salida, en la pared de dentro (muro sur, z = 35,8), junto a la puerta y a la altura de la mano. Dato nuevo `"gate_box": [x, z]` en cada entrada de `exits` de `data/levels/museum_v2.json` (ya escrito; hasta la FEAT nadie lo lee): P01 en (26,4, 35,8), al este de la puerta doble; P02 en (4,2, 35,8), al oeste (al este está el interruptor de C7); P03 en (47,3, 35,8), al este de la persiana, pasado el palé 4; P38 en (57,4, 35,8), al este. La FEAT comprueba en el editor que se llega a cada una sin que la tape un mueble.

## Qué medir
| Evento | Pregunta | Alarma |
|---|---|---|
| `match_end` (resultado, tiempo, piezas robadas, guardias) | ¿Quién gana y con cuántos guardias? | Un bando gana más del 65 % de las partidas con el mismo número de guardias |
| `guard_drowsy` / `coffee` | ¿El sueño saca a los guardias de la garita y los devuelve? ¿El café es un trámite? | Más de 3 cafés por guardia y partida (es un trámite), o ninguno (el sueño no muerde) |
| Segundos de cada guardia en la garita (#116) | ¿La garita es el nuevo campamento? | Un guardia pasa más del 50 % de la partida en la garita en 3 de 5 partidas |
| Resultado por tiempo (#116) | ¿Los guardias ganan solo por esperar? | Más del 60 % de las partidas acaban en «AMANECE» |
| Persecuciones antes de la alarma (#116) | ¿Andar en calma hace imposible atraparlo? | Ninguna captura en 5 partidas |
| `trace_found` | ¿Los rastros dan juego? | Más del 50 % de los robos se descubren antes de 20 s (el ladrón no puede esconderse) |
| `coin_thrown` / `walkie` | ¿Se usan las herramientas? | Menos de 1 uso por partida |
| Resultado con la alarma (#120) | ¿La cuenta atrás da decisiones o solo una carrera? | Más del 70 % de las alarmas acaban en «ENCERRADO» (30 s es poco o los guardias cubren todo), o más del 70 % en huida (sobra tiempo) |
| Huidas a medias por G y s (#120; con #123) | ¿El empate cae en la mitad del encargo? | Con s < k/2, el ladrón gana más de un tercio; o con s > k/2, los guardias ganan más de un tercio (el juego de un bando pesa más que una pieza) |
| Huidas a medias tras un robo a lo bruto con 3-4 guardias (#123) | ¿Q a la pieza más cercana y correr es la jugada óptima? | El ladrón gana más de 2 de cada 3. Primer mando: `thief_fast_escape` a 1 |
| Desglose de la puntuación de equipo (#123) | ¿Qué decide la huida a medias? | Una sola línea (verlo, golpes o huida rápida) da más de la mitad de la diferencia en más de la mitad de las huidas |
| Despistes, walkies que aciertan y robos cerca por partida (#123) | ¿Los puntos nuevos pasan? | Más de 4 despistes por partida (no pueden seguirlo) o ninguno en 5; ningún walkie que acierte en 5 partidas con 2 o más humanos (la ventana es corta); más de 1 robo cerca por guardia y partida (5 m es mucho) |
| «MEJOR DE LA NOCHE» por bando (#123) | ¿Las fichas individuales están equilibradas? | El ladrón lo gana más del 70 % de las partidas, o menos del 15 % |
| Personales de quien pasa más tiempo en la garita (#123) | ¿Patrullar vale más que la garita? | El guardia de la garita tiene más personales que el que patrulla en más de la mitad de las partidas |
| Cajas saboteadas y reparadas por partida (#121) | ¿Sabotear es la apertura obligada? ¿La contra funciona? | El ladrón sabotea 3 o más cajas en más de la mitad de las partidas (seguro gratis); ninguna en 5 partidas (no compensa); o los guardias reparan menos del 20 % de las saboteadas (la contra no se ve) |
| Final de las partidas con rejas cerradas y salidas abiertas (#121) | ¿El sabotaje compra unos segundos o la partida entera? | Más del 70 % acaban en huida por una reja saboteada, o la prórroga dura de media más de 60 s |
| Robos por método y fallos de minijuego (#119) | ¿Se entiende y compensa robar en silencio? | Más de la mitad de las piezas a lo bruto en 3 de 5 partidas, o más de 3 fallos por pieza de media (el minijuego es demasiado duro) |

## Estado
#123 (aprobado por el usuario el 2026-11-05, a falta de su FEAT): puntos de los dos bandos. Reglas del usuario (entrevista del 2026-11-05); números, «puntos de equipo» (las bolsas de «proteger» y «encerrado») y tabla de escenarios propuestos por `game-designer` (R4b, R11, «Puntos (#123)»). Decisiones en «Decisiones (usuario, 2026-11-05, #123)».
#121 (aprobado por el usuario el 2026-11-05, a falta de su FEAT): sabotear la caja de la reja de una salida (minijuego de tres pasos, ~15 s) para que esa reja no baje con la alarma; la caja se nota de cerca y un guardia la repara en 8 s (R7c). Números en `heist_rules.tres` (`box_*`) y `score_rules.tres`; cajas en `exits` de `museum_v2.json`.
#120 (aprobado por el usuario el 2026-11-04, a falta de su FEAT): con la alarma, `lockdown_time` s para huir con lo puesto (huida completa o a medias) antes de que bajen las rejas de las 4 salidas; si no, «ENCERRADO». Lo siguiente, #121 (sabotear la caja de una reja), parte de R7b tal como está escrita.
#119 (aprobado por el usuario el 2026-11-04, a falta de su FEAT): todo lo necesario para robar está en la pieza; robo silencioso con E y su minijuego (R9); Q, lo único a lo bruto; fuera las mesas de copias, los cuadros eléctricos de las alas y el panel de pilotos.
#118 (2026-11-04, a falta de su FEAT): una cámara en cada sala y solo la que está en pantalla ve al ladrón (`interaction.md` parte M).
#116 (2026-10-30, implementado el 2026-11-04): fuera relojes y rondas, sueño fuera de la garita (R5), IA de patrulla libre (R5c), correr solo con alarma (R5d) y final por tiempo para los guardias (R4).
FEAT-034 amplía el museo: 20 candidatas, ventilación (R10), puerta de la garita (R11), 4 salidas y partida de 12 minutos; el nivel está en `docs/gdd/levels/museum_v2.md`.
FEAT-033 añade el somnífero, la adrenalina y el bajón (R5b), el «Zzz» de las cabezadas y el peso del botín (R3).
Entrega 1 implementada en FEAT-028 (lista, carta, escape, condiciones de victoria, combinación y robo a lo bruto). Entrega 4 en FEAT-032 (cambiazo con piezas de pega que los guardias examinan, y corte de corriente por ala con panel de pilotos): **las cuatro entregas están implementadas**. Entrega 3 en FEAT-031 (rastros, alerta, monedas, walkie y luces de alarma). Entrega 2 en FEAT-029 (sueño y café; la cafetera es el carrito CC0 de Poly Haven; el bostezo y el café, grabaciones CC-BY de OpenGameArt desde FEAT-030). Entregas, cada una se puede probar por separado:
1. lista + carta + escape + condiciones de victoria, con las protecciones de combinación y el robo a lo bruto;
2. sueño y café;
3. rastros + alerta + monedas + walkie;
4. el cambiazo con piezas de pega y el corte de corriente.

## Decisiones (usuario, 2026-11-05, #123)
El usuario aceptó todas las recomendaciones de `game-designer` (entre paréntesis), y que la huida por una reja saboteada de #121 pase de ganar con holgura a un resultado ajustado (si el playtest muestra que sabotear no compensa, `thief_sabotage_escape` de 60 a 80).
1. ¿«Σ individuales» del issue son los **personales** (sin la parte de las bolsas)? (Sí: si no, la bolsa cuenta dos veces, una entera y otra repartida entre √G.)
2. ¿«Su parte» de «proteger» y «encerrado» es la bolsa entre G? (Sí: cada ficha `redondear(bolsa / G)`.)
3. ¿La huida a medias depende del número de guardias, [75, 60, 54, 50], para que la huida limpia empate justo en la mitad, o un valor fijo? (Por guardias. Con un fijo de 60, el corte queda en s = 2,10, 1,50 y 0,98: casi, pero el empate exacto con 1 y 3 guardias se pierde.)
4. ¿La alarma del ladrón baja a −15? (Sí: con −25 una persecución mueve el empate pieza y media.)
5. ¿«Encerrado» pasa a bolsa de 150? (Sí: lo que vale la captura. Con 100 en bolsa, 3 guardias cobrarían 33 cada uno, menos que reparar una caja.)
6. ¿La alarma por dos rastros da los +50 a quien descubre el segundo? (Sí: es detectar, que es lo que #123 quiere premiar frente a la garita.)
7. ¿Las vistas por la cámara en pantalla cuentan para «verlo» (+25 al que mira, −10 al ladrón), para cortar el despiste y para el walkie? (Sí, como ya cuentan para la alarma: mirar la cámara justa es jugar. Hasta ahora no contaban en el informe.)
8. «Descubrir un engaño» incluye el sensor puenteado, pero con #119 un sensor puenteado es un pedestal vacío que no se examina. ¿Solo la falsificación? (Sí; descubrir cualquier rastro ya le quita al ladrón los +20 de robo limpio.)

## Decisiones (usuario, 2026-10-30, #116, entrevista tras el playtest con amigos)
1. Fuera los relojes de fichar y las rondas: relojes del mapa, tablilla de ronda, flecha al reloj (FEAT-042), faltas y relojes del informe y de los puntos, y rutas de ronda de la IA.
2. El sueño sube fuera de la garita (andando o quieto) y no sube dentro, mire las cámaras o no; el café lo deja a 0 y da un rato despejado; desaparece acampar. Bostezos a los 3 minutos fuera sin café y cabezadas a los 4.
3. Los guardias andan; solo corren con la alarma.
4. Al acabarse el tiempo sin que el ladrón escape, ganan los guardias.
5. La IA patrulla salas a su aire (sobre todo donde hay piezas) y vuelve a por café cuando le entra sueño.
6. Puntos del guardia: visto, golpes, captura y cabezadas, sin relojes ni faltas (el sistema completo, en #123).

## Decisiones (usuario, 2026-10-28)
1. **Poder de la alarma**: en «alarma», los guardias pueden **encender de golpe todas las luces de un ala durante 30 s** con los interruptores que ya existen. Las puertas, con «cerrar con llave» y puertas abiertas como rastro, irán en su propio diseño más adelante.
2. **El ladrón ve el nivel de alerta.**

## Decisiones (usuario, 2026-11-04, #119, tras el playtest)
1. **Todo está en la pieza**: lo necesario para robar una pieza está en la propia pieza; ninguna protección pide ir a buscar algo a otro sitio. Interruptores, bombillas y monedas son ayudas opcionales.
2. E abre el minijuego de la protección; Q es lo único que roba a lo bruto. Fuera las mesas de copias, los cuadros eléctricos de las alas y el panel de pilotos.
3. **Sensor**: puentear y coger es una sola acción; queda el pedestal vacío, rastro normal anunciado como «sensor puenteado», sin examinar.
4. **Caja fuerte**: sigue sin poder forzarse; su segunda línea dice «La caja fuerte no se puede forzar».
5. **Balanza**: soltar E pausa sin ruido y la aguja sigue yéndose.
6. **Sin copias como objeto**: el ladrón las trae consigo y toda pieza de báscula del encargo admite siempre el cambiazo; el HUD no habla de copias. La falsificación conserva su fallo examinable.
7. Una protección por pieza.
8. Visto a mitad de minijuego, puede terminarlo y la pieza sale en silencio.
9. Los números de R9 (`steal_minigames.tres`), como los propuso `game-designer`.

## Decisiones (usuario, 2026-11-04, #120, tras el playtest)
La regla es del issue #120; los detalles los propuso `game-designer` y el usuario los aprobó todos.
1. **Puntos de los guardias**: se traen de #123 «proteger» (`guard_protect`, +60 a cada guardia por pieza del encargo en su sitio al acabar) y «encerrado» (`guard_lockdown`, +100 a cada guardia). Sin ellos, el ladrón ganaba casi cualquier huida a medias (pilar 4). El resto de #123 sigue en su tarea.
2. **Sin piezas**: la salida no hace nada; al bajar las rejas ganan los guardias, «ENCERRADO» dentro y «SIN BOTÍN» en el callejón.
3. **Alarma con el encargo completo**: huida completa («ESCAPADO», +150) si sale antes de las rejas.
4. **Bajo la reja**: se puede pasar hasta que toca el suelo.
5. **Alarma con menos de 30 s de partida**: manda el reloj de la partida («AMANECE»); no se alarga.
6. **El timbre**: suena desde la alarma hasta el final, a golpes y por debajo de los pasos, y no es ruido para la percepción.
7. **La IA sin red**: la que no persigue ni investiga cubre la salida libre más cercana a la última campana, una por guardia.
8. **La media de los guardias**: redondeada al entero más cercano; se compara lo que se enseña.

## Decisiones (usuario, 2026-11-05, #121, tras el playtest)
La regla es del issue #121; los detalles (R7c) los propuso `game-designer` y el usuario los aprobó todos el 2026-11-05.
1. **Los +60** (`thief_sabotage_escape`) solo cuentan si el ladrón huye por la salida saboteada después de que bajen las demás rejas, en huida completa o a medias. Durante la cuenta atrás todas las salidas están abiertas y el sabotaje no ha hecho nada.
2. **Las salidas abiertas se marcan en el plano de los dos bandos** al cerrarse las rejas, con «REJAS CERRADAS · N SALIDAS ABIERTAS».
3. **La chispa se ve por la cámara en pantalla**, porque es luz; la tapa torcida, no. No es un aviso: hay que estar mirando esa sala en ese momento.
4. **Una caja saboteada descubierta no es rastro** (R6) ni sube la alerta. El guardia gana +40 y la pista; para contarlo, el walkie.
5. **Cerrar la tapa (paso 3) es solo mantener E**, como quitarla: la habilidad está en los cables.
6. Los números de R7c (`box_*` en `heist_rules.tres`; `thief_sabotage`, `thief_sabotage_escape` y `guard_repair` en `score_rules.tres`) y las cajas en `gate_box` de `museum_v2.json`, como los propuso `game-designer`.
