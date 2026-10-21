---
name: spec
description: Crea o revisa una especificación de feature (FEAT-XXX) en docs/tasks/ antes de implementar nada. Úsala siempre que el usuario pida una feature, mecánica, gadget, sistema, asset o cambio de comportamiento, aunque no diga "spec", y antes de delegar trabajo a cualquier subagente.
---
# /spec — especificación previa de una feature

1. Lee `AGENTS.md` y la sección relevante de `docs/gdd/MASTER_GSD.md`.
2. Busca la siguiente numeración libre en `docs/tasks/`.
3. Copia `docs/tasks/_TEMPLATE.md` a `docs/tasks/FEAT-XXX-slug.md` y complétala: objetivo, alcance y fuera de alcance, criterios de aceptación, contratos (señales, métodos, recursos), assets necesarios con medidas, impacto en red, reparto por subagente y orden.
4. Marca el estado como `borrador`. No implementes nada.
5. Resume la spec al usuario, señala las decisiones abiertas y pide aprobación. Solo tras su aprobación pasa a `aprobada`.

Criterios de calidad:
- Cada criterio de aceptación es medible y apunta a su evidencia: un test, un JSON de validación o una captura. Evita frases como "debería funcionar bien".
- Los contratos son exactos (nombres y tipos), para que arte y código puedan avanzar en paralelo sin hablarse.
- Si la feature toca red, enlaza `docs/tasks/FEAT-002-net-readiness.md` y declara qué se replica.
