---
trigger: always_on
description: "Protocolo de todo ejecutor: cómo leer, ejecutar y entregar un paquete PKG de una FEAT."
---
# Ejecución de paquetes

Trabajas sobre un paquete `PKG-N` de `docs/tasks/FEAT-XXX-slug.md`, en tu propio worktree y en la rama `feat/XXX-pkgN`. Empiezas sin historial: el paquete es tu único encargo.

## Pasos
1. Lee `AGENTS.md`, la FEAT completa (objetivo, contratos y tu paquete) y las reglas de `.agents/rules/` que nombre tu agente.
2. Ejecuta el paquete al pie de la letra:
   - Tocas solo los archivos de su bloque `allowed`. CI lo comprueba (`tools/ci/check_scope.py`).
   - Cada número sale del paquete o del `.tres` que cite. Si falta un valor, es una ambigüedad.
   - Las firmas, señales y recursos son exactamente los de "Contratos".
3. **Ambigüedad**: si el paquete no decide algo que necesitas (un valor, un nombre, un comportamiento, un archivo fuera de `allowed`), para. Entrega con estado `bloqueado` y describe la pregunta; la responde el planificador, no tú.
4. Ejecuta los comandos de cierre del paquete en orden y copia su salida real. Un comando que no pudiste ejecutar se informa como "no ejecutado: <motivo>", nunca como superado.
5. Haz commit en tu rama con mensaje `feat(XXX): PKG-N <resumen>`. El merge no es tuyo.

## Herramientas y comandos
Trabajas en modo headless: no hay nadie para aprobar permisos. **Un comando denegado termina tu sesión sin informe** y se pierde el trabajo de verificación.
- Escribe y edita archivos con tu herramienta de edición, nunca con comandos de shell (`echo >`, `cat <<EOF`, `sed -i`, `touch`, `rm`, `mv`, `cp`).
- Ejecuta solo:
  - los comandos de cierre del paquete, exactamente como están escritos y de uno en uno;
  - `git status`, `git diff`, `git show HEAD:<ruta>`, `git add`, `git rm`, `git update-index --chmod=+x` y `git commit`.
- No encadenes comandos (`;`, `&&`, `||`, `|`), no uses variables de shell ni `$(...)` y no escribas scripts de prueba ad hoc. Para comprobar algo, usa el comando de cierre que lo cubre.
- No compruebes el entorno (versiones, rutas, bibliotecas): el planificador ya lo hizo. Si un comando de cierre falla por el entorno y no por tu código, entrega con estado `bloqueado` y copia el error.
- Nunca cambies de rama, ni restaures archivos desde otra rama, ni hagas `push`.

## Informe de entrega
Tu último mensaje es exactamente este informe; el planificador lo lee de forma automática.

```
## Entrega PKG-N (FEAT-XXX)
Estado: entregado | bloqueado
Rama: feat/XXX-pkgN  Commit: <hash corto>
Archivos modificados:
- <ruta>
Comandos de cierre:
| Comando | Código de salida | Resultado (líneas clave copiadas) |
|---|---|---|
Criterios cubiertos: <números de criterio de la FEAT y dónde se demuestran>
Ambigüedades o bloqueos: <lista, o "ninguno">
```
