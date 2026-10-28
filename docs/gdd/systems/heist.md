# El golpe: la lista del coleccionista, el café y la alerta

- **Estado**: aprobado por el usuario el 2026-10-28 (decisiones tomadas en conversación), salvo las preguntas abiertas del final.
- **Origen**: rediseño pedido por el usuario el 2026-10-28 para que los guardias no acampen en un sitio y para que su turno sea divertido. Temática: `docs/decisions/2026-10-28-tematica-caballero-ladron.md`.
- **Relacionado**: `interaction.md` (relojes de ronda, CCTV), `vision.md` (niebla y filtro de red), `stealth.md` (percepción y ruido), `gentleman.md` (temática; sus M1-M3 quedan sustituidas por este documento), `docs/gdd/levels/museum_v2.md`.

## Fantasía
- **Ladrón**: «Un coleccionista me ha encargado tres piezas. Ellos no saben cuáles. Entro, me las llevo y salgo por donde menos me esperen».
- **Guardias**: «Sabemos que viene, no qué busca. Hay que patrullar, leer lo que deja a su paso y cerrarle el cerco cuando se delate. Y no dormirse».

## Por qué
Hasta ahora el ladrón necesitaba una pieza fija (la Pieza Maestra de la cámara acorazada) y volver a un coche fijo. Lo óptimo para los guardias era acampar en esos dos puntos. Este diseño ataca las tres causas:
- **no saber qué defender**: la lista;
- **no saber por dónde saldrá**: las salidas;
- **que quedarse quieto cueste**: el café.

Y da a los guardias un juego propio: los rastros y la alerta.

## Reglas

### R1. La lista del coleccionista
- El nivel marca **6 piezas candidatas** repartidas por alas distintas.
- Al empezar, el servidor **sortea** las piezas del encargo, de entre esas 6. Su número depende de los guardias:

  | Guardias | Piezas del encargo |
  |---|---|
  | 1 | 4 |
  | 2 | 3 |
  | 3 | 2 |

- **Quién sabe qué**:
  - **el ladrón** conoce sus piezas desde el principio (en la tarjeta de objetivo y en su plano);
  - **los guardias** saben cuáles son las 6 candidatas y cuántas busca el ladrón, pero no cuáles.
- **Robar** una pieza es la interacción de botín de siempre (E). Una pieza que no está en el encargo **no se puede robar**: el ladrón no pierde el tiempo con ella.
- Las piezas van al maletín, sin cargar en brazos. El botín pesado queda aparcado.
- La **caja fuerte** es una de las 6 candidatas: si le toca, la pieza está dentro y hay que abrirla con el dial.
- Desaparecen la **cuota de dinero** y la **Pieza Maestra fija**. El resto del botín del museo se retira del nivel.

### R2. La carta
Al empezar, los guardias ven en su tarjeta de objetivo:

> «Esta noche me llevaré **tres** piezas de su colección. Con mis respetos, —V.»

El número es el del encargo. La carta no da ninguna pista de cuáles son.

### R3. Escapar
- Con todas las piezas del encargo, el ladrón gana al **cruzar cualquiera de las salidas exteriores**. En `museum_v2` hay 3: P01 (vestíbulo), P02 (galería suroeste) y P03 (muelle).
- Sin todas las piezas, las salidas no hacen nada. El coche queda como decorado.

### R4. Cómo se gana
| Resultado | Cuándo |
|---|---|
| **Gana el ladrón** | Sale por una salida exterior con todas las piezas del encargo antes de que acabe el tiempo |
| **Ganan los guardias** | Lo atrapan (la porra, como hoy), o se acaba el tiempo con la ronda al día (`interaction.md` R3) |
| **Empate** | Se acaba el tiempo con la ronda rota |

Desaparece el caso «ronda rota y el ladrón tenía la Pieza Maestra = gana el ladrón». Para ganar, el ladrón **siempre** tiene que escapar.

### R5. El sueño y el café
- **Cómo se mide**: cada guardia guarda dónde ha estado en los últimos `window` segundos. Si ha pasado más de `linger_ratio` de ese tiempo dentro de un círculo de radio `radius` alrededor de su posición media, está **acampando**. No importa que dé pasos dentro del círculo.
- **El sueño** es una barra de 0 a 1:
  - sube a `rise_rate` por segundo mientras acampa;
  - no baja sola: moverse solo impide que suba;
  - con la alerta en «alarma» no sube.
- **Niveles**:

  | Sueño | Nivel | Efecto |
  |---|---|---|
  | < `drowsy_at` | Despierto | Ninguno |
  | ≥ `drowsy_at` | Somnoliento | Bosteza cada `yawn_interval` s: un ruido de radio `yawn_radius` que oye todo el mundo. Sus alcances de vista se multiplican por `drowsy_sight` |
  | ≥ `exhausted_at` | Agotado | Lo anterior, y además da cabezadas: cada `nod_interval` s, su vista se apaga `nod_time` s (no percibe nada) |

- **El café**: E en la **cafetera de la garita** (`coffee_time` s, que suenan con radio `coffee_radius`).
  - Deja el sueño a 0 y da `fresh_time` s **despejado**, sin que suba.
  - Mirar los monitores cuenta como acampar, igual que cualquier otro sitio.
- El guardia ve su nivel de sueño en el HUD (una taza que se vacía). El ladrón no lo ve, pero lo oye bostezar.

### R6. Rastros
- Cada pieza robada deja su **pedestal vacío**.
- Cuando un guardia lo ve, o lo ve una cámara mientras alguien mira los monitores, el rastro queda **descubierto**:
  - aparece en el plano de todo el equipo;
  - sube la alerta (R7);
  - esa pieza deja de ser candidata en el plano de los guardias. Saben que el ladrón la tenía en su lista y deducen cuántas le quedan.
- Un rastro solo se descubre una vez.

### R7. Nivel de alerta
| Nivel | Se llega con | Qué ganan los guardias |
|---|---|---|
| **Calma** | Al empezar | — |
| **Sospecha** | 1 rastro descubierto | Los rastros se ven en el plano del equipo (R6) |
| **Alarma** | 2 rastros descubiertos, o que un guardia (o una cámara vigilada) vea al ladrón | Poder de alarma (pregunta abierta 1). El sueño deja de subir |

- La alerta **nunca baja** durante la partida.
- Todos la ven, el ladrón también: sabe que le han descubierto, y la tensión sube.

### R8. Una herramienta por bando
- **Ladrón: monedas.**
  - Tiene `coins` por partida.
  - Con el botón de lanzar, la moneda vuela al punto del ratón, a `throw_range` m como máximo, y suena al caer con radio `coin_radius`.
  - Los guardias la oyen como cualquier ruido. Nadie distingue una moneda de un paso.
- **Guardias: walkie.**
  - Con su tecla marca un punto en el plano de todo el equipo durante `ping_time` s.
  - El chasquido suena con radio `walkie_radius` alrededor de quien habla.
  - Espera `walkie_cooldown` s entre usos.

### R9. Protecciones de las piezas
Cada candidata tiene una protección. El ladrón elige entre **desactivarla y robar en silencio** o **robar a lo bruto**: es instantáneo, pero suena la campana de alarma de esa sala (un ruido de radio `brute_radius`) y la alerta pasa a «alarma» al momento. El reparto es de 2 piezas por tipo, y la caja fuerte es de combinación.

| Protección | Cómo se desactiva | Qué deja | Contrajuego |
|---|---|---|---|
| **Combinación** (vitrina con dial; la caja fuerte) | El panel del dial que ya existe | La vitrina vacía (rastro normal, R6) | La caja fuerte no admite el robo a lo bruto |
| **Pedestal de presión: el cambiazo** | Coger una **pieza de pega** en la mesa de réplicas del taller (una cada vez) y cambiarla por el original (`swap_time` s, en silencio) | Una **copia parecida pero no igual**: cada partida se sortea un fallo por copia (color, tamaño, pose o un detalle que falta) | Los guardias tienen en el plano la **ficha** de cada candidata y pueden notar la diferencia. **Examinar** la pieza (E, `inspect_time` s) dice «¡Es una falsificación!» (rastro descubierto) o «Auténtica» |
| **Sensor del ala: corte de corriente** | Cortar el circuito de alarma en el **cuadro eléctrico de su ala** (`cut_time` s) | Mientras dura el corte, todas las piezas de ese ala se cogen sin alarma. El ala se queda **sin luz**, y en la garita se enciende un **piloto rojo** con el ala cortada | Ver el piloto o la oscuridad. Restablecer la corriente en el cuadro (`restore_time` s), lo que vuelve a proteger las piezas que queden |

- **Una pieza de pega sin descubrir no es rastro**: el pedestal parece intacto. Es la jugada elegante del caballero.
- Un guardia que examina una pieza auténtica pierde el tiempo. No compensa revisarlo todo a ciegas.
- El corte de corriente no cuenta como rastro descubierto hasta que un guardia ve el piloto o llega al ala a oscuras.

## Números
Viven en un recurso nuevo, `data/balance/heist_rules.tres` (`HeistRules`). Son valores iniciales para afinar jugando.

| Mando | Campo | Tipo | Rango | Inicial |
|---|---|---|---|---|
| Candidatas | nivel (`targets`) | ritmo | 5-8 | 6 |
| Piezas del encargo según guardias | `pieces_by_guards` | ritmo | — | [4, 3, 2] |
| Ventana del sueño | `window` | ritmo | 30-90 s | 60 |
| Radio de acampada | `radius` | ritmo | 5-12 m | 8 |
| Proporción que cuenta | `linger_ratio` | ritmo | 0,6-0,9 | 0,75 |
| Subida del sueño | `rise_rate` | ritmo | — | 1/90 por s (unos 45 s hasta somnoliento) |
| Umbrales | `drowsy_at` / `exhausted_at` | ritmo | — | 0,5 / 1,0 |
| Bostezo | `yawn_interval` / `yawn_radius` | sensación | 6-15 s / 5-10 m | 8 / 7 |
| Vista somnolienta | `drowsy_sight` | ritmo | 0,6-0,9 | 0,8 |
| Cabezadas | `nod_interval` / `nod_time` | ritmo | — | 10 / 1,5 s |
| Café | `coffee_time` / `coffee_radius` / `fresh_time` | ritmo | — | 3 s / 8 m / 120 s |
| Monedas | `coins` / `throw_range` / `coin_radius` | ritmo | 2-5 / 6-14 m / 6-12 m | 3 / 10 / 9 |
| Walkie | `ping_time` / `walkie_radius` / `walkie_cooldown` | ritmo | — | 8 s / 6 m / 10 s |
| Robo a lo bruto | `brute_radius` | sensación | 12-20 m | 15 |
| Cambiazo / examinar | `swap_time` / `inspect_time` | ritmo | 1-4 s / 1-3 s | 2 / 2 |
| Cortar / restablecer la corriente | `cut_time` / `restore_time` | ritmo | 2-5 s | 3 / 3 |

## Contrajuego
| Acción | Quién | Qué percibe el otro | Cómo responde |
|---|---|---|---|
| Acampar junto a una candidata | Guardia | Bostezos, y el puesto vacío cuando va a por café | Robar las otras piezas, o esperar al café |
| Ir a por café | Guardia | El ruido de la cafetera | Aprovechar que deja el puesto |
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
- **Sin red**: los 2 guardias de IA patrullan como hoy; no les afecta el sueño ni usan el walkie (más adelante).

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
| `guard_drowsy` / `coffee` | ¿Se acampa? ¿El café es un trámite? | Más de 3 cafés por guardia y partida (es un trámite), o ninguno (el sueño no muerde) |
| `trace_found` | ¿Los rastros dan juego? | Más del 50 % de los robos se descubren antes de 20 s (el ladrón no puede esconderse) |
| `coin_thrown` / `walkie` | ¿Se usan las herramientas? | Menos de 1 uso por partida |

## Estado
Sin implementar. Entregas propuestas, cada una se puede probar por separado:
1. lista + carta + escape + condiciones de victoria, con las protecciones de combinación y el robo a lo bruto;
2. sueño y café;
3. rastros + alerta + monedas + walkie;
4. el cambiazo con piezas de pega y el corte de corriente.

## Preguntas abiertas
1. **Poder de la alarma.** El museo **no tiene puertas que se abran y se cierren** (los pasos son huecos), así que «cerrar puertas con llave» necesita antes un sistema de puertas. Opciones:
   - **(a) Puertas ahora.** Abrir y cerrar (cortan la vista y suenan), cerrar con llave como poder de la alarma (máximo 2 a la vez, nunca las salidas) y puertas abiertas como rastro. Es más trabajo, pero las puertas son la base de mucho sigilo.
   - **(b) Simple ahora y puertas después.** En alarma, los guardias pueden **encender de golpe todas las luces de un ala** durante 30 s, con los interruptores que ya existen.

   Recomendación: **(b) ahora y (a) en su propio diseño después**.
2. ¿El ladrón **ve el nivel de alerta**? Recomendación: sí.
