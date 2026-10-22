---
name: balance
description: Analiza el balance de Velvet Heist '84 (valores .tres, rangos de los documentos de sistema, telemetría e informes de playtest), propone ajustes como TUNE-XXX y los aplica tras la aprobación del usuario. Úsala cuando un número se sienta mal, al recibir datos de partidas o antes de cambiar cualquier valor de balance.
---
# /balance — análisis y ajuste de números

La ejecuta `game-designer`.

## 1. Comprobar las entradas
Antes de analizar, lista cada entrada y márcala `ENCONTRADA` o `AUSENTE`:
- `.tres` de `data/balance/` del sistema,
- rangos declarados en su documento de `docs/gdd/systems/`,
- telemetría de partidas,
- informes de `docs/playtests/`.
Una sección cuya entrada falta es `NO EVALUADO — SIN DATOS`; no se estima ni se deduce de otra cosa. Si faltan todas, el veredicto completo es `NO EVALUADO` y dices qué la produciría. Un `NO EVALUADO` es una respuesta correcta.

## 2. Analizar
- Compara cada valor con el rango de su documento. Un valor fuera de rango es un atípico; uno sin rango declarado se lista como "sin rango — no evaluado".
- Asimetría (con telemetría): reparto de victorias por bando frente al objetivo que declare `roles.md`, tiempo hasta la primera detección, duración de partida frente a 8-10 minutos.
- Herramientas: una que nunca se usa sobra o está mal pagada; una que se usa siempre es candidata a estrategia dominante.
- Sonido: ruido emitido por superficie y postura; un cero absoluto contradice el pilar 2.

## 3. Informe
Salud: `NO EVALUADO` · `SANO` · `DUDAS` (atípicos que una TUNE arregla) · `CRÍTICO` (estrategia dominante o regla rota, que pide `/design`). Después: entradas usadas, atípicos, estrategias dominantes y valores que necesitan atención.

## 4. Proponer
Los cambios dentro de rango van en `docs/tasks/TUNE-XXX-slug.md` con `docs/tasks/_TUNE_TEMPLATE.md`, estado `propuesta`. Un cambio fuera de rango o de reglas va a `/design`.

## 5. Aplicar (solo con la TUNE aprobada por el usuario)
1. Edita los `.tres` indicados, solo los campos de la tabla.
2. Añade una línea por valor a `docs/gdd/balance-changelog.md`.
3. Ejecuta `./tools/ci/run_tests.sh`. Si falla un test que comprueba un valor literal, informa del test para corregirlo en otro paquete; el valor de la TUNE se queda.
4. Marca la TUNE como `aplicada`.
