---
name: dispatch
description: Lanza un paquete aprobado de una FEAT en Antigravity CLI (agy) en su propio worktree, encarga la revisión al subagente reviewer y gestiona hasta dos vueltas de corrección. Úsala cuando una spec esté aprobada y haya paquetes pendientes, o cuando /next proponga ejecutar uno.
---
# /dispatch — orquestar un paquete con agy

Uso: `/dispatch FEAT-XXX <N|qa>`.
- El script `tools/agy/dispatch.sh` es la fuente de verdad del comando del ejecutor, y su configuración está en `tools/agy/config.env`.
- Hay dos ejecutores:
  - `agy`, el de por defecto;
  - `opencode`, con el modelo `OPENCODE_MODEL` y los permisos de `tools/agy/opencode.json`. Se elige con `--executor opencode`.
- Con opencode, un comando denegado no corta la sesión: el resumen lo lista como aviso.
- Si `agy` se queda sin cuota, cambia a opencode.

## 1. Comprobar antes de lanzar
- La FEAT está `aprobada` y commiteada en su **rama de integración** (cabecera de la FEAT; por defecto `master`), que es la rama de la copia principal. Si falta el commit, hazlo tú: `docs(XXX): spec aprobada`, solo con la FEAT; es la ejecución de la aprobación del usuario. Si la FEAT usa una rama `feat/XXX-slug`, créala desde `master`, commitea ahí la FEAT y deja la copia principal en esa rama mientras dure.
- Si el repositorio ejecuta CI en ramas de paquete y la rama de integración no es `master`, publícala (`git push -u origin <rama>`).
- El paquete está `pendiente` y sus dependencias están `revisado` o `integrado`.
- Los paquetes que se lanzan en paralelo no comparten archivos en sus bloques `allowed`.

## 2. Lanzar
Ejecuta en segundo plano `tools/agy/dispatch.sh FEAT-XXX <N|qa> <agente>`; tarda minutos. Pon el paquete en `en curso` en la tabla de estado de la FEAT (copia principal).

## 3. Recibir la entrega
Al terminar, el script imprime el estado del ejecutor y el informe de entrega (regla 00).
- `bloqueado` o una ambigüedad: estado `bloqueado`; trasladas la pregunta al usuario tal cual.
- Avisos de permisos denegados: el ejecutor no pudo ejecutar algunos comandos; lo anotas y la revisión los ejecutará.
- `entregado`: estado `entregado` y sigues.

## 4. Revisar
Lanza el subagente `reviewer` en modo rama con: ruta del worktree, ruta de la FEAT y número de paquete. Si existe `PKG-QA` entregado, pídele que ejecute esos tests contra esta rama.
- `aprobado` → estado `revisado`. Publica la rama (`git push -u origin <rama>`) y abre el PR con el MCP `github` contra la rama de integración, con el resumen del paquete, la evidencia y el veredicto del revisor.
- `cambios requeridos` → guarda los bloqueantes en `.agy-runs/XXX-pkgN-revision-<vuelta>.md` y suma una vuelta. Con 2 vueltas o menos, relanza con `tools/agy/dispatch.sh FEAT-XXX <N> <agente> --feedback <ese archivo>`, con el mismo `--executor` que la vuelta anterior. A la tercera, estado `bloqueado` y entregas al usuario el informe del revisor.

## 4b. CI y merge
- Sigue el CI del PR. En verde: intégralo (método `merge`, con `expectedHeadSha`), sincroniza `master` local, borra la rama (local y remota) y su worktree, y avisa al usuario.
- En rojo: lee el log del job fallido (`get_job_logs`). Si el fallo es del paquete, guárdalo como bloqueante en `.agy-runs/XXX-pkgN-revision-<vuelta>.md` y cuenta una vuelta. Si es del entorno de CI, arréglalo en su propio PR o explícaselo al usuario. Nunca integres con el CI en rojo o pendiente.

## 5. Cerrar la FEAT
Cuando un paquete se integra, su estado pasa a `integrado`. Con todos integrados: `/verify` sobre la rama de integración, estado de la FEAT `hecha` y la FEAT con su tabla de estado final en un PR propio, que se integra con la misma regla de CI. Si la rama de integración no es `master`, abre también su PR a `master`.
