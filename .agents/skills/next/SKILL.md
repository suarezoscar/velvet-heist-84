---
name: next
description: Muestra la cola de trabajo de Velvet Heist '84 a partir del roadmap del PoC, las FEAT, TUNE, documentos de diseño y ramas abiertas: qué espera aprobación del usuario, qué está en curso y qué toca después. Úsala al empezar una sesión o cuando alguien pregunte qué toca ahora.
---
# /next — cola de trabajo

1. Lee `docs/decisions/2026-10-23-roadmap-poc.md` (hitos y meta del PoC), el estado de `docs/tasks/FEAT-*.md` y `TUNE-*.md`, los diseños `propuesto` de `docs/gdd/`, las ramas abiertas (`git branch --list 'feat/*' 'fix/*' 'chore/*'`) y los PR abiertos.
2. Clasifica cada elemento: **Usuario: decidir** (diseños propuestos, preguntas abiertas), **En curso** (ramas y PR abiertos, con su CI) y **Siguiente** (lo próximo del hito actual del PoC).
3. Salida: una tabla corta con la ruta de cada FEAT y la siguiente acción concreta.
