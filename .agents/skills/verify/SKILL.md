---
name: verify
description: Ejecuta las comprobaciones de la definición de hecho (importación, compilación de scripts, lint, patrones, alcance, tests, validador de assets) y produce un informe de evidencia con resultados reales. Úsala al terminar cualquier tarea, antes de entregar o revisar, y cuando el usuario pida comprobar el estado del proyecto.
---
# /verify — informe de evidencia

Lee `.agents/rules/05-verification.md`: fija los comandos y su orden.

1. Lista los archivos cambiados: `./tools/ci/changed_files.sh` (respecto a `master`, incluye lo no commiteado).
2. Ejecuta en orden las comprobaciones de la regla 05 que apliquen a esos cambios.
3. Copia el código de salida y las líneas clave de cada comando. Un paso que no se pudo ejecutar se informa con su motivo, nunca como superado.

## Plantilla del informe
| Comprobación | Comando | Código | Resultado | Notas |
|---|---|---|---|---|
| | | | | |

- Criterios de la FEAT: cada uno con su evidencia (test, JSON, captura) o marcado como pendiente.
- Bloqueantes: lista, o "ninguno".
- Pasos no ejecutados y motivo.
