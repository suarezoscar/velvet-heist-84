---
name: design
description: Propone o revisa el diseño de una mecánica, gadget o sistema de Velvet Heist '84 contra sus pilares, antes de cualquier spec. Úsala ante una idea de mecánica nueva, un cambio de reglas, la división del MASTER_GSD o un documento de sistema que revisar.
---
# /design — propuesta de diseño de un sistema

La ejecuta `game-designer`. El resultado es un documento en `docs/gdd/systems/<sistema>.md` aprobado por el usuario; nunca código.

1. **Contexto**: lee `docs/gdd/pillars.md`, `docs/gdd/systems/README.md`, el documento del sistema si existe y los de los sistemas con los que interactúa. Si partes del `MASTER_GSD.md`, cita la sección de origen.
2. **Preguntas**: como mucho cinco, solo de lo que cambie el diseño (fantasía buscada, límites, qué no debe pasar).
3. **Opciones**: 2-3 alternativas con sus compromisos. En cada una, qué pilar refuerza o tensa y qué contrajuego tiene el otro bando. El usuario elige.
4. **Documento**: escribe o actualiza el documento con `references/system-template.md`, estado `propuesto`. Cada número nuevo se declara como mando de ajuste (recurso `.tres`, valor inicial, rango, tipo y por qué).
5. **Autorrevisión**: pasa `references/design-review.md` y corrige lo que falle antes de enseñarlo.
6. **Aprobación**: presenta un resumen, las preguntas abiertas y el veredicto de la autorrevisión. Con el visto bueno explícito del usuario, el estado pasa a `aprobado` y propones el siguiente paso: la FEAT (con sus paquetes) o la `TUNE`.

Hecho cuando: las siete secciones de la plantilla tienen contenido real, cada número enlaza a su `.tres` (o declara el nuevo), la autorrevisión no deja bloqueantes y el usuario ha aprobado.
