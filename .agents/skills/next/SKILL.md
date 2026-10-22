---
name: next
description: Muestra la cola de trabajo de Velvet Heist '84 a partir de las FEAT, TUNE y documentos de diseño: qué espera aprobación del usuario, qué paquetes están listos para ejecutar, cuáles esperan revisión y qué ramas esperan merge. Úsala al empezar una sesión o cuando alguien pregunte qué toca ahora.
---
# /next — cola de trabajo

1. Lee el estado de:
   - `docs/gdd/systems/*.md` y `docs/gdd/levels/*.md` (línea de estado),
   - `docs/tasks/FEAT-*.md` (estado de la FEAT y tabla "Estado de los paquetes"),
   - `docs/tasks/TUNE-*.md`,
   - las ramas `git branch --list 'feat/*'`.
2. Clasifica cada elemento en una sola columna:

| Para | Qué |
|---|---|
| Usuario: aprobar | Diseños `propuesto`, FEAT `borrador`, TUNE `propuesta` |
| Antigravity: ejecutar | Paquetes `pendiente` con todas sus dependencias en `revisado` o `integrado` |
| Claude: revisar | Paquetes `entregado` |
| Usuario: merge | Paquetes `revisado` |
| Usuario: desbloquear | Paquetes `bloqueado`, con su pregunta |

3. Señala incoherencias entre la tabla y git: rama de un paquete `pendiente` que ya existe, o paquete `entregado` sin rama.

Salida: la tabla, con la ruta de cada FEAT y el siguiente comando sugerido (`/dispatch FEAT-XXX PKG-N`, revisar con `reviewer`, o qué debe decidir el usuario).
