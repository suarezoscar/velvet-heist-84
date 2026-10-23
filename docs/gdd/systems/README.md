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
| `stealth.md` | Percepción, visibilidad, ruido por superficie, modos de movimiento, linterna, luz y anillos | aprobado (partes 1 y 2) |
| `characters.md` | Vestuario, silueta y presupuesto de los personajes | aprobado |
| `gadgets.md` | Maletín del ladrón y cinturón de los guardias | por crear |
| `interaction.md` | Cajas fuertes, puertas, teléfonos, relojes de fichar, cámaras | por crear |
| `loot.md` | Botín ligero y pesado, cuota, Pieza Maestra | por crear |
| `match.md` | Flujo de partida, tiempo, equipamiento en el lobby | por crear |
| `disguise.md` | Disfraz de guardia del ladrón | por diseñar (primera propuesta de `/design`) |

## Pendiente de diseño
- **Disfraz de guardia**: mecánica pedida por el usuario. Va antes de la spec de red autoritativa porque cambia el filtro de visibilidad del ladrón.
- **Posturas de FEAT-005**: resuelto en `stealth.md` (aprobado).
- **Nivel nuevo**: rediseño del museo con `/level` (base: `museum_velvet_84`).
