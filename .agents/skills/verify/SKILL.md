---
name: verify
description: Ejecuta las comprobaciones de la definición de hecho (importación, parseo de scripts, lint, tests, validador de assets) y produce un informe de evidencia con resultados reales. Úsala al terminar cualquier tarea, antes de pedir una revisión o dar algo por hecho, y cuando el usuario pida verificar, comprobar o validar el estado del proyecto.
---
# /verify — informe de evidencia

Lee `.agents/rules/05-verification.md` y busca los comandos reales en `tools/ci/`.

1. Lista los archivos cambiados (`git status` y `git diff --name-only`).
2. Ejecuta en este orden, solo lo que aplique a los cambios: importación headless, parseo de cada `.gd` modificado, lint, tests, validador de assets.
3. Si falta `tools/ci/` o el framework de tests, no improvises: indica qué piezas faltan y remite a `docs/tasks/FEAT-000-baseline.md`.
4. Nunca marques como superado un paso que no ejecutaste.

## Plantilla del informe
| Comprobación | Comando | Resultado | Notas |
|---|---|---|---|
| | | | |

- Criterios de la FEAT: cada uno con su evidencia (test, JSON, captura) o marcado como pendiente.
- Bloqueantes: lista, o "ninguno".
- Pasos no ejecutados y motivo.
