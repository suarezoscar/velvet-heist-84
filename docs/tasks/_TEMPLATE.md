# FEAT-XXX — Título

- **Estado**: borrador | aprobada | en curso | hecha | hecha parcialmente
- **Diseño**: `docs/gdd/systems/<sistema>.md` (aprobado) · o `n/a — técnica` si no cambia mecánicas, niveles ni balance
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master` (por defecto: los paquetes salen de ella y el usuario los integra ahí; una rama `feat/XXX-slug` solo si la FEAT debe llegar entera a `master` de una vez)

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
Nombre, dimensiones (m), pivote, triángulos máximos, materiales, colisión `-col` y origen (`procedural`, `polyhaven`, `mixamo`).

## Impacto en red
Qué se replica, quién tiene autoridad, frecuencia. Si toca red, la spec se escribe con la skill `netcode`.

## Estado de los paquetes
Lo actualiza Claude (`/dispatch`) en la copia principal; se commitea con el cierre de la FEAT.

| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | | `feat/XXX-pkg1` | — | pendiente | 0 | |
| PKG-QA | qa-engineer | `feat/XXX-pkgqa` | — | pendiente | 0 | |

Estados: `pendiente` → `en curso` → `entregado` → `revisado` (listo para merge) → `integrado` · `bloqueado` (espera al usuario).

## Paquetes de ejecución
Uno por agente y rama. Los redacta Claude para que el ejecutor no tome decisiones de diseño. Si el ejecutor encuentra una ambigüedad, para y la reporta (regla 00).

### PKG-1 — <título>
- **Agente / rama**: `<agente>` / `feat/XXX-pkg1`
- **Archivos permitidos**: CI rechaza cualquier archivo fuera de este bloque (`tools/ci/check_scope.py`). Un glob por línea; un archivo de otro dueño lleva `# excepción: <motivo>`.
  ```allowed
  src/entities/components/ejemplo_3d.gd
  ```
- **Contratos**: firmas exactas que debe exponer o consumir.
- **Valores**: cada número con su origen (`.tres` y campo, o tabla de esta spec); el ejecutor no inventa números.
- **Tests**: tests unitarios de los internos que escribe este agente. Los de aceptación van en PKG-QA.
- **Comandos de cierre**: `./tools/ci/import.sh` · `./tools/ci/check_scripts.sh <archivos>` · `./tools/ci/lint.sh` · `./tools/ci/check_patterns.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh`.
- **Fuera de alcance**: lo que no debe tocar aunque parezca relacionado.

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/XXX-pkgqa`
- **Archivos permitidos**:
  ```allowed
  tests/unit/test_ejemplo.gd
  ```
- **Tests obligatorios**: `tests/...::test_nombre` → criterio que cubre. Uno por criterio como mínimo, derivados de los contratos.
- **Comandos de cierre**: los de PKG-1, empezando siempre por `./tools/ci/import.sh` (cada paquete trabaja en un worktree nuevo sin `.godot/`).
- **Montaje de tests con física**: `position` antes de `add_child_autofree`; personajes al árbol antes de usar sus perfiles; `set_physics_process(false)` si el test simula a mano; ninguna pieza de escenario solapada con una cápsula.

## Riesgos y decisiones abiertas
