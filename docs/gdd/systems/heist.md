# El golpe: la lista del coleccionista, el café y la alerta

- **Estado**: aprobado por el usuario el 2026-10-28 (decisiones tomadas en conversación). **2026-10-30, #116**: R4, R5, R7 y R11 reescritas y R5c y R5d nuevas (fuera relojes y rondas; sueño fuera de la garita; IA de patrulla libre; correr solo con alarma). Las reglas las decidió el usuario en la entrevista de #116; los números nuevos los aprobó el 2026-11-04. **2026-11-04, #118**: «cámara vigilada» pasa a ser la cámara que está en pantalla en la mesa (una cada vez, `interaction.md` M5); R5, R6, R7 y el contrajuego ajustados.
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
- **Robar** una pieza es la interacción de botín de siempre (E). Una pieza que no está en el encargo **no se puede robar**: el ladrón no pierde el tiempo con ella.
- Las piezas van al maletín, sin cargar en brazos. El botín pesado queda aparcado.
- Las **cajas fuertes** (2) son candidatas: si le toca una, la pieza está dentro y hay que abrirla con el dial.
- Desaparecen la **cuota de dinero** y la **Pieza Maestra fija**. El resto del botín del museo se retira del nivel.

### R2. La carta
Al empezar, los guardias ven en su tarjeta de objetivo:

> «Esta noche me llevaré **tres** piezas de su colección. Con mis respetos, —V.»

El número es el del encargo. La carta no da ninguna pista de cuáles son.

### R3. Escapar
- Con todas las piezas del encargo, el ladrón gana al **cruzar cualquiera de las salidas exteriores**. En `museum_v2` hay 3: P01 (vestíbulo), P02 (galería suroeste) y P03 (muelle).
- Sin todas las piezas, las salidas no hacen nada. El coche queda como decorado.
- **Peso del botín** (FEAT-033): cada pieza del encargo que lleva le quita `loot_slow` de velocidad, hasta un mínimo de `loot_min_speed`.

### R4. Cómo se gana (reescrita el 2026-10-30, #116)
| Resultado | Cuándo |
|---|---|
| **Gana el ladrón** | Sale por una salida exterior con todas las piezas del encargo antes de que acabe el tiempo |
| **Ganan los guardias** | Lo atrapan (la porra, como hoy), o se acaba el tiempo sin que haya escapado (`TIME_EXPIRED`, sello «AMANECE») |

- Ya no hay empate ni «ronda rota»: desaparecen `TIME_EXPIRED_BREACH` y `TIME_EXPIRED_DRAW` y la tabla R4 de `interaction.md`. Para ganar, el ladrón **siempre** tiene que escapar.
- **Por qué**: sin relojes, el tiempo es la presión del ladrón; la de los guardias es que, si se quedan en la garita, él se lleva el encargo sin que nadie lo vea (R5, «Presión sobre los guardias»).

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
- Cada pieza robada deja su **pedestal vacío**.
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
| **Alarma** | 2 rastros descubiertos, o que un guardia (o una cámara vigilada: desde #118, solo la que está en pantalla en la mesa) vea al ladrón | Encender de golpe todas las luces de un ala durante 30 s (decisión 1). El sueño deja de subir. Pueden correr (R5d, desde el 2026-10-30) |

- La alerta **nunca baja** durante la partida.
- Todos la ven, el ladrón también: sabe que le han descubierto, y la tensión sube.
- **Campanas en el plano** (2026-11-04, #117): cada vez que salta la alarma queda una campana con «hace m:ss» en el plano de los dos bandos (las 8 últimas). Va donde saltó:
  - un guardia o una cámara vigilada (la que está en pantalla, #118) ve al ladrón: donde estaba el ladrón en ese momento (excepción a la percepción por guardia, ver `stealth.md` P2.3);
  - robo a lo bruto: en la pieza;
  - 2 rastros descubiertos: en el último rastro, nunca donde está el ladrón.
- **Cortes y luz en el plano** (#117): solo el ladrón ve en su plano qué cuadros están cortados y cuánta luz da cada sala. El de los guardias los enseña siempre en estado normal, para no saltarse R9.

### R11. Informe de la noche (FEAT-041; sin relojes ni faltas desde el 2026-10-30, #116)
- Al acabar la partida, todos los personajes se quedan quietos y el informe ocupa la pantalla: primero un sello 1,5 s («ESCAPADO», «CAPTURADO» o «AMANECE»), después el veredicto y una ficha por jugador.
- **Ladrón**: cada pieza del encargo con ✔/✘ y cómo se robó (abriendo el dial, a lo bruto, con el cambiazo, con la corriente cortada), alarmas que hizo saltar, monedas, veces que lo vieron y la hora de la huida.
- **Cada guardia**: veces que vio al ladrón (cuenta cuando empieza a verlo; perderlo menos de 2 s no cuenta otra vez; las cámaras no cuentan), golpes de porra, captura y cabezadas.
- **Puntos** (`score_rules.tres`, no cambian el juego, solo lo valoran): ladrón +100 por pieza, +150 por huir, −25 por alarma, −10 por cada vez que lo ven; guardia +25 por cada vez que lo ve, +50 por golpe, +150 por la captura, −15 por cabezada. El que más tiene lleva el sello «MEJOR DE LA NOCHE».
  - 2026-10-30, #116: fuera los puntos por reloj (`guard_clock`) y por falta (`guard_fault`), que se borran de `score_rules.tres`; la hoja de ronda desaparece del informe. Lo que queda es provisional: el sistema completo de puntos de los guardias (proteger, detectar, atrapar, equipo) es #123.
  - Un guardia que se queda toda la partida en la garita y no ve al ladrón acaba con 0 puntos; uno que patrulla con sueño puede acabar en negativo por las cabezadas. Lo corrige #123 con «proteger» (+60 por pieza que sigue en su sitio).
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

### R9. Protecciones de las piezas
Cada candidata tiene una protección. El ladrón elige entre **desactivarla y robar en silencio** o **robar a lo bruto**: es instantáneo, pero suena la campana de alarma de esa sala (un ruido de radio `brute_radius`) y la alerta pasa a «alarma» al momento. Reparto (FEAT-034): 7 de combinación (dos de ellas, cajas fuertes), 7 de presión (con dos mesas de réplicas, en el taller y en el ala este) y 6 de sensor, en 4 alas con su cuadro eléctrico.

| Protección | Cómo se desactiva | Qué deja | Contrajuego |
|---|---|---|---|
| **Combinación** (vitrina con dial; la caja fuerte) | El panel del dial que ya existe | La vitrina vacía (rastro normal, R6) | La caja fuerte no admite el robo a lo bruto |
| **Pedestal de presión: el cambiazo** | Coger una **pieza de pega** en la mesa de réplicas del taller (una cada vez) y cambiarla por el original (`swap_time` s, en silencio) | Una **copia parecida pero no igual**: cada partida se sortea un fallo por copia (color, tamaño, pose o un detalle que falta) | Los guardias tienen en el plano la **ficha** de cada candidata y pueden notar la diferencia. **Examinar** la pieza (E, `inspect_time` s) dice «¡Es una falsificación!» (rastro descubierto) o «Auténtica» |
| **Sensor del ala: corte de corriente** | Cortar el circuito de alarma en el **cuadro eléctrico de su ala** (`cut_time` s) | Mientras dura el corte, todas las piezas de ese ala se cogen sin alarma. El ala se queda **sin luz**, y en la garita se enciende un **piloto rojo** con el ala cortada | Ver el piloto o la oscuridad. Restablecer la corriente en el cuadro (`restore_time` s), lo que vuelve a proteger las piezas que queden |

- **Una pieza de pega sin descubrir no es rastro**: el pedestal parece intacto. Es la jugada elegante del caballero.
- Un guardia que examina una pieza auténtica pierde el tiempo. No compensa revisarlo todo a ciegas.
- El corte de corriente no cuenta como rastro descubierto hasta que un guardia ve el piloto o llega al ala a oscuras.

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
| Cambiazo / examinar | `swap_time` / `inspect_time` | ritmo | 1-4 s / 1-3 s | 2 / 2 |
| Cortar / restablecer la corriente | `cut_time` / `restore_time` | ritmo | 2-5 s | 3 / 3 |

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
| Salir | Ladrón | Nada antes de cruzar | Patrullar cerca de las salidas al final, sin poder cubrir las 3 |
| Dar el cambiazo | Ladrón | Una copia con un fallo | Fijarse en ella, compararla con la ficha y examinarla |
| Cortar la corriente de un ala | Ladrón | El piloto rojo en la garita y el ala a oscuras | Ir al cuadro y restablecerla |
| Robar a lo bruto | Ladrón | La campana y la alarma al momento | Ir todos hacia allí y cerrar las salidas de esa zona |

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

## Red
- **Al ladrón**: su encargo, como estado privado (`#private`, igual que la caja fuerte).
- **A los guardias**: las candidatas, el número de piezas y los rastros descubiertos. Nunca el encargo.
- **A todos**: la alerta, los ruidos (bostezos, café, monedas, walkie) y si cada pedestal está ocupado o vacío. Estos últimos solo se dibujan si se ven, por la niebla y la memoria de `vision.md`.
- **Al propio guardia**: su sueño, como estado privado.

## Cambios en el nivel (`museum_v2`)
- 6 candidatas en alas distintas, a partir de lo que ya hay:
  - La Dama de Terciopelo, en la cámara acorazada;
  - el Retrato del Duque (galería oeste);
  - el Ánfora griega (antigüedades);
  - el Busto de bronce (despacho);
  - la Miniatura (taller);
  - la caja fuerte.
- Una cafetera en la garita.
- Protección de cada candidata (2 de combinación con la caja fuerte, 2 de presión y 2 de sensor), la mesa de réplicas en el taller (TAL), un cuadro eléctrico de alarma por ala y el panel de pilotos en la garita.
- Las salidas exteriores P01, P02 y P03 marcadas como «salida».

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

## Estado
#118 (2026-11-04, a falta de su FEAT): una cámara en cada sala y solo la que está en pantalla ve al ladrón (`interaction.md` parte M).
#116 (2026-10-30, implementado el 2026-11-04): fuera relojes y rondas, sueño fuera de la garita (R5), IA de patrulla libre (R5c), correr solo con alarma (R5d) y final por tiempo para los guardias (R4).
FEAT-034 amplía el museo: 20 candidatas, ventilación (R10), puerta de la garita (R11), 4 salidas y partida de 12 minutos; el nivel está en `docs/gdd/levels/museum_v2.md`.
FEAT-033 añade el somnífero, la adrenalina y el bajón (R5b), el «Zzz» de las cabezadas y el peso del botín (R3).
Entrega 1 implementada en FEAT-028 (lista, carta, escape, condiciones de victoria, combinación y robo a lo bruto). Entrega 4 en FEAT-032 (cambiazo con piezas de pega que los guardias examinan, y corte de corriente por ala con panel de pilotos): **las cuatro entregas están implementadas**. Entrega 3 en FEAT-031 (rastros, alerta, monedas, walkie y luces de alarma). Entrega 2 en FEAT-029 (sueño y café; la cafetera es el carrito CC0 de Poly Haven; el bostezo y el café, grabaciones CC-BY de OpenGameArt desde FEAT-030). Entregas, cada una se puede probar por separado:
1. lista + carta + escape + condiciones de victoria, con las protecciones de combinación y el robo a lo bruto;
2. sueño y café;
3. rastros + alerta + monedas + walkie;
4. el cambiazo con piezas de pega y el corte de corriente.

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
