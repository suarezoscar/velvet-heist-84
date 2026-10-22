---
name: dispatch
description: Lanza un paquete aprobado de una FEAT en Antigravity CLI (agy) en su propio worktree, encarga la revisión al subagente reviewer y gestiona hasta dos vueltas de corrección. Úsala cuando una spec esté aprobada y haya paquetes pendientes, o cuando /next proponga ejecutar uno.
---
# /dispatch — orquestar un paquete con agy

Uso: `/dispatch FEAT-XXX <N|qa>`. El script `tools/agy/dispatch.sh` es la fuente de verdad del comando de `agy`; su configuración está en `tools/agy/config.env`.

## 1. Comprobar antes de lanzar
- La FEAT está `aprobada` y commiteada en su **rama de integración** (cabecera de la FEAT; por defecto `master`), que es la rama de la copia principal. Si falta el commit, hazlo tú: `docs(XXX): spec aprobada`, solo con la FEAT; es la ejecución de la aprobación del usuario. Si la FEAT usa una rama `feat/XXX-slug`, créala desde `master`, commitea ahí la FEAT y deja la copia principal en esa rama mientras dure.
- Si el repositorio ejecuta CI en ramas de paquete y la rama de integración no es `master`, publícala (`git push -u origin <rama>`).
- El paquete está `pendiente` y sus dependencias están `revisado` o `integrado`.
- Los paquetes que se lanzan en paralelo no comparten archivos en sus bloques `allowed`.

## 2. Lanzar
Ejecuta en segundo plano `tools/agy/dispatch.sh FEAT-XXX <N|qa> <agente>`; tarda minutos. Pon el paquete en `en curso` en la tabla de estado de la FEAT (copia principal).

## 3. Recibir la entrega
Al terminar, el script imprime el estado de `agy` y el informe de entrega (regla 00).
- `bloqueado` o una ambigüedad: estado `bloqueado`; trasladas la pregunta al usuario tal cual.
- Avisos de permisos denegados: el ejecutor no pudo ejecutar algunos comandos; lo anotas y la revisión los ejecutará.
- `entregado`: estado `entregado` y sigues.

## 4. Revisar
Lanza el subagente `reviewer` en modo rama con: ruta del worktree, ruta de la FEAT y número de paquete. Si existe `PKG-QA` entregado, pídele que ejecute esos tests contra esta rama.
- `aprobado` → estado `revisado`. Avisa al usuario: rama lista para merge en la rama de integración.
- `cambios requeridos` → guarda los bloqueantes en `.agy-runs/XXX-pkgN-revision-<vuelta>.md` y suma una vuelta. Con 2 vueltas o menos, relanza con `tools/agy/dispatch.sh FEAT-XXX <N> <agente> --feedback <ese archivo>`. A la tercera, estado `bloqueado` y entregas al usuario el informe del revisor.

## 5. Cerrar la FEAT
Cuando el usuario integra un paquete, su estado pasa a `integrado`. Con todos integrados: `/verify` sobre la rama de integración, estado de la FEAT `hecha` y commit de la FEAT con su tabla de estado final. Si la rama de integración no es `master`, avisa al usuario para su merge a `master`. Después, con su permiso, borra los worktrees (`git worktree remove`) y las ramas de paquete.
