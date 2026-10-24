# Nivel: Museo Velvet '84, versión 2

- **Estado**: aprobado (2026-10-24). El usuario aprueba todas las recomendaciones: esqueleto A "dos alas", 48 × 36 m y decisiones 3–8 (3 y 5 pasan por `/design`).
- **Origen**: petición del usuario del 2026-10-24: tirar `scenes/maps/museum_velvet_84.tscn` ("feo", 30 × 19 m, 8 salas) y tener un museo grande y bien diseñado, con pasillos, varias salas y una garita de guardia. Meta del PoC (`docs/decisions/2026-10-23-roadmap-poc.md`): 3 personas juegan 5 partidas seguidas, 1 ladrón contra 2 guardias humanos en LAN, y quieren la sexta.
- **Relacionado**: `docs/gdd/pillars.md`; `docs/gdd/systems/stealth.md` (partes 1 y 2, P2.4); sistemas en código: `src/systems/lighting/`, `safe_box_3d.gd`, `time_clock_3d.gd`, `escape_car_3d.gd`, `security_camera_3d.gd`, `cctv_monitor_3d.gd`, `src/entities/loot_item_3d.gd`, `core/game_manager.gd`.
- **Fuente de verdad**: las tablas de este documento, hasta que exista `data/levels/museum_v2.tres` (no existe formato de nivel por datos: `FloorplanBlueprint` describe salas y puertas en código y `MuseumLevelBuilder3D` tiene los muros y el mobiliario escritos a mano). Ver "Siguiente paso".

## 1. Concepto y fantasía
Medianoche de noviembre de 1984 en el Museo Velvet, un palacete de mármol con ala de servicio de linóleo y fluorescentes. Las arañas de la rotonda siguen encendidas para las cámaras, el resto es penumbra y farolas de sodio filtrándose por las ventanas.
**Ladrón**: "Conozco el edificio mejor que ellos: sé por dónde cruje el suelo y qué luz apagar". **Guardias**: "Dos hombres, cuatro relojes y tres monitores; no podemos estar en todas partes, y él lo sabe".

## 2. Dimensiones y escala

### Coordenadas
- Metros. Origen en la esquina noroeste del edificio. **x** crece hacia el este y **z** hacia el sur (igual que Godot, donde el norte es −Z). En Godot: `posición = (x − 24, y, z − 18)`, con el centro del edificio en el origen.
- Edificio: x 0-48, z 0-36 (**48 × 36 m, 1.728 m²**). Callejón exterior: x −4 a 52, z 36-44 (56 × 8 m).
- Muros en múltiplos de 2 m, grosor 0,3 m, colisión de 3,2 m de alto (la de `MuseumLevelBuilder3D`). Puertas de 1,2 × 2,2 m; arcos de 2,4 × 2,6 m.

### Por qué este tamaño
- **Lo que cabe en pantalla**: con la ortográfica de tamaño 14 a 16:9, la vista cubre unos 25 m de ancho por 24 m de suelo en profundidad (14 / sen 35,26°), unos 600 m². El edificio ocupa unas 2 × 1,5 pantallas: ninguna sala es mayor que una pantalla (la mayor, 16 × 14 m), así que cada sala se lee entera con sus puertas, pero nadie ve el mapa completo.
- **Densidad de guardias**: 2 guardias para unos 1.300 m² transitables. Cada uno controla de verdad un haz de ~45 m² (`perception_guard.tres` → `flashlight_range`, `flashlight_half_angle_deg`) y, en salas iluminadas, hasta `lit_sight_range`. Con 4 relojes en las esquinas, los guardias cruzan el centro varias veces por ciclo: el ladrón no puede contar con no encontrárselos, pero tampoco hay un guardia en cada sala.
- **Travesía**: cruzar el edificio en diagonal son ~60 m. Andando, el ladrón tarda unos 12 s (`movement_thief.tres` → `walk_speed`) y el guardia 14 s (`movement_guard.tres`). Lo que llena los 10 minutos no es la distancia, sino esperar, escuchar y dar rodeos.
- **Comparación**: el museo actual tiene 30 × 19 m de edificio (unos 570 m²), y en él un guardia ve media planta desde la puerta. Este es unas 3 veces más grande.

### Velocidades de referencia (derivadas de `movement_*.tres`; sirven para todos los tiempos del documento)
| Quién y modo | m/s | Con botín pesado (×0,8, `HEAVY_LOOT_SPEED_MULTIPLIER`, constante de código) |
|---|---|---|
| Ladrón andando / en sigilo / agachado / corriendo | 5,0 / 2,4 / 2,0 / 7,5 | 4,0 / 1,92 / 1,6 / 6,0 |
| Guardia andando / en sigilo / corriendo | 4,2 / 2,0 / 6,3 | — |

Con la Pieza Maestra en brazos, el ladrón corre más despacio que un guardia (6,0 frente a 6,3 m/s): una vez visto, tiene que romper la línea de visión, no ganar la carrera.

## 3. Esqueleto elegido y alternativas
La propuesta detallada es la **A**. Las otras dos se quedan aquí por si el usuario prefiere otra (decisión abierta 1).

| | Esqueleto | Compromisos | Pilares |
|---|---|---|---|
| **A (recomendada)** | **Dos alas**: lo público al oeste y en el centro (galerías, rotonda, cámara) y lo de servicio al este (garita, pasillo de servicio, muelle). La cámara acorazada queda al norte, en el centro, y el coche al suroeste. | Tres rutas bien diferenciadas por su carácter (pública, galerías, servicio). La garita queda lejos de la cámara, así que acampar en ella no protege la Pieza Maestra. Riesgo: la antesala es un cuello de botella compartido por dos rutas. | Refuerza 3 y 5; tensa el 4 en la antesala (se resuelve con la luz, §7). |
| B | **Anillo**: un pasillo perimetral alrededor de un bloque central de galerías, con la cámara en el centro. | Persecuciones en bucle muy legibles, pero el anillo es una autopista para los guardias y todas las salas se parecen. | Refuerza 2; tensa 3: el guardia que recorre el anillo lo ve todo. |
| C | **Lineal en H**: dos crujías norte-sur unidas por la rotonda. | Muy fácil de leer en isométrica, pero solo hay dos rutas reales y es fácil de acampar en el travesaño. | Tensa 4 y 5. |

## 4. Salas
Suelos: `alfombra` = `data/balance/surface_carpet.tres`, `mármol` = `surface_marble.tres`, `parqué` = `surface_wood_parquet.tres`, `linóleo` = **nuevo** `surface_linoleum.tres` (propuesto, ×1,0, rango 0,9-1,1; decisión abierta 6). En el exterior no hay dato de superficie: ×1 por la regla de `stealth.md`.

**Aviso sobre los multiplicadores del encargo**: el encargo daba parqué ~1,0-1,2 y mármol 1,4-1,6. Los `.tres` actuales (alfombra 0,2, mármol 1,2, parqué 1,5) y la regla aprobada de `stealth.md` ("alfombra < 1 ≤ mármol ≤ parqué": el parqué cruje más que el eco del mármol) dicen lo contrario. Este documento sigue los `.tres` y `stealth.md`.

Radio del paso, como referencia (fórmula de `stealth.md`):
| Suelo | Ladrón en sigilo o agachado | Ladrón andando | Guardia andando (el ladrón lo oye a ×1,5) |
|---|---|---|---|
| alfombra | 0,5 m (`min_radius`) | 0,7 m | 0,84 m (1,26 m) |
| linóleo | 1,05 m | 3,5 m | 4,2 m (6,3 m) |
| mármol | 1,26 m | 4,2 m | 5,04 m (7,56 m) |
| parqué | 1,58 m | 5,25 m | 6,3 m (9,45 m) |

La alfombra protege a los dos bandos: un guardia en sigilo sobre alfombra es casi inaudible. Es el sitio de las emboscadas, y el ladrón solo lo compensa viendo la linterna.

### Tabla de salas
Rectángulo = (x, z, ancho, fondo). Luz: tipo × número, circuito y estado inicial; los radios están en `data/balance/lamp_*.tres`. "Cobertura baja" significa al menos 1,0 m de opaco (oculta los `crouch_points`, invariante 9 de `stealth.md`); "dura" significa de suelo a techo.

| Id | Sala | Rect. (m) | Función de juego | Suelo | Luz | Botín | Coberturas y bolsillos de sombra |
|---|---|---|---|---|---|---|---|
| VES | Vestíbulo | (16, 26, 16, 10) | Entrada principal; inicio de la ruta rápida; la cámara CAM-1 vigila la puerta de personal | mármol | techo × 2, C1, encendido | L5 caja registradora | Mostrador de taquilla de 3 × 0,8 × 1,1 m, guardarropa (barra de 1,8 m) y 2 columnas. Sombra en las esquinas NO y SO, fuera del radio de las lámparas |
| ROT | Gran Galería de Escultura (rotonda) | (16, 14, 16, 12) | Nudo central: une vestíbulo, galerías, antesala y servicio. Es la zona de más tensión del mapa | parqué de espiga | techo × 3 (araña), C2, encendido | L4 pitillera esmaltada (vitrina central) | 4 columnas de 0,6 m (duras) en (19,17), (29,17), (19,23) y (29,23); 4 estatuas sobre pedestal de 1,2 m; 2 bancos (no cubren). Sombra en las franjas z 14-16 y z 24-26 |
| ANTE | Antesala de la Cámara | (16, 10, 16, 4) | Pasillo de 4 m ante la puerta acorazada. Cuello de botella de las rutas A y B | alfombra roja | techo × 1, C3, encendido | — | 2 bancos y 2 pedestales con jarrón (1,0 m). El extremo oeste (x 16-22) queda fuera de CAM-3 y en sombra: ahí están los interruptores de C3 y C4 |
| VLT | Cámara de la Pieza Maestra | (16, 0, 16, 10) | Objetivo. Dos puertas: la acorazada (sur) y la de servicio (este) | mármol | techo × 2 (foco sobre el pedestal y otra junto a la puerta este), C4, encendido. **El interruptor de C4 está fuera, en la antesala** | **M** La Dama de Terciopelo | Pedestal central de 1,2 × 1,2 × 1,1 m con cordón; 4 columnas (duras) en (19,3), (29,3), (19,8) y (29,8); 2 vitrinas bajas vacías. Con C4 apagado, la sala entera es sombra |
| ANT | Ala de Antigüedades | (0, 0, 16, 14) | Botín ligero abundante y el pesado más lejano. Reloj R2 | parqué | techo × 2, C5, encendido | L1, L2, L3; H1 ánfora | Sarcófago de 2,2 × 0,8 × 1,0 m, 6 vitrinas bajas en dos filas y 2 estatuas (duras). Sombra en la franja norte y en la esquina SO |
| GW | Galería de Retratos | (0, 14, 16, 10) | Ruta sigilosa. El tabique central forma un bucle para despistar en una persecución | alfombra | techo × 2, C6, **apagado** ("sala cerrada por montaje") | H2 Retrato del Duque | **Tabique expositor** exento de 10 × 0,3 × 2,4 m, de x 3 a x 13 en z 19 (duro), que deja dos carriles de 4,7 m; 2 bancos; caballetes y cajas de montaje (1,0-1,2 m) |
| GSW | Galería de Pintura Moderna | (0, 24, 16, 12) | Entrada por la salida de emergencia. Reloj R4 | mármol | techo × 2, C7, encendido; interruptor junto a la salida de emergencia | L8 reloj de bolsillo | 2 tabiques exentos de 4 × 0,3 × 2,4 m (duros) y una vitrina baja. Sombra a lo largo del muro este |
| ARC | Archivo y Almacén de Obras | (32, 0, 8, 14) | Lado de servicio de la cámara (puerta este) | linóleo | techo × 1, C13, apagado | H3 busto de bronce (en caja) | Estanterías de 2,0 × 0,6 × 2,2 m en 3 filas norte-sur (duras), cajas de embalaje de 1,0-1,2 m. Casi todo es sombra |
| OFF | Despacho del Conservador | (40, 0, 8, 14) | Caja fuerte. Reloj R3 | alfombra | flexo desenroscable (encendido, cadenilla propia) y techo × 1 (C10, apagado) | **S** caja fuerte; L6 cajón | Escritorio de 1,6 × 0,8 × 0,75 m (no cubre al agachado), 2 archivadores de 1,3 m, butaca, planta de 1,6 m y estantería. Sombra lejos del flexo |
| PS | Pasillo de Servicio | (32, 14, 2, 16) | Ruta de servicio y vía rápida de los guardias entre la garita y la rotonda | linóleo | techo × 2, C8, encendido; un interruptor en cada extremo | — | Ninguna dentro. Ventana V1 de la garita (vidrio) en x 34, z 27-29 |
| TAL | Taller de Restauración | (34, 14, 6, 10) | Atajo entre el pasillo y mantenimiento; botín ligero cerca del lado de los guardias | parqué | flexo sobre la mesa de trabajo (encendido) | L7 miniatura | Mesa de restauración de 2,0 × 1,0 × 0,9 m (casi cubre), caballete y armario de disolventes de 1,8 m |
| MNT | Mantenimiento y Generadores | (40, 14, 8, 10) | **Cuadro de alumbrado**: interruptores duplicados de C1, C2, C5 y C7 (salas públicas). Ruta por interacción | linóleo | techo × 1, C12, apagado | — | Generador de 2,0 × 1,0 × 1,4 m (cubre), caldera de 1,2 × 1,2 × 2,0 m (dura) y tuberías |
| GAR | Garita de Seguridad | (34, 24, 8, 6) | Aparición de los guardias, 3 monitores CCTV y reloj R1 | linóleo | techo × 1, C9, encendido; brillo de los monitores | — | Mesa de monitores contra el muro este; taquilla de llaves; silla. Ventana V1 al pasillo |
| VEST | Vestuario de Personal | (42, 24, 6, 6) | Une la garita con mantenimiento por detrás | linóleo | techo × 1, C15, apagado | — | Dos filas de 4 taquillas de 1,6 × 0,5 × 1,9 m (duras) y un banco |
| DOCK | Muelle de Carga | (32, 30, 16, 6) | Tercera salida al callejón, junto a la garita | linóleo | techo industrial × 1, C14, encendido | — | Palés con cajas (1,2 m), carretilla y contenedor de 1,8 × 1,0 × 1,3 m |
| ALY | Callejón | (−4, 36, 56, 8) | Coche de huida y aparición del ladrón | sin dato (×1) | farola × 3 (`lamp_street`, fija) en (12, 37,5), (24, 37,5) y (44, 37,5) | — | 3 contenedores de basura (1,3 m) en (16,42), (32,42) y (40,40); cajas. La franja z 41-44 queda a más de `lit_radius` de las farolas |

## 5. Puertas, ventanas y conexiones

### Puertas
En el PoC no hay sistema de puertas: todas son vanos abiertos. Las columnas "Cerradura" y "Cuña" son reservas para cuando exista `interaction.md`.

| Id | Une | Posición (x, z) | Ancho | Cerradura (reserva) | Cuña (reserva) |
|---|---|---|---|---|---|
| P01 | ALY–VES (puerta principal) | (24, 36) | 2,4 doble | sí, ganzúa | no |
| P02 | ALY–GSW (salida de emergencia) | (6, 36) | 1,2 | barra antipánico: desde dentro siempre abre | sí |
| P03 | ALY–DOCK (persiana) | (44, 36) | 3,0 | sí, ruidosa | no |
| P04 | VES–ROT (arco) | (24, 26) | 2,4 | no | no |
| P05 | VES–GSW | (16, 32) | 1,2 | no | sí |
| P06 | VES–PS (personal) | (32, 28) | 1,2 | sí | sí |
| P07 | ROT–GW (arco) | (16, 19) | 2,4 | no | no |
| P08 | ROT–ANTE (arco) | (24, 14) | 2,4 | no | no |
| P09 | ROT–PS (servicio) | (32, 18) | 1,2 | sí | sí |
| P10 | GW–GSW | (12, 24) | 1,2 | no | sí |
| P11 | GW–ANT | (3, 14) | 1,2 | no | sí |
| P12 | ANT–ANTE | (16, 12) | 1,2 | no | sí |
| P13 | ANTE–VLT (acorazada) | (24, 10) | 2,4 | combinación (con la caja fuerte) | no |
| P14 | VLT–ARC (servicio) | (32, 3) | 1,2 | sí, ganzúa: la ruta C pasa a ser la ruta con gadget | sí |
| P15 | ARC–PS | (33, 14) | 1,2 | no | sí |
| P16 | ARC–OFF | (40, 7) | 1,2 | sí | sí |
| P17 | OFF–MNT | (44, 14) | 1,2 | no | sí |
| P18 | PS–TAL | (34, 17) | 1,2 | no | sí |
| P19 | TAL–MNT | (40, 19) | 1,2 | no | sí |
| P20 | PS–GAR | (34, 25) | 1,2 | no | no |
| P21 | GAR–VEST | (42, 27) | 1,2 | no | no |
| P22 | MNT–VEST | (45, 24) | 1,2 | no | sí |
| P23 | PS–DOCK (final del pasillo) | (33, 30) | 2,0 abierto | no | no |
| P24 | GAR–DOCK | (38, 30) | 1,2 | no | no |
| V1 | Ventana interior GAR → PS | x 34, z 27-29 | 2,0 | vidrio fijo: bloquea el paso, no la vista | — |

**Requisito técnico de V1**: el vidrio colisiona en la capa de mundo sólido, pero no en la de visión (`LAYER_VISION`), para que los rayos de percepción lo atraviesen. Si eso no se puede hacer en el PoC, V1 queda como hueco a 1,0 m de alto (alféizar), que cubre al agachado.

### Grafo
```
            ANT ──P12── ANTE ──P13── VLT ──P14── ARC ──P16── OFF
             │P11        │P08                     │P15        │P17
            GW ──P07──  ROT ─────────P09──────── PS ──P18── TAL ──P19── MNT
             │P10        │P04                     │P20  ·V1·            │P22
            GSW ──P05── VES ─────────P06──────── PS    GAR ──P21── VEST
             │P02        │P01                     │P23   │P24
             └──────── ALY (callejón) ──────────  DOCK ─┘
                         └───────────P03──────────┘
```
- **Cuellos de botella**: ANTE (rutas A y B, 16 m bajo CAM-3); PS (ruta C, 16 m rectos junto a la ventana de la garita); las tres salidas al callejón, a 18 y 38 m entre sí, que dos guardias no pueden cubrir a la vez.
- **Bucles cortos para perder a un perseguidor**: el tabique de GW (unos 30 m de vuelta); ROT–P09–PS–P06–VES–P04 (unos 40 m); GAR–VEST–MNT–TAL–PS (unos 34 m, en el lado de los guardias).
- **Atajos**: P09 (de la garita a la rotonda en ~12 m, para los guardias); P14 (del archivo a la cámara sin pasar por la antesala, para el ladrón).
- **Conductos y ventanas transitables**: ninguno. Gatear está aplazado (`stealth.md` A1) y no existe la mecánica de saltar una ventana. V1 y las ventanas de fachada solo dejan pasar la vista y la luz de las farolas.

### Mapa en planta
1 carácter = 1 m en x; 1 fila = 2 m en z (por eso el dibujo sale aplastado en vertical). Norte arriba. Huecos en los muros = puertas; `:` = ventana V1. `$` botín ligero, `H#` pesado, `M` Pieza Maestra, `S` caja fuerte, `R#` reloj, `c#` cámara, `i` panel de interruptores C3/C4, `G` aparición de guardia, `L` aparición del ladrón, `*` farola, `.` lámparas del pasillo de servicio.

```
          0         1         2         3         4         5
          0 2 4 6 8 0 2 4 6 8 0 2 4 6 8 0 2 4 6 8 0 2 4 6 8 0 2
z= 0      +---------------+---------------+-------+-------+
z= 2      |               |               |       |       |
z= 4      | ANT  H1       |  VLT   M       ARC    |OFF $  |
z= 6      |               |  (camara)     |H3     |       |
z= 8      | $ $ $ R2      |               |        R3  S  |
z=10      |               +------   ------+       |       |
z=12      |                i ANTE  c3     |       |       |
z=14      +-  ------------+------   ------+ +-----+--  ---+
z=16      |               | ROT           |       |       |
z=18      | GW  H2        |                 |TAL  |MNT    |
z=20      |  =tabique=         $ (arana)  |.|$     cuadro |
z=22      |               |               | |     |       |
z=24      +----------  ---+c2             |. -------+-  --+
z=26      | R4            +------   ------+ |GAR R1 |VEST |
z=28      |               |           c1    : G G         |
z=30      | GSW  $        | VES  $        + ---  ---------+
z=32      |                               |  DOCK         |
z=34      |               |               |               |
z=36      +----  ---------+------   ------+----------   --+
z=38                  *           *                   *
z=40      [AUTO]  L
z=42                        C A L L E J O N
z=44
```

## 6. Puntos de interés

### Aparición, Pieza Maestra, coche
| Elemento | Posición (x, z) | Notas |
|---|---|---|
| Aparición del ladrón | (8, 40) | Junto al coche, en el callejón oeste |
| Coche de huida | (3, 40), mirando al este | Accesos: P02 a 5 m, P01 a ~21 m por el callejón y P03 a ~41 m. A ~9,5 m de la farola más cercana: queda en sombra |
| Aparición de los guardias | G1 (37, 26) y G2 (39, 26) | Dentro de la garita. A unos 35 m en línea recta del ladrón, con 3 muros de por medio |
| **M** La Dama de Terciopelo (óleo, pesada) | (24, 4) | Sustituye al busto. Valor 5.000 $, `is_heavy` y `is_masterpiece`. Al llevársela, el pedestal queda vacío bajo el foco: es el rastro visible (pilar 2) |

### Botín
Cuota: `core/game_manager.gd` → `quota_target` (10.000 $; debería pasar a un `.tres` de partida, ver "Siguiente paso"). La Pieza Maestra suma 5.000 $ al depositarla en el coche; **faltan 5.000 $**. El botín ligero suma al cogerlo y hace un ruido de 2,5 m; el pesado suma al dejarlo en el maletero, y solo se puede llevar una pieza pesada cada vez.

| Id | Objeto | Sala, posición | Tipo | Valor | Distancia andando al coche |
|---|---|---|---|---|---|
| L1 | Escarabajo de oro | ANT (5, 4), vitrina | ligero | 1.500 | — |
| L2 | Monedas romanas | ANT (11, 9), vitrina | ligero | 1.000 | — |
| L3 | Amuleto de lapislázuli | ANT (3, 10), vitrina | ligero | 1.000 | — |
| L4 | Pitillera esmaltada | ROT (24, 20), vitrina central bajo la araña | ligero | 1.000 | — |
| L5 | Caja registradora | VES (20, 29), taquilla | ligero | 500 | — |
| L6 | Fajo del cajón | OFF (43, 4), escritorio | ligero | 500 | — |
| L7 | Miniatura en restauración | TAL (37, 20), mesa | ligero | 1.000 | — |
| L8 | Reloj de bolsillo | GSW (8, 30), vitrina | ligero | 500 | — |
| S | Joyas de la caja fuerte | OFF (46, 12), tras un cuadro | ligero (dentro de `SafeBox3D`) | 3.000 | — |
| H1 | Ánfora griega | ANT (8, 2) | pesado | 3.000 | ~50 m (P11-P10-P02) |
| H2 | Retrato del Duque | GW (8, 19), en el tabique | pesado | 2.500 | ~24 m (P10-P02) |
| H3 | Busto de bronce | ARC (36, 4) | pesado | 2.000 | ~65 m (P15-PS-P06-VES-P01) |

Total disponible sin la Pieza: 10.000 $ ligeros y 7.500 $ pesados, 3,5 veces lo que falta. Combinaciones para los 5.000 $:
1. **Caja fuerte**: S + L1 + L5 = 5.000 (noreste, noroeste y vestíbulo; pide abrir la caja).
2. **Todo al oeste**: H2 + L1 + L2 = 5.000 (ruta B pura, con un viaje pesado de más).
3. **Ligero y repartido**: L1 + L2 + L3 + L4 + L8 = 5.000 (sin caja ni pesados, pero pasando por la rotonda).
4. **Pesado lejano**: H1 + L4 + L7 = 5.000 (el ánfora obliga a volver por todo el oeste cargado).

### Relojes de fichar
Cuatro, uno por cuadrante. `round_duration` es un campo del nodo (dato de nivel, hoy 90 s por defecto, `DEFAULT_ROUND_DURATION`). Rango de ritmo propuesto: 60-120 s. Fichar hace un ruido de 5,5 m y un reloj vencido suena a 14 m cada 3 s (constantes de `time_clock_3d.gd`).

| Id | Sala, posición | Ciclo | Por qué ahí |
|---|---|---|---|
| R1 | GAR (36, 24,2), muro norte | 90 s | En la garita (lo pide el encargo). Es el único que se puede fichar sin salir |
| R2 | ANT (0,2, 6), muro oeste | 90 s | Lleva a un guardia al botín ligero del noroeste y a la antesala |
| R3 | OFF (47,8, 2), esquina noreste | 90 s | El camino de R3 a R2 cruza la cámara: los guardias pasan junto a la Pieza |
| R4 | GSW (0,2, 26), muro oeste | 90 s | Cubre la entrada de la ruta B sin estar a la vista del coche (a 16 m, tras un muro) |

### Cámaras y monitores
Valores de `security_camera_3d.gd`: alcance 9,5 m, FOV 52° y barrido de 65°, todos campos del nodo (datos de nivel). Montaje a 2,9 m.

| Id | Montaje (x, z) | Apunta a | Cubre | Ángulo muerto que se puede descubrir |
|---|---|---|---|---|
| CAM-1 | VES (31,5, 26,5) | suroeste | Taquilla, P01 y P06 (a 1,6 m) | Franja oeste del vestíbulo y P05 (a 16 m, fuera de alcance) |
| CAM-2 | ROT (16,5, 25,5) | noreste | Mitad sur de la rotonda, P04 y P07 en el extremo del barrido | Mitad norte: P08 y P09 quedan a más de 9,5 m |
| CAM-3 | ANTE (31,5, 10,5) | oeste, a lo largo de la antesala | x 22-31 y la puerta acorazada P13 (a 7,5 m) | Extremo oeste: P12 y el panel de interruptores C3/C4 |
| Monitores | GAR, 3 CRT en la mesa del muro este (41,5, 25-28), mirando al oeste | — | Uno por cámara | Quien mira los monitores da la espalda a la ventana V1 y a P20: o mira las pantallas o mira el pasillo |

Hoy la detección de una cámara solo avisa a la IA (`SignalBus.thief_spotted` → `guard_ai_3d.gd`); un guardia humano solo se entera mirando un monitor. A 1080p, un monitor de 0,44 × 0,33 m apenas ocupa unos píxeles: ver la decisión abierta 5.

### Luces e interruptores
Circuitos numerados por `circuit_id`. "Interruptor" es un `LightSwitch3D` a 1,2 m de alto, junto al vano indicado (a menos de 1,5 m de la puerta, fuera de su zona de despeje).

| Circuito | Lámparas | Estado inicial | Interruptores |
|---|---|---|---|
| C1 VES | techo × 2: (20, 31) y (28, 31) | encendido | junto a P04, en el lado del vestíbulo; duplicado en el cuadro de MNT |
| C2 ROT | techo × 3: (20, 20), (24, 20) y (28, 20) | encendido | junto a P08 y junto a P09; duplicado en el cuadro de MNT |
| C3 ANTE | techo × 1: (28, 12) | encendido | panel oeste de la antesala (17, 10,2) |
| C4 VLT | techo × 2: (24, 4) foco y (29, 6) | encendido | **solo** en el panel oeste de la antesala (17,5, 10,2), fuera de la cámara y fuera de CAM-3 |
| C5 ANT | techo × 2: (5, 5) y (11, 9) | encendido | junto a P11 y junto a P12; duplicado en el cuadro de MNT |
| C6 GW | techo × 2: (5, 16,5) y (11, 21,5) | apagado | junto a P07 |
| C7 GSW | techo × 2: (5, 30) y (11, 30) | encendido | junto a P02 y junto a P05; duplicado en el cuadro de MNT |
| C8 PS | techo × 2: (33, 17) y (33, 25) | encendido | junto a P15 y junto a P23 |
| C9 GAR | techo × 1: (38, 27) | encendido | junto a P20 |
| C10 OFF | techo × 1: (44, 9) + flexo (43, 4) con cadenilla propia | techo apagado, flexo encendido | junto a P16 |
| C11 TAL | flexo (37, 20) | encendido | cadenilla propia |
| C12 MNT | techo × 1: (44, 19) | apagado | junto a P17 y junto a P19 |
| C13 ARC | techo × 1: (36, 7) | apagado | junto a P15 |
| C14 DOCK | techo × 1: (40, 33) | encendido | junto a P24 |
| C15 VEST | techo × 1: (45, 27) | apagado | junto a P21 |
| — ALY | `lamp_street` × 3 | fijo | — |

Requisitos de P2.2 de `stealth.md`: toda sala iluminada tiene un bolsillo de sombra (columna "Coberturas" de §4) y un interruptor a la vista desde una entrada; ninguna ruta obligatoria pasa solo por luz fija (el callejón tiene su franja z 41-44 a oscuras).

### Teléfonos (reserva)
Fuera del PoC (no existe el sistema). Extensiones reservadas, repartidas en extremos opuestos: 101 taquilla de VES, 102 despacho OFF, 103 garita GAR, 104 antigüedades ANT. Una llamada de 104 a 103 saca a un guardia de la garita; una de 101 a 104 vacía el noroeste.

## 7. Rutas del ladrón
Tiempos de la ruta de ida, del coche al pedestal, sin esperas: andando / en sigilo. La vuelta cargado tarda ×1,25.

| Ruta | Recorrido | Longitud | Tiempo | Riesgo | Carácter |
|---|---|---|---|---|---|
| **A pública** | Coche → P01 → VES → P04 → ROT → P08 → ANTE → P13 → M | ~50 m | 10 s / 21 s | Las tres cámaras, tres salas encendidas, parqué en la rotonda y la vía de los guardias por P09 | Rápida y arriesgada |
| **B galerías** | Coche → P02 → GSW → P10 → GW (bucle del tabique) → P11 → ANT → P12 → ANTE oeste → P13 → M | ~62 m | 12 s / 26 s (31 s agachado) | GSW encendida junto a R4; ANT de parqué; los últimos 8 m de la antesala dentro de CAM-3 | Sigilosa y larga |
| **C servicio** | Coche → callejón → P03 → DOCK → P23 → PS → P15 → ARC → P14 → M | ~84 m | 17 s / 35 s | Pasa junto a la garita (P24, V1) y por el pasillo encendido; los guardias salen por P20 | Pide una interacción: apagar C8 en P23 o C1/C2 desde el cuadro de MNT. Tras el PoC, la ganzúa de P14 |
| C′ servicio por el vestíbulo | Coche → P01 → VES → P06 → PS → P15 → ARC → P14 → M | ~60 m | 12 s / 25 s | CAM-1 ve P06 a 1,6 m: solo vale con C1 apagado o en el barrido contrario | Variante |

Vueltas con la Pieza: A al revés, 50 m (12,5 s andando cargado, 26 s en sigilo cargado); B al revés, 62 m (15,5 / 32 s); C′ al revés, 60 m. Las tres acaban en una salida distinta: P01, P02 o P03.

**Travesía mínima resuelta** (combinación 1; "cabe holgada en la partida, pero no sin riesgo"):
Coche → P01 → L5 → P04 → L4 → ANTE → P13 → P14 → ARC → P16 → L6 → S (abrir) → P16 → P14 → M → P13 → ROT → VES → P01 → coche.
- Sin carga: ~105 m. Con la Pieza: ~50 m. Abrir la caja fuerte: unos 30 s (estimación; el sistema no tiene un tiempo fijo).
- Andando: 21 + 12,5 + 30 = **~64 s**. En sigilo: 44 + 26 + 30 = **~100 s**.
- Con un factor de 3-4 por esperas, escondites y rodeos: **5-7 minutos** de partida de 10 (`match_duration_seconds` = 600 s). Si un ladrón experto gana sistemáticamente en menos de 4 minutos, sobra botín o sobra mapa (ver §9).

## 8. Patrullas y ritmo
Los relojes imponen el recorrido; el reparto entre los dos guardias es suyo. Estas son las dos rondas naturales con su coste andando (4,2 m/s):

| Ronda | Recorrido | Longitud | Tiempo | % del ciclo de 90 s |
|---|---|---|---|---|
| **Oeste** (R4 y R2) | GAR → P20 → PS → P09 → ROT → P07 → GW → P10 → R4 → P10 → GW → P11 → R2 → P12 → ANTE → P08 → ROT → P09 → PS → GAR | ~123 m | ~29 s | 33 % |
| **Este y cámara** (R1 y R3) | R1 → P21 → VEST → P22 → MNT → P17 → R3 → P16 → ARC → P14 → **VLT** → P13 → ANTE → P08 → ROT → P04 → VES → P06 → PS → P20 → R1 | ~92 m | ~22 s | 24 % |
| **Un solo guardia ficha los cuatro** | R1 → R3 → R2 (por la cámara) → R4 → R1 | ~162 m | ~39 s | 43 % |

**Contra la acampada** (checklist: "ninguna sala obligatoria se puede vigilar desde un único punto fijo"):
- **Garita**: desde ella se ven los 3 monitores (con la espalda a la ventana) y el pasillo de servicio, nada obligatorio. Si un guardia se queda en ella, el otro tiene que fichar R2, R3 y R4 solo: ~39 s de cada 90, siempre por el mismo recorrido, y el ladrón ve su linterna. Es una estrategia legítima, operador más corredor, con su contrajuego: ruta B y cuidado con CAM-3.
- **Cámara acorazada**: con C4 encendido, un guardia junto al pedestal ve las dos puertas (240° de vista con luz). La respuesta del ladrón es apagar C4 desde el panel oeste de la antesala, en el punto ciego de CAM-3. Entonces el guardia solo ve con su linterna (64°) y no puede cubrir a la vez P13 (sur) y P14 (este), separadas ~110° desde el pedestal. Y para volver a dar la luz tiene que salir a la antesala, 8 m: es el momento de entrar por P14. **Tensión justificada**: la sala obligatoria es acampable con la luz encendida y deja de serlo con un clic de 2 m que el guardia ve y oye.
- **Antesala**: un guardia en ella cubre las rutas A y B, pero no la C (P14 por el archivo).
- **Coche**: es el riesgo de acampada más serio (ver §9). Ningún reloj queda a la vista del coche: un guardia que lo acampe no ficha nada, y el otro carga con los cuatro relojes (43 % del ciclo).

**Ritmo de una partida de 8-10 minutos** (lo que se espera):
- 0:00-1:30, reconocimiento: el ladrón elige entrada; los guardias salen a la primera ronda y fichan antes de 1:30.
- 1:30-5:00, acopio: botín ligero y caja fuerte; primeros sustos por ruido, interruptores que se apagan.
- 5:00-8:00, la Pieza: apagar C4, el pedestal vacío, la huida cargado a 4 m/s y la persecución por los bucles.
- 8:00-10:00, el coche: tres salidas, dos guardias y el callejón a oscuras.

## 9. Checklist del nivel (`.claude/skills/level/references/level-checklist.md`)
| Punto | Estado | Nota |
|---|---|---|
| Tres rutas a la Pieza: sigilosa y larga, rápida y arriesgada, con gadget o interacción | verde | B, A y C (interruptores; la ganzúa de P14 tras el PoC) |
| El coche tiene dos aproximaciones o más | verde | P02, P01 y P03 |
| Ninguna ruta es segura de punta a punta | verde | A: cámaras y luz; B: R4, parqué y CAM-3; C: garita y pasillo |
| Ninguna sala obligatoria se vigila desde un punto fijo | **tensión** | VLT con la luz encendida (§8). Coche (§9, riesgos) |
| Los relojes obligan a recorrer el mapa y pasan cerca del botín | verde | 24-43 % del ciclo; R2 está junto al botín de ANT y el camino R3-R2 cruza la cámara |
| La travesía mínima cabe holgada, pero no sin riesgo | verde | ~64-100 s de movimiento; 5-7 min estimados |
| Las superficies dibujan el riesgo | verde | Alfombra en GW, ANTE y OFF; parqué en ROT, ANT y TAL; mármol en VES, VLT y GSW |
| Hay sombras y luces apagables; las visuales largas tienen coberturas | verde | PS (16 m) no tiene coberturas, pero tiene interruptor en los dos extremos y es ruta de servicio, no obligatoria |
| Teléfonos repartidos | **tensión** | El sistema no existe en el PoC; extensiones reservadas en extremos opuestos (§6) |
| Cámaras con ángulos muertos; el monitor obliga a quedarse quieto | verde (con la decisión 5) | Ángulos muertos en §6. Hoy el monitor no se lee a 1080p |
| Cuota con al menos dos combinaciones | verde | Cuatro combinaciones |
| El botín pesado está lejos de la salida | **tensión** | H1 (50 m) y H3 (65 m) sí; H2 está a 24 m de P02, compensado con un valor menor y con la sala a oscuras, donde el guardia en alfombra no se oye |
| Disfraz | n/a | Sin `disguise.md` |
| Legibilidad isométrica | **tensión** | La cámara mira desde el sureste: los muros sur y este de cada sala y los tabiques exentos tapan lo que hay detrás. Requisito: esos muros se recortan en lo visual (a 1,0-1,3 m, como el `FRONT_WALL_H` actual, o se desvanecen cerca del jugador) con la colisión entera de 3,2 m |
| Cada sala se reconoce por su forma, suelo o mobiliario | verde | Rotonda con columnas y araña; GW con tabique; ANT con sarcófago; servicio con linóleo y fluorescentes |
| Medidas | verde | Muros en múltiplos de 2 m, puertas de 1,2 m, pasillo de 2,0 m (≥ 1,6) |

Ningún punto en rojo.

## 10. Pilares
| Pilar | Cómo lo cumple el nivel |
|---|---|
| 1. Tecnología de 1984 | CCTV con CRT, relojes de fichar mecánicos, cuadro de alumbrado con palancas y caja fuerte de dial; nada digital |
| 2. El sonido es información | Cada suelo suena distinto y las rutas se eligen por él. Apagar la luz hace clic. **Silencio a justificar**: coger un botín pesado no emite ruido (`_attach_to_thief_hands`); el rastro es visual (el pedestal vacío bajo el foco). Ver la decisión 7 |
| 3. Información frente a número | El ladrón ve los haces a través de los muros y conoce el mapa; los guardias dependen de monitores que les obligan a quedarse quietos y de relojes que les obligan a moverse |
| 4. Toda herramienta tiene respuesta | La luz encendida protege la cámara y apagarla la expone (§8); la alfombra silencia a los dos bandos; los bucles salvan al ladrón, pero los recorta P09 |
| 5. Partidas cortas y tensas | Travesía de 1-2 min de movimiento en una partida de 10; relojes de 90 s |
| 6. El ladrón no es violento | El nivel no ofrece nada para atacar; los bucles y las sombras son la forma de escapar |

## 11. Riesgos de balance y qué medir en el playtest
| Riesgo | Señal de alarma en el playtest | Mando o respuesta |
|---|---|---|
| **Acampar el coche**: un guardia espera junto al coche y el ladrón no puede terminar | En 2 o más de 5 partidas, un guardia pasa más de 90 s seguidos a menos de 8 m del coche | Decisión 4 (dos aparcamientos al azar) y decisión 3 (penalización de los relojes) |
| Relojes sin consecuencia: hoy un reloj vencido solo suena | Algún reloj vence más de 2 veces por partida y los guardias no cambian de plan | Decisión 3 |
| Mapa demasiado grande: guardias y ladrón no se cruzan | Menos de 2 detecciones (vista o ruido) por partida | `round_duration` a 75 s; la decisión 2 (mapa S) |
| Mapa demasiado pequeño o botín de sobra | Mediana de victoria del ladrón por debajo de 4 min | TUNE de `quota_target` a 12.000 $ o retirar L8 y L5 |
| La rotonda absorbe toda la partida | Más del 50 % de las capturas en ROT | Bajar C2 a 2 lámparas; quitar P09 |
| La ruta B domina | B en más del 70 % de las idas o vueltas | Encender C6 al inicio; acercar R4 a P10 |
| Monitores inútiles | Ningún guardia pasa más de 20 s seguidos en la mesa | Decisión 5 |
| H2 demasiado barato | H2 en todas las partidas | Bajarlo a 2.000 $ o moverlo al extremo norte del tabique |

**Qué anotar en cada partida** (sin telemetría, a mano o en vídeo): duración y resultado; ruta de ida y de vuelta del ladrón (A, B, C o C′); combinación de botín; salida usada; número de veces que se apagó C4 y quién lo restauró; relojes vencidos; posición de cada guardia en el minuto 2, 5 y 8; momento en que un guardia notó el pedestal vacío; si alguien pidió "otra".

## 12. Piezas modulares (para buscar assets)
Medidas aproximadas en metros (ancho × fondo × alto), escala 1 u = 1 m. Las coberturas bajas tienen que tener al menos 1,0 m de opaco.

| Familia | Pieza | Medidas | Cantidad aprox. | Notas |
|---|---|---|---|---|
| Muros | Muro recto | 2,0 × 0,3 × 3,2 (y 1,0 de ajuste) | ~90 | Juego "palacete" (estuco y zócalo) y juego "servicio" (azulejo o pintura) |
| | Muro con vano de puerta | 2,0 × 0,3 × 3,2, vano de 1,2 × 2,2 | 22 | |
| | Muro con arco | 4,0 × 0,3 × 3,2, vano de 2,4 × 2,6 | 4 | VES, ROT, ANTE |
| | Muro con ventana | 2,0 × 0,3 × 3,2, alféizar a 1,0 | ~10 + V1 | Fachada sur y garita |
| | Variante baja de cada muro | alto 1,0-1,3 | igual | Para recortar los muros sur y este en lo visual |
| | Esquina y pilastra | 0,3 × 0,3 × 3,2 | ~40 | |
| | Tabique expositor exento | 4,0 × 0,3 × 2,4 (y 10 m en piezas) | 5 | GW y GSW |
| Puertas | Hoja de madera | 1,2 × 0,05 × 2,2 | 20 | Abiertas en el PoC (visuales) |
| | Puerta doble principal | 2,4 × 2,2 | 1 | P01 |
| | Puerta acorazada con volante | 2,4 × 0,4 × 2,4 | 1 | P13, abierta |
| | Persiana metálica | 3,0 × 3,0 | 1 | P03 |
| Estructura | Columna de mármol | Ø 0,6 × 3,2 | 10 | ROT, VLT y VES |
| Exposición | Vitrina baja | 1,2 × 0,6 × 1,0 opaco + 0,4 de vidrio | 10 | ANT, ROT, GSW y VLT |
| | Vitrina de pared | 2,0 × 0,5 × 2,2 | 2 | ANT |
| | Pedestal con estatua | 0,8 × 0,8 × 2,2 | 6 | Duras |
| | Pedestal de jarrón | 0,6 × 0,6 × 1,0 | 4 | ANTE |
| | Pedestal de la Pieza Maestra | 1,2 × 1,2 × 1,1 | 1 | Con postes y cordón de 0,3 × 0,3 × 1,0 (no cubren) |
| | Sarcófago | 2,2 × 0,8 × 1,0 | 1 | ANT |
| | Cuadros de pared | 1,0 × 0,8; 1,6 × 1,2; 2,4 × 1,6 | ~30 | El de la Pieza Maestra y H2, como objeto portable de 1,0 × 0,8 |
| | Ánfora y busto (botín) | Ø 0,4 × 0,8; 0,5 × 0,4 × 0,6 | 2 | H1 y H3 |
| | Banco de museo | 1,6 × 0,5 × 0,45 | 6 | No cubre |
| | Caballete | 0,8 × 0,8 × 1,8 | 3 | GW y TAL |
| | Alfombra o pasillo | plano por sala | 3 | Marca visual de la superficie |
| Vestíbulo | Mostrador de taquilla | 3,0 × 0,8 × 1,1 | 1 | |
| | Guardarropa con perchas | 2,0 × 0,6 × 1,8 | 1 | |
| | Planta en maceta | 0,6 × 0,6 × 1,6 | 4 | VES y OFF |
| Oficina | Escritorio de conservador | 1,6 × 0,8 × 0,75 | 1 | |
| | Archivador | 0,5 × 0,6 × 1,3 | 4 | |
| | Estantería | 2,0 × 0,4 × 2,2 | 2 | |
| | Butaca y silla | 0,7 × 0,7 × 1,0 | 3 | |
| Seguridad | Mesa de monitores | 2,4 × 0,8 × 0,75 | 1 | |
| | Monitor CRT | 0,5 × 0,45 × 0,45 | 3 | Existe `cctv_monitor_3d.gd` |
| | Taquilla metálica (bloque de 4) | 1,6 × 0,5 × 1,9 | 3 | VEST y GAR |
| | Reloj de fichar de pared | 0,35 × 0,2 × 0,5, a 1,5 m | 4 | Existe `time_clock_3d.gd` |
| | Cámara CCTV de pared | 0,3 × 0,2 × 0,2 | 3 | Existe |
| Servicio | Estantería de almacén | 2,0 × 0,6 × 2,2 | 6 | ARC |
| | Caja de embalaje | 1,0 × 1,0 × 1,0 y 1,2 × 0,8 × 1,2 | ~15 | ARC y DOCK |
| | Palé y carretilla | 1,2 × 0,8 × 0,15; 0,6 × 0,5 × 1,2 | 4 + 1 | DOCK |
| | Mesa de restauración | 2,0 × 1,0 × 0,9 | 1 | TAL |
| | Generador diésel | 2,0 × 1,0 × 1,4 | 1 | MNT |
| | Caldera | 1,2 × 1,2 × 2,0 | 1 | MNT |
| | Cuadro de alumbrado | 1,2 × 0,3 × 1,8 | 1 | MNT, con 4 palancas |
| Luz | Araña | Ø 1,2 × 1,0 | 3 | ROT |
| | Lámpara de techo clásica | Ø 0,5 | 8 | |
| | Fluorescente industrial | 1,2 × 0,2 | 7 | Servicio |
| | Flexo y lámpara de banquero | 0,3 × 0,3 × 0,5 | 2 | OFF y TAL |
| | Interruptor de pared | 0,1 × 0,15, a 1,2 m | ~18 | |
| Exterior | Farola de sodio | 4,0 de alto | 3 | `lamp_street` |
| | Contenedor de basura | 1,8 × 1,0 × 1,3 | 3 | |
| | Bordillo y acera | 56 × 2 | 1 | |
| | Coche de huida | — | 1 | Existe `escape_car_84` |

## 13. Decisiones abiertas
1. **► ¿Esqueleto A (dos alas, servicio al este)?** Recomendación: **A**. Las alternativas B (anillo) y C (H) están en §3.
2. **► ¿Tamaño de 48 × 36 m?** Opciones: S, 40 × 30 m (todo un 17 % más corto: más encuentros y partidas más rápidas); M, 48 × 36 m; L, 56 × 44 m (pide 3-4 guardias). Recomendación: **M** para 1 contra 2, y ajustar en el playtest con `round_duration`, sin redibujar.
3. **► ¿Qué pasa si un reloj vence?** Hoy solo suena una campana. Es una regla de sistema (`interaction.md` y `match.md`), no del nivel. Opciones: (a) nada más; (b) cada vencimiento suma 20 s a la partida; (c) **victoria por tiempo solo con la ronda al día**: si la partida acaba con algún reloj vencido, los guardias no ganan por tiempo (gana el ladrón si tiene la Pieza, y si no, empate). Recomendación: **c**. Es la única que impide que los dos guardias acampen el coche y vuelve frenético el último minuto. Pide un `/design` corto.
4. **► ¿El coche siempre en el mismo sitio?** Opciones: fijo en el callejón oeste; o dos aparcamientos (callejón oeste o este, a x 30) elegidos al azar al empezar, que solo conoce el ladrón. Recomendación: **fijo en el primer playtest**, con el riesgo medido (§11), y los dos aparcamientos como respuesta preparada si salta la alarma. Así se prueba antes.
5. **► ¿Los monitores se miran en grande?** Opciones: solo en el mundo, como ahora; o una interacción "mirar monitores" que muestra las 3 imágenes en el HUD del guardia mientras no se mueva (moverse la cancela). Recomendación: **la interacción**. Sin ella las cámaras no valen nada contra guardias humanos, y es la que obliga a quedarse quieto.
6. **► ¿Linóleo como superficie nueva (×1,0, rango 0,9-1,1)?** Opciones: crear `surface_linoleum.tres`; o usar mármol en el lado de servicio. Recomendación: **crearla**. Separa a la vista y al oído lo público de lo de servicio, y en el PoC puede usar provisionalmente la muestra de pasos del mármol.
7. **► ¿Alarma de peso en el pedestal de la Pieza?** Una campana mecánica al levantarla. Recomendación: **no en el primer playtest**: el pedestal vacío bajo el foco es el rastro. Se mide cuánto tardan los guardias en notarlo; si pasa de 60 s, se añade la alarma con un `/design`.
8. **► ¿Qué se hace con la escena vieja?** Recomendación: la escena nueva es `scenes/maps/museum_v2.tscn` (generada desde datos) y `museum_velvet_84.tscn` se borra cuando la nueva sea jugable en LAN, no antes, para no dejar el PoC sin mapa.

## Siguiente paso
- **FEAT "nivel por datos"** (antes de la maqueta): un recurso `LevelBlueprint` en `data/levels/museum_v2.tres` con salas (id, tipo, rectángulo, superficie), puertas (posición, ancho, eje), ventanas, puntos de interés (botín, relojes, cámaras, monitores, lámparas con circuito y estado, interruptores, apariciones y coche) y mobiliario de colisión. `MuseumLevelBuilder3D` construye muros, vanos y la variante baja de los muros sur y este solo a partir del recurso, sin nada escrito a mano. Toca `src/generation/`, `data/levels/` y tests de sus invariantes: los muros cierran, cada sala tiene superficie de tipo, cada sala encendida tiene interruptor y no hay puertas en las zonas de despeje.
- **FEAT "museo v2"**: escribir `museum_v2.tres` desde las tablas de este documento (lo puede escribir `game-designer` en cuanto exista el formato), generar `scenes/maps/museum_v2.tscn` con su `HeistMap3D` y dejarla para que el usuario la decore. Incluye `surface_linoleum.tres` si se aprueba la decisión 6.
- **FEAT pequeña**: `quota_target` y `match_duration_seconds` pasan de `@export` en `game_manager.gd` a un `data/balance/match.tres`.
- **`/design` aparte**, solo si se aprueban: penalización de los relojes (decisión 3) y la interacción de los monitores (decisión 5). Es lo que más pesa en la meta del PoC, más que el propio plano.
- **Búsqueda de assets** con la lista de §12 (regla 02), empezando por muros modulares, columnas, vitrinas y puertas.
