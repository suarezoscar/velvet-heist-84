<div align="center">

<img src="docs/img/menu.jpg" alt="Menú principal de Velvet Heist '84: un coche rojo aparcado bajo la lluvia frente a un museo, de noche" width="100%">

# Velvet Heist '84

**Un caballero nunca deja huellas.**

Sigilo táctico asimétrico multijugador en 1984.<br>
Un ladrón de guante blanco frente a una patrulla de guardias, en red o en solitario contra el ordenador.

[![Última versión](https://img.shields.io/github/v/release/suarezoscar/velvet-heist-84?label=descargar&style=for-the-badge&color=ff3d9a)](https://github.com/suarezoscar/velvet-heist-84/releases/latest)
&nbsp;
![Windows y Linux](https://img.shields.io/badge/Windows%20%C2%B7%20Linux-3de0e0?style=for-the-badge)
&nbsp;
![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf?style=for-the-badge&logo=godotengine&logoColor=white)

**[⬇ Descargar la última versión](https://github.com/suarezoscar/velvet-heist-84/releases/latest)** · **[📖 Manual del juego](https://suarezoscar.github.io/velvet-heist-84/)**

</div>

---

## El juego
Es 1984 y es de noche en el Museo Velvet. El **ladrón**, un caballero al estilo de Arsène Lupin que roba con guante blanco y jamás recurre a la violencia, trae el encargo de un coleccionista: varias piezas concretas entre las veinte que hay en el punto de mira. Tiene doce minutos para robarlas y salir por cualquier puerta exterior sin que lo atrapen. Los **guardias**, vigilantes jurados de una empresa de seguridad, han recibido su carta, *«Esta noche me llevaré tres piezas de su colección. Con mis respetos, —V.»*, pero no saben cuáles. Patrullan con linterna, fichan cada uno en su ronda de relojes y vigilan el circuito cerrado desde la garita.

Nadie lo ve todo:
- **El sonido es información.** Cada paso sobre mármol, parqué o alfombra suena distinto, y cada interruptor, caja fuerte o reloj deja un rastro que el otro bando puede oír.
- **Información frente a número.** El ladrón ve más y oye más lejos; los guardias son más y se reparten el edificio.
- **Niebla de guerra.** Solo ves lo que tu personaje tiene a la vista. Lo demás queda en penumbra, como lo recuerdas.
- **El ladrón no es violento.** Se esconde, engaña y espera su momento; nunca ataca.
- **Tecnología de 1984.** Cámaras CCTV con monitores, relojes de fichar mecánicos y cajas fuertes de dial. Nada de drones ni de visión nocturna.

<table>
<tr>
<td width="50%"><img src="docs/img/ladron-niebla.jpg" alt="El ladrón en la Gran Galería de Escultura, entre bustos, columnas y cuadros"></td>
<td width="50%"><img src="docs/img/garita-guardias.jpg" alt="Dos guardias en la garita de seguridad, junto a la pared de monitores; la pared delantera se ve con tramado"></td>
</tr>
<tr>
<td><b>El ladrón.</b> Su encargo está entre 20 obras de 22 salas. Las paredes que lo tapan se ven con tramado, y la ventilación le abre atajos.</td>
<td><b>Los guardias.</b> Salen de la garita, con su puerta y su pared de monitores, cada uno con su propia ruta de relojes.</td>
</tr>
<tr>
<td><img src="docs/img/caja-fuerte.jpg" alt="Panel de la caja fuerte con el dial en el número 11 y la flecha en ámbar, cerca del número"></td>
<td valign="top">
<b>La caja fuerte.</b> Gira el dial con las flechas y escucha: cerca del número suena un clic y la flecha se pone ámbar; en el número, un golpe sordo. Prueba con <kbd>E</kbd>. Los guardias pueden oírte trabajar.
<br><br>
<b>La ronda.</b> Cada guardia tiene una ruta de cuatro relojes y debe fichar el siguiente a tiempo. Si el equipo acumula demasiadas faltas, la ronda se rompe y ya solo les vale atrapar al ladrón.
</td>
</tr>
</table>

## Cómo jugar
1. Descarga el juego de tu sistema desde la **[última versión](https://github.com/suarezoscar/velvet-heist-84/releases/latest)**:
   - **Windows**: [`VelvetHeist84-win-Setup.exe`](https://github.com/suarezoscar/velvet-heist-84/releases/latest/download/VelvetHeist84-win-Setup.exe). Ábrelo y el juego se instala y se abre solo. No está firmado: en el aviso de SmartScreen pulsa «Más información» y luego «Ejecutar de todos modos».
   - **Linux**: [`VelvetHeist84.AppImage`](https://github.com/suarezoscar/velvet-heist-84/releases/latest/download/VelvetHeist84.AppImage). `chmod +x VelvetHeist84.AppImage` y ábrelo.

   Cuando salga una versión, el menú principal te avisa y la instala con un botón. Si prefieres no instalar nada, en la misma página están el `.zip` (Windows) y el `.tar.gz` (Linux), que no se actualizan solos.
2. La primera vez, el juego te pregunta cómo te llamas. Así te verán en la sala de espera y, si te toca ser el ladrón, la carta y la victoria llevarán tu inicial: *«Con mis respetos, —D.»*. Se cambia en **Opciones**.
3. Elige un modo:
   - **Un jugador**: eres el ladrón, y a dos guardias los lleva el ordenador.
   - **Multijugador**: escribe la IP y el puerto de la partida, pulsa Unirse, elige bando y empieza la partida. Al acabar, si todos pulsan **Revancha**, se juega otra con los mismos bandos sin salir del juego.

| Acción | Tecla |
|---|---|
| Moverse / mirar | <kbd>WASD</kbd> o flechas / ratón |
| Correr · sigilo · agacharse | <kbd>Mayús</kbd> · <kbd>C</kbd> · <kbd>Ctrl</kbd> |
| Interactuar · robar a lo bruto (salta la alarma) | <kbd>E</kbd> · <kbd>Q</kbd> |
| Plano del museo | <kbd>M</kbd> o <kbd>Tab</kbd> |
| Linterna · porra (guardias) | <kbd>F</kbd> · clic izquierdo |
| Moneda (ladrón) · walkie · luces de alarma (guardias) | clic derecho · <kbd>T</kbd> · <kbd>Q</kbd> |
| Datos de la conexión | <kbd>F9</kbd> |
| Pausa: controles y salir | <kbd>Esc</kbd> |
| Revancha · volver al menú (al acabar) | <kbd>R</kbd> · <kbd>Esc</kbd> |

La lista completa está en el juego, en **Opciones → Ver controles**.

## Jugar en red
Una persona organiza la partida en su PC con `servidor.bat` (Windows) o `./servidor.sh` (Linux), que vienen en el paquete y abren el juego sin ventana. Abre el puerto **7777** (UDP) en su router y pasa su IP pública y el puerto a los demás. Caben un ladrón y hasta tres guardias, y para empezar hace falta el ladrón y al menos un guardia.

Todos deben usar la misma versión, que se ve abajo a la izquierda del menú; si no coincide, la sala de espera avisa de cuál necesitas. Con <kbd>F9</kbd> verás el ping y la pérdida de paquetes de cada jugador.

La guía completa, con el router, el cortafuegos, CGNAT y cómo compilar desde el código, está en **[docs/manual-compilacion.md](docs/manual-compilacion.md)**.

## Estado
Es la **primera versión** (v0.x), todavía en desarrollo, con un mapa: el museo, con 22 salas y 20 piezas en el punto de mira. Se juega con:
- sigilo, sonido, luz y niebla de guerra;
- tres formas de proteger cada pieza (dial, cambiazo con réplica y corte de corriente);
- ventilación para el ladrón;
- la garita con su puerta y el circuito cerrado;
- una ronda de relojes propia para cada guardia, y el sueño y el café.

Cada cambio que se integra en `master` publica una versión nueva automáticamente.

## Para desarrollar
- Motor: **Godot 4.7.2** (Forward+), GDScript con tipado estático.
- Diseño del juego: [`docs/gdd/`](docs/gdd/), con los [pilares](docs/gdd/pillars.md) y un documento por sistema.
- Reglas del proyecto y flujo de trabajo: [`AGENTS.md`](AGENTS.md).
- Comprobaciones (las mismas que pasa el CI): `tools/ci/import.sh`, `check_scripts.sh`, `lint.sh`, `check_patterns.sh` y `run_tests.sh`.
- Compilar los paquetes: `tools/build/install_templates.sh` (una vez) y `tools/build/export.sh`.

---

<div align="center">
<sub>Un juego de <b>Óscar Suárez</b> · Tipografías de Google Fonts con licencia <a href="assets/fonts/CREDITS.md">SIL OFL 1.1</a><br>
Música: «Coffee Black» de grimfrenzy (CC-BY 3.0) y «Espionage» de haeldb (CC0) · Sonidos: Kenney (CC0), «Yawn» de spookymodem y «coffee cooking» de Christoph (CC-BY 3.0), en <a href="assets/audio/CREDITS.md">créditos de audio</a> · Cafetera: «Coffee Cart 01» de Joe Seabuhr (Poly Haven, CC0)</sub>
</div>
