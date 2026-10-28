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
| `interaction.md` | Relojes de fichar (con hoja de faltas y final por tiempo) y monitores CCTV; después cajas fuertes, puertas, teléfonos | aprobado (parte 1, 2026-10-24; implementado en FEAT-016 y FEAT-017) |
| `vision.md` | Zona visible de cada jugador y niebla de guerra en la vista cenital; filtro de red del ladrón | aprobado (2026-10-24) |
| `loot.md` | Botín ligero y pesado, cuota, Pieza Maestra | por crear |
| `match.md` | Flujo de partida, tiempo, equipamiento en el lobby | por crear |
| `gentleman.md` | Temática del caballero ladrón: golpe anunciado, tarjeta de visita, estilo, disfraz | propuesto (2026-10-28) |
| `disguise.md` | Disfraz de guardia del ladrón (de momento, M4 de `gentleman.md`) | por diseñar |

## Pendiente de diseño
- **Disfraz de guardia**: mecánica pedida por el usuario. Va antes de la spec de red autoritativa porque cambia el filtro de visibilidad del ladrón.
- **Posturas de FEAT-005**: resuelto en `stealth.md` (aprobado).
- **Nivel nuevo**: rediseño del museo con `/level` (base: `museum_velvet_84`). Propuesta en `docs/gdd/levels/museum_v2.md` (propuesto, 2026-10-24).
