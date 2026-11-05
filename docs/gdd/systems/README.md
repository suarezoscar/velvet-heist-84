# Documentos de diseño por sistema

Un documento por sistema de juego. Los escribe y mantiene `game-designer` con `/design`; el usuario los aprueba. La plantilla está en `.claude/skills/design/references/system-template.md`.

Reglas:
- Un sistema, un archivo, una fuente de verdad. Si dos documentos se contradicen, se corrige uno de los dos.
- Los números se enlazan al `.tres` que los contiene; nunca se copian sueltos.
- Cuando una FEAT cambia el diseño, el documento del sistema se actualiza en la misma FEAT (definición de hecho).

## Índice
Pendiente de la división de `docs/gdd/MASTER_GSD.md`. Reparto propuesto:

| Documento | Contenido | Estado |
|---|---|---|
| `roles.md` | Fantasía y asimetría de ladrón y guardias, condiciones de victoria | por crear |
| `stealth.md` | Percepción, visibilidad, ruido por superficie, modos de movimiento, linterna, luz y percepción del ruido (audio, vúmetro; sin anillos desde 2026-10-23) | aprobado (partes 1 y 2) |
| `characters.md` | Vestuario, silueta y presupuesto de los personajes | aprobado |
| `gadgets.md` | Maletín del ladrón y cinturón de los guardias | por crear |
| `interaction.md` | Monitores CCTV y selección de interactivos; después cajas fuertes, puertas, teléfonos. Los relojes de fichar (parte R) se retiraron el 2026-10-30 (#116) | aprobado (parte M, 2026-10-24; implementada en FEAT-017; reescrita el 2026-11-04, #118, a falta de su FEAT) |
| `vision.md` | Zona visible de cada jugador y niebla de guerra en la vista cenital; filtro de red del ladrón | aprobado (2026-10-24) |
| `loot.md` | Botín ligero y pesado, cuota, Pieza Maestra | por crear |
| `match.md` | Flujo de partida, tiempo, equipamiento en el lobby | por crear |
| `heist.md` | El golpe: lista del coleccionista, escape por cualquier salida, final por tiempo, sueño fuera de la garita y café, patrulla de la IA, correr solo con alarma, rastros, nivel de alerta, cuenta atrás y rejas con la alarma, sabotaje de las rejas, monedas, walkie e informe con puntos | aprobado (2026-10-28); reglas de #116 decididas por el usuario el 2026-10-30, números aprobados el 2026-11-04; R9 reescrita con #119 (todo en la pieza), aprobada el 2026-11-04; #120 (huida a medias y rejas, R4b y R7b), aprobado el 2026-11-04; #121 (sabotear la caja de la reja, R7c), aprobado por el usuario el 2026-11-05; #167 (conductos: elegir fuera, viaje de como mucho 10 s, nunca escondido; R10), reglas aprobadas por el usuario el 2026-11-05 y detalles de `game-designer` pendientes de revisión |
| `gentleman.md` | Temática del ladrón de guante blanco: golpe anunciado, tarjeta de visita, estilo, disfraz | propuesto (2026-10-28) |
| `disguise.md` | Disfraz de guardia del ladrón (de momento, M4 de `gentleman.md`) | por diseñar |

## Pendiente de diseño
- **Disfraz de guardia**: mecánica pedida por el usuario. Va antes de la spec de red autoritativa porque cambia el filtro de visibilidad del ladrón.
- **Posturas de FEAT-005**: resuelto en `stealth.md` (aprobado).
- **Nivel**: el único mapa es `museum_v2` (`docs/gdd/levels/museum_v2.md`, ampliado en FEAT-034). El museo de 1984 y la mansión se retiraron el 2026-10-29.
