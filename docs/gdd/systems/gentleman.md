# Ladrón de guante blanco

- **Estado**: propuesto (2026-10-28). **M1-M3 quedan sustituidas por `heist.md`** (lista del coleccionista, carta sin pistas, alerta). Siguen vivas M4 (disfraz) y M5 (gadgets).
- **Origen**: decisión del usuario del 2026-10-28 (`docs/decisions/2026-10-28-tematica-caballero-ladron.md`): el ladrón es un caballero al estilo de Arsène Lupin, en 1984. Recoge también el disfraz de guardia, pedido antes y pendiente de diseño (`README.md`).
- **Relacionado**: `stealth.md` (percepción y ruido), `vision.md` (niebla y filtro de red), `interaction.md` (relojes y CCTV), `pillars.md` (1, 4 y 6).

## Fantasía
- **Ladrón**: «Entro, me llevo lo que he anunciado y me voy sin que nadie me vea. Y que sepan que fui yo». Gana con elegancia, no con fuerza.
- **Guardias**: «Sabemos qué viene a buscar, pero no cuándo ni por dónde. Es más listo que nosotros; tenemos que ser más».

Tono: irónico y elegante, nunca de caricatura. Nada de antifaces ni sacos con el símbolo del dólar: guantes blancos, tarjetas de visita y frases cortas con doble sentido.

## Propuesta
Cinco mecánicas candidatas, ordenadas por lo que aportan a la temática y a la rejugabilidad frente a lo que cuestan. Ninguna cambia lo que ya funciona; todas se suman.

### M1. El golpe anunciado (recomendada para después del playtest)
Antes de empezar, el ladrón elige **qué pieza va a robar**: la Pieza Maestra pasa a ser una entre 3 o 4 candidatas repartidas por el museo. Al empezar, los guardias reciben **la carta del ladrón**: «Esta noche me llevaré *El retrato de la condesa*. Afectuosamente, V.».
- **Regla**: la pieza anunciada es la única que cuenta como «Pieza Maestra». Las otras candidatas son botín normal (o no existen esa partida).
- **Contrajuego**: los guardias saben **qué** proteger, pero no **cuándo** ni **por dónde** llegará. Esto da un motivo para acampar junto a la pieza, que tensa los relojes de ronda, que ya existen precisamente para impedir acampar.
- **Pilares**: refuerza el 3 (información frente a número: ahora los guardias también saben algo) y el 5 (tensión desde el primer segundo).
- **Rejugabilidad**: muy alta. Cada partida cambia la ruta, la sala que vigilar y el reparto de los guardias. Combina con la «semilla del golpe» del roadmap.
- **Coste**: medio (datos del nivel con candidatas, selección en el lobby y la carta en la tarjeta de objetivo).

### M2. La tarjeta de visita (recomendada para después del playtest)
El ladrón puede **dejar su tarjeta** donde estaba lo que roba (E sobre el hueco, 1,5 s).
- **Regla**: cada tarjeta suma **estilo** (M3). Pero la tarjeta es un objeto visible: un guardia que la ve sabe qué falta, desde cuándo más o menos, y deja una marca en el plano para su equipo.
- **Contrajuego**: es riesgo a cambio de recompensa. Dejarla cuesta tiempo y deja una pista; no dejarla no da estilo.
- **Pilares**: 2 (toda acción deja rastro) y 4 (la tarjeta tiene respuesta: la ven y la leen).
- **Coste**: bajo.

### M3. Estilo: cómo se gana con elegancia
Además de ganar o perder, la partida puntúa el **estilo** del ladrón (estrellas, de 1 a 5, en el panel de fin):
- sin ser visto por ningún guardia;
- sin que suene ninguna alarma ni lo grabe ninguna cámara;
- tarjetas dejadas;
- botín por encima de la cuota;
- tiempo.

Los guardias puntúan al revés («la ronda impecable»: relojes sin faltas, captura sin que llegue a la cámara acorazada…).
- **Regla**: no cambia quién gana; da una segunda lectura de la partida y algo que mejorar en la revancha.
- **Rejugabilidad**: alta. Entre amigos, superar el estilo de la ronda anterior es un juego en sí, y prepara la «serie de golpes con rotación de papeles» del roadmap.
- **Coste**: bajo-medio (contadores y panel; los eventos ya existen casi todos).

### M4. El disfraz de guardia (pedido por el usuario)
El ladrón puede ponerse un **uniforme de guardia** (uno por partida, en una taquilla del museo). Disfrazado, **a distancia** se dibuja como un guardia más en los clientes de los guardias.
- **Regla**: el disfraz cae al correr, al robar o al ponerse a menos de `dark_sight` de un guardia (que «le ve la cara»). Las CCTV no se dejan engañar, porque las cintas se miran con calma.
- **Contrajuego**: los guardias saben cuántos son. Un guardia «de más» se delata en los números de las marcas (FEAT-027): el falso no tiene número. También se delata por la radio (el walkie, cuando exista) y por no fichar.
- **Pilares**: tensa el 3 y el filtro de red de `vision.md` (el servidor tiene que enviar al ladrón como guardia, sin revelar quién es). Es la mecánica más cara.
- **Coste**: alto. Necesita su propio `/design` detallado y tocar la red.

### M5. Gadgets de caballero (más adelante)
El maletín del `MASTER_GSD` (estetoscopio, espejo de dentista, monedas y despertador, cuñas, molde de cera) ya es de caballero. Con la temática ganan nombre y presentación: «el estetoscopio del abuelo», «el molde de cera». Entran con `gadgets.md`.

## Qué cambia ya sin tocar reglas
- El lema y el tono de los textos del ladrón. Hecho en el PR #80.
- El panel de fin puede firmar la victoria del ladrón como lo haría Lupin («Con mis respetos. —V.»), y los guardias pueden recibir una frase irónica al perder. Es solo texto.
- La tarjeta de objetivo del ladrón como «carta de invitación», incluso antes de M1.

## Recomendación de orden
1. **Ahora, antes del playtest**: solo textos (lo de arriba). El playtest debe medir el juego tal y como está.
2. **Después del playtest**: M1 (golpe anunciado) + M2 (tarjeta) + M3 (estilo). Juntas convierten cada partida en una historia distinta, son baratas y no tocan el filtro de red.
3. **Luego**: M4 (disfraz), con su propio diseño detallado, y M5 con `gadgets.md`.

## Preguntas abiertas (decide el usuario)
1. **Golpe anunciado (M1)**: ¿la pieza la elige el ladrón en el lobby o la decide la semilla al azar? Recomendación: la elige el ladrón entre 3 candidatas, porque elegir ya es jugar.
2. **Carta a los guardias (M1)**: ¿los guardias saben la pieza desde el principio, o solo cuando el ladrón entra en el museo? Recomendación: desde el principio.
3. **Estilo (M3)**: ¿solo para el ladrón, o también una puntuación de «ronda impecable» para los guardias? Recomendación: los dos bandos.
4. **Disfraz (M4)**: ¿lo diseñamos ya, aunque vaya después de M1-M3?
5. **Textos de Lupin**: ¿firma con inicial («—V.»), con alias o sin firma?
