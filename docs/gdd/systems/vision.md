# Visión y niebla de guerra

- **Estado**: aprobado por el usuario el 2026-10-24, con las 5 recomendaciones de «Decisiones»
- **Origen**: petición del usuario del 2026-10-24, tras jugar: «Como ladrón veo dónde están los guardias por la vista cenital de la cámara. Quiero una especie de field of view: fuera del campo de visión, una niebla de guerra que impida ver la posición de guardias o ciertos objetos dentro de las salas.»
- **Relacionado**:
  - `stealth.md`: percepción de los guardias, P2.1 (el ladrón ve todos los haces), P2.2 luz, P2.4 ruido y chevrons, O2 última posición;
  - `interaction.md`: CCTV, M3, M4 pilotos y M6 `cctv_only`;
  - `docs/gdd/levels/museum_v2.md`: muros de 3,2 m, vista baja de 1,2 m, tabique de 2,4 m y ventana V1;
  - `docs/tasks/FEAT-014-red-minima-lan.md`: filtro de red.
- **Alcance**: L. Toca la red, el render y varios sistemas.

## Fantasía
- **Ladrón**: «Conozco el plano de memoria, pero no sé dónde está nadie hasta que lo veo o lo oigo. Una linterna al otro lado del muro me dice por dónde va la ronda; un pasillo a oscuras puede esconder a un guardia esperándome.»
- **Guardias**: «Veo lo que tengo delante. La sala de al lado puede estar vacía o no; para saber si falta el cuadro tengo que ir a mirarlo.»

## Problema que resuelve
La cámara isométrica enseña unos 30 m alrededor del personaje y los muros se dibujan bajos (1,2 m) para ver dentro de las salas. Por eso cualquier jugador ve a los demás a través de las paredes. Para los guardias, el servidor ya oculta al ladrón si no lo perciben (FEAT-014). Para el ladrón no hay filtro: ve a todos los guardias en pantalla, y eso rompe el sigilo, porque nunca hay sorpresa.

## Opciones
| Opción | Cómo funciona | A favor | En contra | Pilares |
|---|---|---|---|---|
| **A (recomendada)**: visión de 360° cortada por muros | Cada jugador ve lo que tiene en línea de visión desde los ojos, en cualquier dirección, hasta un radio. Muros y tabiques cortan la vista; las puertas, los muebles bajos y la ventana V1, no | Es lo que el personaje vería de verdad. Se lee al instante (lo oscuro es «no lo sé»). Encaja con la cámara isométrica, que no tiene «hacia dónde miro» claro | Hay que dibujar un polígono de visión y filtrar en red | Refuerza el 2 (oír vale más) y el 3 (el ladrón ve más lejos y ve linternas) |
| B: cono hacia donde mira, más un círculo corto | Ves en un cono de unos 120° hacia el ratón y en un círculo de 2-3 m a tu alrededor | Mucha tensión: mirar atrás cuesta | Con cámara cenital marea y obliga a girar sin parar. Choca con «visión amplia» del ladrón (pilar 3) | Tensa el 3 |
| C: por salas | Ves entera la sala donde estás y las que asoman por puertas abiertas | Sencillo y barato. Encaja con un museo hecho de salas | Las esquinas y las puertas quedan raras: ves a quien está escondido en una esquina de tu sala pero no a quien está a 1 m tras la puerta | Neutro |

Las reglas de abajo describen la opción A.

## Reglas
### R1. Qué ve cada jugador
- **Zona visible** de un jugador: los puntos del suelo a los que hay línea de visión desde sus ojos (`eye_height` de `perception_guard.tres`, 1,6 m), a una distancia horizontal ≤ su radio.
  - El ladrón usa `thief_view_radius` y los guardias `guard_view_radius`.
  - Solo cortan la vista los **muros y tabiques del nivel**: los del grupo `walls`, con su altura de colisión completa.
  - Los muebles, mostradores y coberturas no la cortan; ocultarse detrás de ellos ya lo resuelve la percepción de `stealth.md` con sus puntos de visibilidad.
  - Las puertas son huecos y dejan ver. La ventana V1 también, porque su alféizar mide 1,0 m y queda por debajo de los ojos.
  - Agacharse no cambia la zona visible.
- **Fuera de la zona visible está la niebla**: se ve el edificio (el plano se conoce), pero oscurecido y desaturado, y sin nada vivo.

### R2. Qué tapa la niebla y qué no
| Cosa | Dentro de tu visión | En la niebla |
|---|---|---|
| Muros, suelos, muebles fijos | Normal | Oscurecidos (recuerdo del plano) |
| Personajes del otro bando | Según R3 | **Ocultos** |
| Compañeros de bando (guardias entre sí) | Normal | Visibles como silueta (D2) |
| Botín, caja fuerte, banderolas de reloj | Estado actual | **Último estado visto** (D4). Si te robaron el cuadro, lo descubres al volver a mirar |
| Luz de las lámparas y pilotos rojos del CCTV | Normal | **Visibles**, porque la luz se ve de lejos (D5) |
| Haces de linterna de los guardias | Normal | **El ladrón los ve siempre**, también tras muros (ya era la regla P2.1). Los guardias ven los de sus compañeros |
| Chevrons de ruido y sonido | Sin cambios | Sin cambios: son el canal principal para saber qué pasa fuera de la vista (pilar 2) |
| Silueta de última posición (O2) | Sin cambios | Se dibuja también en la niebla, porque es un recuerdo |

### R3. Ver al otro bando dentro de tu zona visible
- **El ladrón ve a un guardia** de su zona visible si:
  - el guardia está iluminado (lámpara de P2.2 o su propia linterna encendida), o
  - está a ≤ `dark_sight_radius` del ladrón (D3).
  
  Un guardia quieto a oscuras y con la linterna apagada es una emboscada posible.
- **Un guardia ve al ladrón** solo según su percepción de `stealth.md` (proximidad, cono, luz). La niebla del guardia nunca muestra al ladrón por estar en su zona visible: la percepción manda. La niebla solo decide qué parte del entorno ve.

### R4. Red
El servidor decide; cada cliente solo recibe lo que su jugador ve.

| Dato | Para quién | Cuándo |
|---|---|---|
| Estado de un guardia (posición, giro, linterna) | El ladrón | Solo si R3 lo hace visible. Si no lo ve pero el guardia lleva la linterna encendida, le llega marcado `beam_only` con posición, mirada y linterna: el cliente dibuja **solo el haz**, nunca el cuerpo (P2.1) |
| Estado del ladrón | Cada guardia | Como hoy: su percepción (FEAT-014) o `cctv_only` (FEAT-017) |
| Estado de un compañero guardia | Los otros guardias | Siempre |
| Botín, lámparas, relojes, caja fuerte | Todos | Como hoy. La memoria de R2 la aplica el cliente al dibujar (D4). Sin filtro en el servidor en el PoC: hacer trampa con eso vale poco |

- **Coste**: para cada guardia, entre 1 y 3 rayos ladrón-guardia por tick de snapshot (20 Hz). El polígono que se dibuja lo calcula cada cliente para su propio jugador: unos `fog_rays` rayos a 30 Hz.

### R5. Casos límite
- **Esquinas y marcos de puerta**: la vista pasa por el hueco. Un guardia pegado a la pared de al lado del marco queda en la niebla.
- **Muros bajos de vista frente a colisión alta**: la línea de visión usa la colisión (3,2 m), no la altura visible (1,2 m). Ver por encima de un muro bajo en pantalla no revela lo que hay detrás.
- **Guardia sentado ante los monitores**:
  - su zona visible es la de su cuerpo;
  - las imágenes CCTV no llevan niebla, porque son la vista de la cámara (M6);
  - los pilotos siguen visibles en la niebla para el ladrón (M4).
- **Ladrón en una sala a oscuras**: él ve su entorno con normalidad. Apagar la luz le esconde de los guardias, pero también le impide ver a un guardia a oscuras más allá de `dark_sight_radius`. Es un compromiso a propósito.
- **Fin de la partida**: la niebla se retira para todos, para que vean dónde estaba cada uno.
- **Desconexión**: el actor que se queda quieto se trata como cualquier otro.
- **Sin red** (un jugador o depuración): la niebla se calcula igual, desde el jugador local.

## Números (nuevo recurso `data/balance/vision_rules.tres`)
| Mando | Campo | Tipo | Rango | Valor inicial y por qué |
|---|---|---|---|---|
| Radio de visión del ladrón | `thief_view_radius` | sensación | 12-25 m | 18. Cubre una galería entera y lo que asoma por su puerta. Mayor que el de los guardias (pilar 3, visión amplia) |
| Radio de visión del guardia | `guard_view_radius` | sensación | 9-15 m | 12. Igual que `lit_sight_range`: el guardia ve el entorno hasta donde podría ver al ladrón iluminado |
| Vista a oscuras del ladrón | `dark_sight_radius` | ritmo | 3-9 m | 6. Un guardia quieto a oscuras se descubre a dos pasos de una puerta; más lejos solo se le oye (pasos ×1,5) |
| Brillo de la niebla | `fog_brightness` | sensación | 0,2-0,6 | 0,35. El plano se lee, pero se nota que es «recuerdo» |
| Desaturación de la niebla | `fog_desaturation` | sensación | 0,4-1,0 | 0,7. Gris de foto vieja, a juego con el tono neo-noir |
| Borde suave | `fog_edge_feather` | sensación | 0,3-2,0 m | 1,0. Sin corte duro: la vista se apaga al girar una esquina |
| Rayos del polígono | `fog_rays` | técnico | 128-512 | 256. Bordes limpios a 30 Hz sin coste notable |

`eye_height` se reutiliza de `perception_guard.tres` (1,6 m), sin número nuevo.

## Invariantes medibles
1. Un muro del grupo `walls` entre ladrón y guardia oculta al guardia en el cliente del ladrón (test con el nivel pequeño).
2. El cliente del ladrón nunca recibe el estado completo de un guardia que no ve; solo `beam_only` si lleva la linterna encendida (partida en red con `--net-log`).
3. Un guardia a oscuras y con la linterna apagada es visible para el ladrón a `dark_sight_radius` − 0,01 m e invisible a + 0,01 m, con línea de visión libre.
4. Los guardias se reciben siempre entre sí.
5. Al acabar la partida no queda niebla.
6. Ningún mueble ni cobertura corta la zona visible; solo los muros y tabiques.

## Contrajuego
| Acción | Quién | Qué percibe el otro | Respuesta |
|---|---|---|---|
| Avanzar pegado a los muros, fuera de las líneas de visión | ladrón | Nada si es silencioso; los pasos si corre | Escuchar; patrullar cruzando las puertas en vez de rodear las salas |
| Esperar a oscuras con la linterna apagada (emboscada) | guardia | Nada hasta `dark_sight_radius`; sus pasos al moverse | Escuchar antes de cruzar; encender la luz de la sala (el interruptor suena); lanzar un señuelo |
| Llevar la linterna encendida | guardia | El haz, a través de los muros | Apagarla en las zonas donde se espera al ladrón, a cambio de ver menos |
| Apagar las luces de una zona | ladrón | El clic del interruptor y la sala a oscuras en la niebla | Ir con linterna; la oscuridad también ciega al ladrón más allá de 6 m |
| Robar algo lejos de los guardias | ladrón | Nada hasta que vuelven a mirar (D4) | Rondas que pasan por las salas del botín; la cámara CCTV de la antesala |

## Pilares
| Pilar | Cómo lo cumple |
|---|---|
| 1. 1984 | Sin visión nocturna ni radares: se ve lo que ve un ojo, con luz o de cerca |
| 2. Sonido | Fuera de la vista, el sonido y los chevrons son la única pista: el ruido vale más que nunca |
| 3. Información frente a número | El ladrón ve más lejos (18 frente a 12 m), ve todos los haces y oye más. Los guardias se ven siempre entre sí. Tensión declarada: el ladrón pierde la visión total de hoy, que era un error y no una regla |
| 4. Respuesta | Cada acción tiene su fila en el contrajuego. La emboscada a oscuras se contesta con luz, oído y señuelos |
| 5. Partidas cortas | La niebla no frena el ritmo: el plano se ve siempre y nadie se pierde |
| 6. No violento | Sin cambios |

## Qué medir
| Evento | Pregunta | Señal de alarma |
|---|---|---|
| Segundos por minuto con algún guardia visible para el ladrón | ¿El ladrón vive a ciegas o lo ve todo? | Menos de 5 s o más de 40 s de media |
| Capturas sin que el captor fuera visible 3 s antes | ¿Las emboscadas funcionan sin ser injustas? | Más de la mitad de las capturas |
| % del tiempo con la linterna encendida | ¿La linterna tiene compromiso? | Más del 95 % o menos del 10 % |
| Robos descubiertos al pasar por la sala (D4) | ¿La memoria del botín crea rondas? | Ninguno en 5 partidas |

## Estado
Sin implementar. Hoy el ladrón ve a todos los guardias y el filtro de red solo protege al ladrón. Se implementa en FEAT-020.

## Decisiones (aprobadas por el usuario el 2026-10-24)
1. **► Opción de visión.** Recomendación: **A**, 360° cortada por muros con radio.
2. **► ¿Los guardias se ven siempre entre sí, también a través de muros?** Recomendación: **sí**, como silueta. Son compañeros con radio, y sin eso dos humanos se pierden. Los avisos con coste (pings) siguen siendo de P2.3.
3. **► ¿Un guardia a oscuras y sin linterna solo se ve de cerca (`dark_sight_radius`)?** Recomendación: **sí**. Da a los guardias su propia herramienta de sigilo (pilar 4) y hace que apagar luces tenga precio también para el ladrón.
4. **► Botín y objetos en la niebla: ¿último estado visto o estado real?** Recomendación: **último visto**. Descubrir que falta el cuadro al pasar es buena tensión, y cuesta poco.
5. **► ¿La luz (lámparas y pilotos CCTV) se ve a través de la niebla?** Recomendación: **sí**. La luz se ve de lejos en la realidad y mantiene la contramedida de los pilotos (M4).

## Autorrevisión
- **Completitud**: las siete secciones tienen contenido.
- **Fantasía**: las reglas la entregan.
- **Pilares**: revisados uno a uno, con la tensión del 3 declarada.
- **Asimetría**: todas las acciones tienen contrajuego. La emboscada a oscuras es la nueva herramienta de los guardias y tiene respuestas.
- **Sonido**: refuerza el pilar 2.
- **Extremos**:
  - `thief_view_radius` en 25 m y `dark_sight_radius` en 9 m dan casi la visión de hoy; los rangos lo limitan.
  - `fog_brightness` en 0,2 vuelve el plano difícil de leer, pero queda dentro del rango.
- **Ritmo**: sin esperas añadidas.
- **Tono 1984**: correcto.
- **Medible**: 6 invariantes y 4 eventos.
- **Coherencia**: reutiliza P2.1, M4, M6 y `eye_height`, sin contradicciones. Al aprobarse hay que añadir `vision.md` a «Relacionado» de `stealth.md` e `interaction.md`.
- **Veredicto: APROBABLE.** Las 5 decisiones de arriba son del usuario.
