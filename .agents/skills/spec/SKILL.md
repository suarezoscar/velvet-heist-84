---
name: spec
description: Crea o revisa la nota de una feature (FEAT-XXX) en docs/tasks/ antes de implementarla. Úsala cuando el usuario pida una feature, sistema, asset o cambio de comportamiento ya diseñado, o al empezar una tarea de más de un día.
---
# /spec — nota de FEAT

1. **Diseño**: si la FEAT cambia mecánicas, niveles o balance, necesita un documento de `docs/gdd/systems/` (o de nivel) aprobado; si no existe, pasa antes por `/design` o `/level`. Las FEAT técnicas declaran `n/a — técnica`.
2. Busca la siguiente numeración libre en `docs/tasks/`, copia `docs/tasks/_TEMPLATE.md` a `docs/tasks/FEAT-XXX-slug.md` y complétala.
3. Escribe lo justo para que el trabajo no se desvíe:
   - objetivo y por qué acerca el PoC;
   - criterios medibles, cada uno con su evidencia (test, captura o partida de prueba);
   - contratos solo donde otra pieza depende de ellos (señales, RPC, recursos `.tres`);
   - si toca red, la tabla de replicación (skill `netcode`);
   - riesgos y decisiones abiertas.
4. Resume la nota al usuario y pide aprobación solo si hay decisiones suyas (diseño, alcance, cambios de pilares). Si es técnica y sin decisiones abiertas, empieza a implementar.
