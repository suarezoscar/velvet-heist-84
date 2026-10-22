# TUNE-XXX — Título

- **Estado**: propuesta | aprobada | aplicada
- **Sistema**: `docs/gdd/systems/<sistema>.md`
- **Evidencia**: informe de `/balance`, de `/playtest` o datos de telemetría que la motivan

Una `TUNE` solo cambia valores de `.tres` dentro del rango que declara el documento del sistema. Un valor fuera de rango, o un cambio de reglas, es diseño: pasa por `/design`.

## Cambios
| Recurso `.tres` | Campo | Actual | Nuevo | Rango del documento | Motivo |
|---|---|---|---|---|---|

## Cómo sabremos si funcionó
Métrica de telemetría o pregunta de playtest que debería moverse, y en qué dirección.

## Verificación
- `./tools/ci/run_tests.sh` en verde. Si un test falla por comprobar un valor literal en vez de una relación, el test está mal: se reporta para corregirlo en otro paquete.
- Línea añadida a `docs/gdd/balance-changelog.md`.
