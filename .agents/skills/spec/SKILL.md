---
name: spec
description: Crea o revisa una especificación técnica de feature (FEAT-XXX) en docs/tasks/ con sus paquetes de ejecución. Úsala antes de delegar cualquier implementación a un agente, y cuando el usuario pida una feature, sistema, asset o cambio de comportamiento ya diseñado.
---
# /spec — especificación técnica y paquetes

1. **Puerta de diseño**: si la FEAT cambia mecánicas, niveles o balance, necesita un documento de `docs/gdd/systems/` (o de nivel) en estado `aprobado`. Si no existe, para y propón pasar antes por `/design` o `/level`. Las FEAT puramente técnicas (refactor, red, CI, herramientas) declaran `n/a — técnica`.
2. Lee `AGENTS.md`, el documento de diseño aprobado, `.agents/ownership.yml` y, si la FEAT toca red, la skill `netcode`.
3. Busca la siguiente numeración libre en `docs/tasks/`, copia `docs/tasks/_TEMPLATE.md` a `docs/tasks/FEAT-XXX-slug.md` y complétala con estado `borrador`.
4. Escribe un paquete por agente, más `PKG-QA` para los tests de aceptación. Cada paquete está **cerrado**: un modelo rápido lo ejecuta sin decidir nada.
   - Bloque `allowed` con los archivos exactos; cada archivo pertenece al agente según `ownership.yml` o lleva `# excepción: <motivo>`.
   - Contratos con nombres y tipos exactos.
   - Cada valor con su origen (`.tres` y campo, o tabla de la spec).
   - Dependencias entre paquetes en la tabla de estado; dos paquetes paralelos no comparten archivos.
5. Resume la spec al usuario, señala las decisiones abiertas y pide aprobación. Solo con su aprobación pasa a `aprobada`; entonces se lanza con `/dispatch`.

Criterios de calidad:
- Cada criterio de aceptación es medible y apunta a su evidencia: un test, un JSON de validación o una captura. "Debería funcionar bien" no es un criterio.
- Los contratos son exactos, para que arte, código y tests avancen en paralelo sin hablarse.
- Si la feature toca red, enlaza `docs/tasks/FEAT-002-net-readiness.md` y declara qué se replica, quién tiene autoridad y con qué frecuencia.
