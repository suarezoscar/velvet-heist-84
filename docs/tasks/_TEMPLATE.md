# FEAT-XXX — Título

- **Estado**: borrador | aprobada | en curso | hecha
- **Responsable**: <subagente>  **Revisor**: lead-architect
- **Fase del GSD**: <1-4>

## Objetivo
Qué problema resuelve y por qué ahora.

## Alcance y fuera de alcance
- Dentro:
- Fuera:

## Criterios de aceptación
| # | Criterio (medible) | Evidencia (test, JSON o captura) |
|---|---|---|
| 1 | | |

## Contratos
Señales, métodos públicos, recursos `.tres`, nodos y rutas, con nombres y tipos exactos.

## Assets necesarios
Nombre, dimensiones (m), pivote, triángulos máximos, materiales de la paleta, colisión `-col`.

## Impacto en red
Qué se replica, quién tiene autoridad, frecuencia.

## Reparto y orden
Qué hace cada subagente y qué puede ir en paralelo.

## Paquetes de ejecución
Uno por subagente y rama. Los redacta el planificador (Claude Code) para que el ejecutor (Antigravity) no tome decisiones de diseño. Si el ejecutor encuentra una ambigüedad, para y la reporta; no la resuelve por su cuenta.

### PKG-1 — <título>
- **Subagente / rama**: `<subagente>` / `feat/XXX-pkg1`
- **Archivos permitidos**: rutas exactas que puede crear o modificar (cualquier otro cambio es un bloqueante en `/review`).
- **Contratos**: firmas exactas que debe exponer o consumir.
- **Valores**: constantes y parámetros con su origen (`.tres`, tabla de la spec); el ejecutor no inventa números.
- **Tests obligatorios**: `tests/...::test_nombre` → criterio que cubre.
- **Comandos de cierre**: `./tools/ci/check_scripts.sh <archivos>` · `./tools/ci/run_tests.sh` · `./tools/ci/lint.sh`.
- **Fuera de alcance**: lo que no debe tocar aunque parezca relacionado.

## Riesgos y decisiones abiertas
