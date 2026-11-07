# Visión y niebla de guerra

- **Estado**: aprobado por el usuario el 2026-10-24, con las 5 recomendaciones de «Decisiones». Nota del 2026-10-30 (#112): el personaje mira hacia donde anda; el ratón solo cuenta al apuntar la moneda o barrer con la linterna (que solo se enciende mientras se mantiene el clic derecho). La zona visible sigue siendo de 360°.
  - **#163, aprobado por el usuario el 2026-11-05**: niebla en dos grados, uno para el suelo y otro, más suave, para lo que se alza del suelo (R1, R2, R5, «Números», «Invariantes», «Qué medir» y «Decisiones de #163»). Las reglas de antes se citan junto a cada cambio. El usuario aceptó también que la pieza robada, la falsificación, la vitrina y la caja fuerte abiertas se dibujen como se vieron la última vez (en el mismo PR), que la puerta de la garita no tenga memoria y que los compañeros guardias en la niebla no lleven silueta propia de momento.
  - **#186, aprobado por el usuario el 2026-11-07**: la niebla se dibuja como un plano de 1984 en dos tintas azules con el contorno en claro, en lugar de oscura y gris. El borde es corto en el suelo y más ancho en lo alzado. Cambian R1, R2, los casos límite de #163, «Números», la fórmula, «Invariantes», «Qué medir» y se añaden las «Decisiones de #186». Lo acompaña la luz noir (`night_look.tres`) y quitar los focos sobre las piezas, que parecían luz de sigilo sin serlo (`stealth.md` no cambia).
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
- **Fuera de la zona visible está la niebla**: se ve el edificio (el plano se conoce) y nada vivo. Desde #186 (aprobado el 2026-11-07) la niebla es **un plano de 1984**: cada punto se pinta con una tinta azul que va de la sombra a la luz según lo iluminado que estaba, y el contorno de la geometría se dibuja en azul claro (`fog_ink_line`, `fog_line_strength`). Antes era el mismo dibujo, oscurecido y gris. Tiene dos grados (#163, aprobado el 2026-11-05):
  - **El suelo** lleva la tinta oscura (`fog_ink_floor_dark` a `fog_ink_floor_light`). Es la que dice «esto no lo ves»: el borde entre suelo a la vista y suelo en tinta es la frontera de la vista. Su borde es corto (`fog_edge_feather`).
  - **Lo que se alza del suelo** (muros, tabiques, muebles, pedestales, cuadros, puertas) lleva una **tinta más clara** (`fog_ink_raised_dark` a `fog_ink_raised_light`) y un **borde más ancho** (`fog_raised_feather`): se nota que no está a la vista, pero el borde ya no lo barre con un salto brusco al andar. Antes de #186, un oscurecido suave (brillo 0,8, desaturación 0,3).
  - Qué cuenta como alzado lo decide la **altura de cada punto sobre el suelo** (el suelo pisable está a 0 m en todos los niveles): hasta `fog_raised_from` es suelo; desde `fog_raised_to`, alzado; en medio, un paso gradual (suave) entre los dos grados.
  - **Por qué** (playtest del 2026-11-05, #161 y #163): al andar junto a un hueco cercano, el borde de la vista barre muy deprisa las paredes lejanas, y en pantalla parece un parpadeo. En el suelo el barrido se lee como «la vista cambia»; en una pared se lee como un fallo. Con poco contraste en lo alzado deja de notarse.
  - La niebla, en cualquiera de sus grados, **no decide quién se ve**: personajes, botín y objetos se ocultan o se recuerdan por su propio sistema (R2, R3, R4, D4), con la misma zona visible para los dos grados.

### R2. Qué tapa la niebla y qué no
| Cosa | Dentro de tu visión | En la niebla |
|---|---|---|
| Suelos (y lo que no pasa de `fog_raised_from`: alfombras, monedas caídas, sombras en el suelo) | Normal | Tinta oscura del plano (#186; antes, oscuros y grises) |
| Muros, tabiques, muebles fijos, pedestales, cuadros colgados, puertas | Normal | Tinta clara del plano, con su contorno (#186; antes, oscurecido suave). Es el «recuerdo del plano» |
| Personajes del otro bando | Según R3 | **Ocultos** (por la red y R3, no por el shader) |
| Compañeros de bando (guardias entre sí) | Normal | Visibles (D2), en la tinta clara de lo alzado y con su contorno (#186; con #163, oscurecido suave) |
| Botín y caja fuerte (las banderolas de reloj se retiraron con #116, 2026-10-30) | Estado actual | **Último estado visto** (D4), en la tinta clara del plano (#186). Si te robaron el cuadro, lo descubres al volver a mirar |
| Pieza sobre su pedestal, vitrina o caja fuerte abierta | Estado actual | **Último estado visto** (D4, aclarado en #163): un pedestal que se vacía en la niebla se sigue dibujando con su pieza, y una pieza cambiada por su falsificación se sigue dibujando como la vieron, hasta que vuelven a mirar. Ver R5 |
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
| Guardia visto por una cámara (FEAT-042) | El ladrón, sentado ante los monitores | Si la cámara que tiene en pantalla lo ve con luz (2026-11-04, #118; antes, cualquiera): marcado «solo CCTV», se dibuja solo en la imagen |
| Moneda en vuelo (FEAT-038) | El ladrón siempre; cada guardia despierto | Al lanzarse (no fiable), si la salida o la caída están en su zona visible (`CoinFlightPresenter.view_for`). Quien no ve la salida recibe solo el tramo desde donde entra en su vista: sabe de qué lado viene, no desde dónde se lanzó. El ruido va aparte, al caer |
| Botín, lámparas, caja fuerte (sin relojes desde #116) | Todos | Como hoy. La memoria de R2 la aplica el cliente al dibujar (D4). Sin filtro en el servidor en el PoC: hacer trampa con eso vale poco |

- **Coste**: para cada guardia, entre 1 y 3 rayos ladrón-guardia por tick de snapshot (20 Hz). El polígono que se dibuja lo calcula cada cliente para su propio jugador: unos `fog_rays` rayos en cada fotograma en que se mueve (#161; antes a 30 Hz).

### R5. Casos límite
- **Esquinas y marcos de puerta**: la vista pasa por el hueco. Un guardia pegado a la pared de al lado del marco queda en la niebla.
- **Muros bajos de vista frente a colisión alta**: la línea de visión usa la colisión (3,2 m), no la altura visible (1,2 m). Ver por encima de un muro bajo en pantalla no revela lo que hay detrás.
- **Guardia sentado ante los monitores**:
  - su zona visible es la de su cuerpo;
  - las imágenes CCTV no llevan niebla, porque son la vista de la cámara (M6);
  - los pilotos siguen visibles en la niebla para el ladrón (M4); desde #118 solo hay uno encendido, el de la cámara en pantalla.
- **Ladrón en una sala a oscuras**: él ve su entorno con normalidad. Apagar la luz le esconde de los guardias, pero también le impide ver a un guardia a oscuras más allá de `dark_sight_radius`. Es un compromiso a propósito.
- **Fin de la partida**: la niebla se retira para todos, para que vean dónde estaba cada uno.
- **Desconexión**: el actor que se queda quieto se trata como cualquier otro.
- **Sin red** (un jugador o depuración): la niebla se calcula igual, desde el jugador local.
- **Los dos grados de la niebla** (#163, aprobado el 2026-11-05):
  - **Alfombras, suelos de moqueta y lo que va pegado al suelo** (monedas caídas, manchas, sombras): son suelo, porque no pasan de `fog_raised_from` (0,08 m). Llevan la niebla del suelo.
  - **Zócalos** (0,16 m de alto): caen en el paso gradual y quedan entre los dos grados. Hace de sombra de contacto al pie del muro y no se nota como franja. El pie de cada muro, de 0 a 0,08 m, lleva la niebla del suelo, con la misma lectura.
  - **Mesas, bancos, mostradores**: el tablero y los laterales son alzados; el suelo de debajo (y su sombra) es suelo. Lo que está encima de la mesa también es alzado.
  - **Ladrón y guardias**: el shader los trataría como alzados, pero no decide si se ven. Un guardia en la niebla del ladrón no se dibuja (R3 y la red); el ladrón en la niebla de un guardia tampoco (percepción). Lo único que cambia: los compañeros guardias en la niebla (D2) se ven en la tinta clara de lo alzado, con su contorno (#186).
  - **Pieza sobre su pedestal (botín)**: la pieza y el pedestal son alzados, así que en la niebla se ven casi como a la vista. Por eso **el estado de la pieza tiene que ser el último visto** (D4), no el real: si no, un guardia vería desde dos salas, a través de los muros bajos, cómo desaparece una pieza en el momento del robo. Esa fuga ya existe hoy con la niebla oscura (las piezas de los pedestales no están en la memoria de la niebla: solo el botín suelto lo está), y #163 la haría muy legible. Arreglarla es requisito de #163.
  - **Pedestal vacío como rastro**: con la memoria, un pedestal que se vació en la niebla se sigue dibujando con su pieza hasta que alguien vuelve a mirarlo; entonces la pieza desaparece y el rastro se descubre (heist R6). Un pedestal que ya estaba vacío la última vez que se vio se recuerda vacío: desde lejos se distingue, y eso es correcto, porque ya se vio.
  - **Falsificación** (cambiazo, heist R9b): con la memoria, una pieza cambiada en la niebla se recuerda como el original hasta que se vuelve a ver. Desde #186 la tinta del plano borra el color, así que desde la niebla una copia con el fallo de color no se distingue del original: hay que tenerla a la vista para notarlo, y examinarla sigue pidiendo ir hasta ella (E). Con #163 se distinguía algo desde lejos.
  - **Vitrina o caja fuerte abierta, hoja de una puerta**: lo mismo que el pedestal. La vitrina y la caja fuerte siguen el último estado visto. La hoja de la puerta de la garita no: se ve abrirse en la niebla, como hoy, porque al abrirse ya cruje (pilar 2) y se cierra sola.
  - **Cuadros colgados y decorado**: alzados, en la tinta clara del plano (#186). No tienen estado de juego. Las piezas del encargo que son cuadros van sobre pedestal y siguen la regla de las piezas.
  - **Luces** (D5): las paredes iluminadas de una sala lejana se leen mejor que antes, así que se nota más si una sala tiene la luz encendida o apagada. Es la regla D5 de siempre («apagar las luces» ya deja «la sala a oscuras en la niebla» en el contrajuego), solo más legible.
  - **Suelos que no estén a 0 m** (un escenario, un muelle elevado): se leerían como alzados. Ningún nivel actual los tiene; un nivel que los añada tendrá que dar la altura de su suelo.

## Números (nuevo recurso `data/balance/vision_rules.tres`)
| Mando | Campo | Tipo | Rango | Valor inicial y por qué |
|---|---|---|---|---|
| Radio de visión del ladrón | `thief_view_radius` | sensación | 12-25 m | 18. Cubre una galería entera y lo que asoma por su puerta. Mayor que el de los guardias (pilar 3, visión amplia) |
| Radio de visión del guardia | `guard_view_radius` | sensación | 9-15 m | 12. Igual que `lit_sight_range`: el guardia ve el entorno hasta donde podría ver al ladrón iluminado |
| Vista a oscuras del ladrón | `dark_sight_radius` | ritmo | 3-9 m | 6. Un guardia quieto a oscuras se descubre a dos pasos de una puerta; más lejos solo se le oye (pasos ×1,5) |
| Tinta del suelo en la niebla | `fog_ink_floor_dark`, `fog_ink_floor_light` | sensación | azul tinta; la clara, nunca más clara que la de lo alzado | (0,02, 0,035, 0,09) en sombra y (0,07, 0,13, 0,27) con luz (#186). Casi negro azulado: el suelo en niebla dice «no lo ves» |
| Tinta de lo alzado en la niebla | `fog_ink_raised_dark`, `fog_ink_raised_light` | sensación | azul tinta, más clara que la del suelo | (0,06, 0,1, 0,22) y (0,2, 0,32, 0,58) (#186). Las paredes se leen como plano sin parecer «a la vista». Sustituye al brillo 0,8 y la desaturación 0,3 de #163 |
| Contorno del plano | `fog_ink_line`, `fog_line_strength` | sensación | fuerza 0-0,5 | azul claro (0,55, 0,75, 1,0) con fuerza 0,2 (#186). Con 0,4 (prototipo) las líneas, de un píxel, «reptaban» al mover la cámara; con 0 las paredes se funden con el suelo y el plano no se lee |
| Sin contorno junto al jugador | `fog_line_clear_near` | técnico | 1-3 m | 2 (#186). El tramado de rayos X del personaje deja huecos que el contorno dibujaría como puntitos |
| Altura donde empieza lo alzado | `fog_raised_from` | sensación | 0,02-0,15 m | 0,08 (#163). Por encima de lo pegado al suelo (alfombras, monedas, el grosor de las baldosas) y por debajo del zócalo (0,16 m) |
| Altura donde lo alzado es completo | `fog_raised_to` | sensación | 0,15-0,5 m, mayor que `fog_raised_from` | 0,2 (#163). Justo sobre el zócalo, para que el pie de cada muro haga de sombra de contacto y no de franja; un banco (0,45 m) ya es alzado entero |
| Borde suave del suelo | `fog_edge_feather` | sensación | 0,3-4,0 m | 0,4 (#186; antes 3,0 por #161 y antes 1,0). Corto: la frontera de la vista se ve nítida en el suelo |
| Borde suave de lo alzado | `fog_raised_feather` | sensación | 1,0-4,0 m, nunca menor que `fog_edge_feather` | 1,5 (#186). Más ancho en las paredes para que el borde no las barra con un salto al andar (#161, #163) |
| Fundido del borde | `fog_fade_time` | sensación | 0-0,5 s | 0,3 (#161). Al moverse, el borde se funde hacia la zona nueva en vez de saltar; lo oculto en la niebla sigue ese mismo borde |
| Rendijas de un rayo | `fog_drop_slivers` | sensación | sí/no | sí (#161). Una cuña de un solo rayo de ancho (un hueco lejano) no cuenta como visible |
| Rayos del polígono | `fog_rays` | técnico | 8-256 | 256. Bordes limpios a 30 Hz: unos 0,6 ms por recálculo en `museum_v2`, y solo se recalcula si el jugador se mueve |
| Luz que atraviesa la niebla | `fog_light_keep` | técnico | 0,7-1,5 | 0,9. Canal más brillante de un píxel a partir del cual se ve tal cual, sin tinta: pilotos y bombillas se ven en la niebla (D5); el suelo iluminado, no |

`eye_height` se reutiliza de `perception_guard.tres` (1,6 m), sin número nuevo.

**Fórmula del plano** (#163, con las tintas de #186). Para cada punto de pantalla en la niebla:

`alzado = suave(fog_raised_from, fog_raised_to, altura)`
`tono = suave(0, 0,5, luz del punto)`
`tinta = mezcla(mezcla(suelo_oscura, suelo_clara, tono), mezcla(alzado_oscura, alzado_clara, tono), alzado)`
`color = mezcla(tinta, fog_ink_line, contorno · fog_line_strength)`
`borde = mezcla(fog_edge_feather, fog_raised_feather, alzado)`

| Variable | Qué es |
|---|---|
| `altura` | Altura del punto sobre el suelo, en m (su Y de mundo; el suelo está a 0) |
| `luz del punto` | Luminancia del píxel tal como se dibujó, de 0 a 1 |
| `contorno` | 0 a 1: salto de profundidad o de orientación con los píxeles vecinos, suavizado a unos 3 px; 0 a menos de `fog_line_clear_near` m del jugador |
| `suave(a, b, x)` | 0 si x ≤ a, 1 si x ≥ b, y una curva en S en medio |
| `mezcla(p, q, t)` | p + (q − p) · t |
| `alzado` | 0 (suelo) a 1 (alzado) |

- **Salida**: un color de la tinta del suelo o de la de lo alzado, con el contorno encima. El fundido (`fog_fade_time`) y la luz que atraviesa (`fog_light_keep`) se aplican igual.
- **Ejemplo**: una pared a 1 m con luz 0,25 da tono 0,5, así que una tinta a medio camino entre (0,06, 0,1, 0,22) y (0,2, 0,32, 0,58); su borde con la zona visible mide 1,5 m. El suelo junto a ella, con la misma luz, da la tinta del suelo a medio camino y un borde de 0,4 m.

## Invariantes medibles
1. Un muro del grupo `walls` entre ladrón y guardia oculta al guardia en el cliente del ladrón (test con el nivel pequeño).
2. El cliente del ladrón nunca recibe el estado completo de un guardia que no ve; solo `beam_only` si lleva la linterna encendida (partida en red con `--net-log`).
3. Un guardia a oscuras y con la linterna apagada es visible para el ladrón a `dark_sight_radius` − 0,01 m e invisible a + 0,01 m, con línea de visión libre.
4. Los guardias se reciben siempre entre sí.
5. Al acabar la partida no queda niebla.
6. Ningún mueble ni cobertura corta la zona visible; solo los muros y tabiques.
7. (#163, #186) En la niebla, un punto del suelo a 0 m se dibuja con la tinta del suelo y uno a `fog_raised_to` m o más, con la de lo alzado, que es más clara; los dos usan la misma zona visible (`is_point_visible` no cambia).
8. (#163) Una pieza robada en un pedestal fuera de la zona visible de un guardia sigue dibujándose en su cliente hasta que el pedestal entra en su zona visible; al entrar, desaparece en ese momento.

## Contrajuego
| Acción | Quién | Qué percibe el otro | Respuesta |
|---|---|---|---|
| Avanzar pegado a los muros, fuera de las líneas de visión | ladrón | Nada si es silencioso; los pasos si corre | Escuchar; patrullar cruzando las puertas en vez de rodear las salas |
| Esperar a oscuras con la linterna apagada (emboscada) | guardia | Nada hasta `dark_sight_radius`; sus pasos al moverse | Escuchar antes de cruzar; encender la luz de la sala (el interruptor suena); lanzar un señuelo |
| Llevar la linterna encendida | guardia | El haz, a través de los muros | Apagarla en las zonas donde se espera al ladrón, a cambio de ver menos |
| Apagar las luces de una zona | ladrón | El clic del interruptor y la sala a oscuras en la niebla | Ir con linterna; la oscuridad también ciega al ladrón más allá de 6 m |
| Robar algo lejos de los guardias | ladrón | Nada hasta que vuelven a mirar (D4) | Patrullas que pasan por las salas del botín; la cámara CCTV de la antesala |

## Pilares
| Pilar | Cómo lo cumple |
|---|---|
| 1. 1984 | Sin visión nocturna ni radares: se ve lo que ve un ojo, con luz o de cerca |
| 2. Sonido | Fuera de la vista, el sonido y los chevrons son la única pista: el ruido vale más que nunca |
| 3. Información frente a número | El ladrón ve más lejos (18 frente a 12 m), ve todos los haces y oye más. Los guardias se ven siempre entre sí. Tensión declarada: el ladrón pierde la visión total de hoy, que era un error y no una regla |
| 4. Respuesta | Cada acción tiene su fila en el contrajuego. La emboscada a oscuras se contesta con luz, oído y señuelos |
| 5. Partidas cortas | La niebla no frena el ritmo: el plano se ve siempre y nadie se pierde |
| #163 (aprobado) | Pilar 3: no cambia lo que sabe cada bando, porque personas y estado del botín no dependen del grado de la niebla, siempre que el estado de las piezas siga la memoria (R5). Legibilidad del sigilo: el suelo sigue marcando la frontera de la vista. Tensión declarada: las salas lejanas parecen más «a la vista» y un jugador puede confiarse; se mide abajo. Pilar 5: el plano se lee aún mejor |
| 6. No violento | Sin cambios |

## Qué medir
| Evento | Pregunta | Señal de alarma |
|---|---|---|
| Segundos por minuto con algún guardia visible para el ladrón | ¿El ladrón vive a ciegas o lo ve todo? | Menos de 5 s o más de 40 s de media |
| Capturas sin que el captor fuera visible 3 s antes | ¿Las emboscadas funcionan sin ser injustas? | Más de la mitad de las capturas |
| % del tiempo con la linterna encendida | ¿La linterna tiene compromiso? | Más del 95 % o menos del 10 % |
| Robos descubiertos al pasar por la sala (D4) | ¿La memoria del botín crea rondas? | Ninguno en 5 partidas |
| (#163) Preguntar tras jugar: «¿has visto parpadear las paredes?» | ¿El borde ancho en lo alzado quita el parpadeo? | Algún «sí» con `fog_raised_feather` en 1,5 |
| (#186) Preguntar tras jugar: «¿las líneas del plano tiemblan al moverte?» | ¿El contorno es estable? | Algún «sí» con `fog_line_strength` en 0,2 |
| (#163) Preguntar tras jugar: «¿sabías qué parte del mapa estabas viendo?» | ¿Se sigue leyendo «no visto» en lo alzado? | Algún «no» o dudas sobre una sala lejana |
| (#163) Capturas sin que el captor fuera visible 3 s antes, antes y después de #163 | ¿El ladrón se confía en las salas que parecen a la vista? | Sube más de un 20 % respecto a las partidas con la niebla de un grado |
| (#163) Segundos entre un robo en la niebla de un guardia y su primera reacción (ir hacia esa sala o poner una marca) sin haberlo visto ni oído | ¿Hay fuga del estado de las piezas? | Alguna reacción en menos de 5 s sin ruido ni vista |

## Estado
Implementado en FEAT-020 (2026-10-28). Simplificación del PoC: la vista ladrón-guardia usa un solo rayo de ojos a ojos (no 1-3), así que un guardia con la cabeza tapada por un marco de puerta queda oculto aunque se le vea el cuerpo. Los compañeros guardias en la niebla solo se oscurecen, sin silueta propia.

## Decisiones (aprobadas por el usuario el 2026-10-24)
1. **► Opción de visión.** Recomendación: **A**, 360° cortada por muros con radio.
2. **► ¿Los guardias se ven siempre entre sí, también a través de muros?** Recomendación: **sí**, como silueta. Son compañeros con radio, y sin eso dos humanos se pierden. Los avisos con coste (pings) siguen siendo de P2.3.
3. **► ¿Un guardia a oscuras y sin linterna solo se ve de cerca (`dark_sight_radius`)?** Recomendación: **sí**. Da a los guardias su propia herramienta de sigilo (pilar 4) y hace que apagar luces tenga precio también para el ladrón.
4. **► Botín y objetos en la niebla: ¿último estado visto o estado real?** Recomendación: **último visto**. Descubrir que falta el cuadro al pasar es buena tensión, y cuesta poco.
5. **► ¿La luz (lámparas y pilotos CCTV) se ve a través de la niebla?** Recomendación: **sí**. La luz se ve de lejos en la realidad y mantiene la contramedida de los pilotos (M4).

## Decisiones de #163 (aprobadas por el usuario el 2026-11-05)
1. **► ¿Se aprueban los dos grados de la niebla de R1 (suelo 0,5/0,7; lo alzado 0,8/0,3; paso entre 0,08 y 0,2 m)?** Recomendación: **sí**, es lo que el usuario vio y eligió en el prototipo. **Usuario: sí.**
2. **► ¿El estado de las piezas (pedestal vacío, falsificación, vitrina y caja fuerte abiertas) sigue el último visto, como dice D4, y se arregla en #163?** Recomendación: **sí, en el mismo PR y antes de integrar**. Hoy esas piezas no tienen memoria (solo el botín suelto la tiene) y un guardia ve vaciarse un pedestal en la niebla; con el oscurecido suave se vería claro desde lejos. **Usuario: sí.**
3. **► ¿La hoja de la puerta de la garita también sigue el último visto?** Recomendación: **no**. Al abrirse cruje y se cierra sola: la información ya es pública por el sonido (pilar 2). **Usuario: no, sin memoria.**
4. **► ¿Los compañeros guardias en la niebla, más claros con #163, necesitan su silueta propia (D2) para no confundirse con «a la vista»?** Recomendación: **no por ahora**. Medirlo en el playtest con la pregunta de «Qué medir». **Usuario: no por ahora.**

## Decisiones de #186 (aprobadas por el usuario el 2026-11-07)
1. **► ¿Qué dice la niebla?** Recomendación: **un plano en azul tinta**, sin gris. Distingue al instante lo que ves de lo que no y cuenta R1 («el edificio se conoce») sin explicarlo. **Usuario: sí**, elegido sobre el prototipo frente a «oscuridad» y al estilo de #163.
2. **► ¿Paredes y muebles con una tinta más clara que el suelo?** Recomendación: **sí**, para conservar lo que resolvió #163. **Usuario: sí.**
3. **► ¿Las luces siguen atravesando la niebla (D5)?** Recomendación: **sí**. **Usuario: sí.**
4. **► ¿Borde corto (0,4 m), sin línea de neón?** Recomendación: **sí**, y más ancho en lo alzado. **Usuario: sí.**
5. **► ¿Iluminación noir: menos luz ambiente y solo da luz lo que cuenta para el sigilo?** Recomendación: **sí**. Se quitan los focos sobre las piezas y los monitores de la garita quedan muy tenues. **Usuario: sí.**

## Autorrevisión
- **Completitud**: las siete secciones tienen contenido.
- **Fantasía**: las reglas la entregan.
- **Pilares**: revisados uno a uno, con la tensión del 3 declarada.
- **Asimetría**: todas las acciones tienen contrajuego. La emboscada a oscuras es la nueva herramienta de los guardias y tiene respuestas.
- **Sonido**: refuerza el pilar 2.
- **Extremos**:
  - `thief_view_radius` en 25 m y `dark_sight_radius` en 9 m dan casi la visión de hoy; los rangos lo limitan.
  - `fog_line_strength` en 0 hace que las paredes en niebla se fundan con el suelo; el rango llega a 0, pero el valor útil empieza en 0,15.
- **Ritmo**: sin esperas añadidas.
- **Tono 1984**: correcto.
- **Medible**: 8 invariantes y 9 eventos.
- **Coherencia**: reutiliza P2.1, M4, M6 y `eye_height`, sin contradicciones. Al aprobarse hay que añadir `vision.md` a «Relacionado» de `stealth.md` e `interaction.md`.
- **Veredicto: APROBABLE.** Las 5 decisiones de arriba son del usuario.
