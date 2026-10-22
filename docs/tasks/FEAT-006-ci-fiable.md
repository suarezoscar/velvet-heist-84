# FEAT-006 — CI fiable

- **Estado**: hecha (2026-10-23)
- **Diseño**: `n/a — técnica`
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`

## Objetivo
La auditoría de la Fase 1 (`docs/decisions/2026-10-22-fase-1-auditoria.md`, grupo A) encontró que la Definición de hecho no se puede demostrar:
- `import.sh` sale con 0 aunque Godot informe de errores de importación.
- CI se salta los pasos del motor si no consigue instalar Godot.
- La versión de Godot está duplicada en `ci.yml`.
- La de Blender no está fijada.
- Los tests del validador de assets no se ejecutan en CI y no prueban el código de salida de la CLI.

Esta FEAT va primero porque todas las demás dependen de que "verde" signifique algo.

## Alcance y fuera de alcance
- Dentro:
  - `import.sh` falla ante errores en la salida de Godot.
  - Un script reutilizable que analiza logs de Godot.
  - Las versiones de Godot y Blender se leen de `tools/ci/*.env` en CI.
  - Comprobación de la versión de Blender en el validador.
  - Tests de la CLI del validador.
  - Los tests del validador se ejecutan en CI.
  - CI falla si falta Godot o Blender.
- Fuera:
  - Endurecer las comprobaciones del validador (paleta, tolerancias, snake_case): grupo E de la auditoría.
  - Hacer bloqueantes `lint --all` o `check_patterns --all`.
  - Cambiar `check_scripts.sh` o `run_tests.sh`.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | `scan_godot_log.sh` sale con 1 ante un log con `ERROR:`, `SCRIPT ERROR`, `Parse Error` o `Failed loading resource` (con o sin códigos de color ANSI), con 0 ante un log limpio y con 2 sin argumento o con un archivo inexistente | `tools/ci/qa_scan_godot_log.sh` (PKG-QA), exit 0 |
| 2 | `./tools/ci/import.sh` sale con 0 en `master` y su salida se sigue viendo en consola | Log de la ejecución en el informe de PKG-1 |
| 3 | `import.sh` sale con 1 si el log de Godot contiene un error | `qa_scan_godot_log.sh` cubre el analizador; `import.sh` lo invoca (revisión de código: `import.sh` llama a `scan_godot_log.sh` con el log completo) |
| 4 | `ci.yml` no contiene ningún número de versión de Godot ni de Blender: los lee de `tools/ci/godot_version.env` y `tools/ci/blender_version.env` | `grep -nE '4\.7\|5\.2' .github/workflows/ci.yml` sin resultados |
| 5 | CI falla si no hay Godot o si su versión no empieza por `GODOT_VERSION`, y lo mismo con Blender y `BLENDER_VERSION` | Revisión de `ci.yml` (pasos "Check Godot Executable" y "Check Blender Executable") |
| 6 | `validate_asset.py` y `test_validator.py` salen con 2 y un mensaje claro si la versión de Blender no coincide con `BLENDER_VERSION` | `test_validator.py::test_blender_version_mismatch` |
| 7 | La CLI del validador sale con 1 ante un asset que incumple y con 0 ante uno válido | `test_validator.py::test_cli_exit_code_fail` y `test_cli_exit_code_pass` |
| 8 | `./tools/ci/run_blender_tests.sh` ejecuta la suite del validador y propaga su código de salida (0 con todo en verde, ≠0 si falla un test o el script lanza una excepción) | Log en el informe de PKG-2, con 12/12 tests |
| 9 | Una ejecución de CI en `master` después del merge pasa en verde, incluidos los pasos de Blender | Enlace a la ejecución en la tabla de estado al cerrar la FEAT |

## Contratos

### `tools/ci/scan_godot_log.sh <log>` (nuevo)
- Quita los códigos ANSI con `sed 's/\x1b\[[0-9;]*m//g'`.
- Busca con `grep -nE 'ERROR:|SCRIPT ERROR|Parse Error|Failed loading resource'`.
- Si hay coincidencias, imprime `==> Errores en el log de Godot:` y las líneas encontradas (con su número), y sale con 1.
- Si no hay coincidencias, sale con 0 sin imprimir nada.
- Sin argumento, o si el archivo no existe, imprime el uso por stderr y sale con 2.

### `tools/ci/import.sh` (modificado)
- Ejecuta `godot --headless --import 2>&1 | tee "$LOG"`, con `LOG="$(mktemp)"` y `trap 'rm -f "$LOG"' EXIT`. El `set -o pipefail` que ya tiene conserva el código de salida de Godot.
- Captura el código de Godot sin abortar: `... || STATUS=$?`.
- Ejecuta después `"${SCRIPT_DIR}/scan_godot_log.sh" "$LOG" || STATUS=1`.
- Si `STATUS ≠ 0`, imprime `==> Error: la importación de Godot tiene errores.` y sale con 1. Si no, imprime `==> Godot import completed successfully.` como ahora.

### `tools/ci/blender_version.env` (nuevo)
```
# Versión exacta de Blender fijada para Velvet Heist '84
BLENDER_VERSION=5.2.2
BLENDER_SERIES=5.2
```
Origen: la versión instalada localmente (`blender --version` → `Blender 5.2.2 LTS`). La URL `https://download.blender.org/release/Blender5.2/blender-5.2.2-linux-x64.tar.xz` responde 200 (comprobado al escribir la spec).

### `tools/ci/run_blender_tests.sh` (nuevo)
```
blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/test_validator.py
```
- Lo ejecuta desde la raíz del proyecto (mismo patrón `SCRIPT_DIR`/`PROJECT_ROOT` que `import.sh`).
- Sale con el código de Blender.
- Imprime al final `==> Tests del validador en verde.` o `==> Error: fallan tests del validador.`

### `tools/blender_scripts/validate_asset.py` (modificado)
- Nueva función pública, sin efectos secundarios:
  ```python
  def check_blender_version(env_path: Path) -> Tuple[bool, str]
  ```
  - Lee la línea `BLENDER_VERSION=` de `env_path`.
  - La compara con `".".join(str(n) for n in bpy.app.version)`.
  - Devuelve `(True, "")` si coinciden. Si no, `(False, "Blender <actual>, se esperaba <fijada> (tools/ci/blender_version.env)")`.
  - Si el archivo o la línea faltan, devuelve `(False, "<motivo>")`.
- Constante:
  ```python
  BLENDER_VERSION_ENV: Path = SCRIPT_DIR.parent.parent / "tools" / "ci" / "blender_version.env"
  ```
- `main()` la llama antes que `parse_arguments()`. Si devuelve `False`, imprime `Error: <mensaje>` por stderr y sale con 2. El JSON de validación no cambia: sigue con las 8 comprobaciones.

### `tools/blender_scripts/test_validator.py` (modificado)
- `run_test_suite()` llama primero a `check_blender_version(BLENDER_VERSION_ENV)`. Si devuelve `False`, imprime el error y sale con 2.
- Tres tests nuevos, registrados en el mismo contador que los 9 actuales (total 12):
  - **`test_blender_version_mismatch`**:
    - escribe en un directorio temporal (`tempfile.TemporaryDirectory`) un `.env` con `BLENDER_VERSION=0.0.0`;
    - comprueba que `check_blender_version` devuelve `False` y que el mensaje contiene `0.0.0`;
    - comprueba que con un `.env` con la versión actual devuelve `True`.
  - **`test_cli_exit_code_fail`**:
    - monta la escena del test de nombres actual (un objeto con un espacio en el nombre);
    - la guarda con `bpy.ops.wm.save_as_mainfile(filepath=<tmp>/bad.blend)`;
    - escribe en `<tmp>/spec.json` la ficha que usa ese test;
    - ejecuta `subprocess.run([bpy.app.binary_path, "-b", "<tmp>/bad.blend", "--factory-startup", "-P", str(SCRIPT_DIR / "validate_asset.py"), "--", "<tmp>/spec.json"], timeout=120)`;
    - comprueba `returncode == 1`.
  - **`test_cli_exit_code_pass`**:
    - ejecuta `subprocess.run([bpy.app.binary_path, "-b", "--factory-startup", "-P", str(SCRIPT_DIR / "validate_asset.py"), "--", str(<raíz>/assets/models/wood_wedge.glb), str(SCRIPT_DIR / "specs/wood_wedge.json")], timeout=120)`;
    - comprueba `returncode == 0`. Origen: `tools/blender_scripts/reports/wood_wedge_validation.json` está en `pass`, y así se comprobó al escribir la spec.
- Actualizar la línea 9 del docstring para que nombre estos dos tests de la CLI.

### `.github/workflows/ci.yml` (modificado)
1. Quitar `GODOT_VERSION: "4.7.2"` del bloque `env`.
2. Primer paso tras "Checkout Code", **"Load Pinned Versions"**:
   ```
   grep -hE '^[A-Z_]+=' tools/ci/godot_version.env tools/ci/blender_version.env >> "$GITHUB_ENV"
   ```
3. "Check Godot Executable":
   - si `command -v godot` falla: `echo "::error::Godot no está instalado"` y `exit 1`;
   - si no, `godot --version | grep -q "^${GODOT_VERSION}"`, y si no coincide, `exit 1` con un mensaje `::error::`.
4. Pasos nuevos de Blender, después de "Step 3 - Run GUT Characterization Tests":
   - **"Install Blender System Libraries"** (siempre):
     ```
     sudo apt-get update && sudo apt-get install -y libxi6 libxxf86vm1 libxfixes3 libxrender1 libgl1 libegl1 libxkbcommon0 libsm6
     ```
   - **"Cache Blender"**: `actions/cache@v4`, `path: /opt/blender`, `key: blender-${{ env.BLENDER_VERSION }}`.
   - **"Install Blender ${{ env.BLENDER_VERSION }}"** (solo sin acierto de caché):
     ```
     curl -sLf "https://download.blender.org/release/Blender${BLENDER_SERIES}/blender-${BLENDER_VERSION}-linux-x64.tar.xz" -o /tmp/blender.tar.xz
     sudo mkdir -p /opt/blender
     sudo tar -xJf /tmp/blender.tar.xz -C /opt/blender --strip-components=1
     ```
   - **"Check Blender Executable"**:
     - `sudo ln -sf /opt/blender/blender /usr/local/bin/blender`;
     - `blender --version | head -1 | grep -q "Blender ${BLENDER_VERSION}"`, y si no coincide, `exit 1` con `::error::`.
   - **"Step 4 - Asset Validator Tests"**: `./tools/ci/run_blender_tests.sh`.
5. El resto de pasos, sin cambios.

## Assets necesarios
Ninguno.

## Impacto en red
Ninguno.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | integrator | `feat/006-pkg1` | — | integrado | 0 | Ejecutado por Claude tras 7 intentos de agy fallidos por permisos; PR #6 |
| PKG-2 | technical-artist | `feat/006-pkg2` | PKG-1 | integrado | 0 | PR #9 |
| PKG-QA | qa-engineer | `feat/006-pkgqa` | PKG-1 | integrado | 1 | Fixtures desde la salida real de import.sh; PR #11 |

Estados: `pendiente` → `en curso` → `entregado` → `revisado` (listo para merge) → `integrado` · `bloqueado` (espera al usuario).

## Paquetes de ejecución

### PKG-1 — Análisis de logs, versiones fijadas y CI estricto
- **Agente / rama**: `integrator` / `feat/006-pkg1`
- **Archivos permitidos**:
  ```allowed
  tools/ci/scan_godot_log.sh
  tools/ci/import.sh
  tools/ci/blender_version.env
  tools/ci/run_blender_tests.sh
  .github/workflows/ci.yml
  ```
- **Contratos**:
  - `scan_godot_log.sh`, `import.sh`, `blender_version.env`, `run_blender_tests.sh` y `ci.yml` exactamente como en la sección Contratos.
  - Los scripts nuevos empiezan por `#!/usr/bin/env bash`, una línea de comentario con su propósito y `set -euo pipefail`, como `check_scripts.sh`, y tienen permiso de ejecución (`git update-index --chmod=+x`).
- **Valores**: `BLENDER_VERSION=5.2.2` y `BLENDER_SERIES=5.2` (origen en Contratos). Los patrones de error salen de la sección Contratos; no añadas otros.
- **Tests**: ninguno propio; los de aceptación van en PKG-QA. `run_blender_tests.sh` puede fallar hasta que se integre PKG-2 si la suite no encuentra lo que espera: no es un bloqueo de este paquete, porque la suite actual (9 tests) ya pasa con este comando.
- **Comandos de cierre**:
  - `./tools/ci/import.sh` (debe salir con 0; pega las últimas 5 líneas)
  - `./tools/ci/scan_godot_log.sh` sin argumentos (debe salir con 2)
  - `./tools/ci/run_blender_tests.sh` (debe salir con 0, 9/9)
  - `grep -nE '4\.7|5\.2' .github/workflows/ci.yml` (sin resultados)
  - `./tools/ci/lint.sh` · `./tools/ci/check_patterns.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh`
- **Fuera de alcance**:
  - `check_scripts.sh`, `run_tests.sh`, `lint.sh` y `check_patterns.sh`.
  - Los pasos de lint, alcance y patrones de `ci.yml`.
  - Cualquier archivo de `tools/blender_scripts/`.

### PKG-2 — Versión de Blender y tests de la CLI del validador
- **Agente / rama**: `technical-artist` / `feat/006-pkg2` (sale de `master` con PKG-1 ya integrado)
- **Archivos permitidos**:
  ```allowed
  tools/blender_scripts/validate_asset.py
  tools/blender_scripts/test_validator.py
  ```
- **Contratos**: `check_blender_version`, `BLENDER_VERSION_ENV`, los cambios de `main()` y los tres tests, exactamente como en la sección Contratos. No cambies las 8 comprobaciones ni el formato del JSON.
- **Valores**:
  - la versión esperada se lee del `.env`, nunca de un literal en Python;
  - `0.0.0` es solo el valor del test de desajuste;
  - `timeout=120` en los subprocesos.
- **Tests**: los tres de la sección Contratos, dentro de `test_validator.py` (es la suite de este dueño). Total esperado: 12/12.
- **Comandos de cierre**:
  - `./tools/ci/run_blender_tests.sh` (12/12, sale con 0)
  - Ejecutar `blender -b --factory-startup -P tools/blender_scripts/validate_asset.py -- assets/models/wood_wedge.glb tools/blender_scripts/specs/wood_wedge.json; echo $?` → `0`
  - Ejecutar `python3 tools/ci/check_scope.py` · `./tools/ci/check_patterns.sh` · `./tools/ci/lint.sh`
- **Fuera de alcance**:
  - Las 8 comprobaciones del validador (umbrales, tolerancias, paleta).
  - `lib/palette.py`, las fichas y los informes JSON.

### PKG-QA — Tests de aceptación del análisis de logs
- **Agente / rama**: `qa-engineer` / `feat/006-pkgqa` (sale de `master` con PKG-1 ya integrado)
- **Archivos permitidos**:
  ```allowed
  tools/ci/qa_scan_godot_log.sh
  tests/fixtures/ci/godot_log_clean.log
  tests/fixtures/ci/godot_log_error.log
  tests/fixtures/ci/godot_log_error_ansi.log
  tests/fixtures/ci/godot_log_script_error.log
  tests/fixtures/ci/godot_log_parse_error.log
  tests/fixtures/ci/godot_log_failed_resource.log
  ```
- **Fixtures**:
  - **`godot_log_clean.log`**: copia las últimas 15 líneas de la salida real de `./tools/ci/import.sh` en `master`. No deben contener ninguno de los patrones.
  - Los otros cinco son el log limpio más una línea:
    - `godot_log_error.log`: `ERROR: Error importing 'res://assets/models/broken.glb'.`
    - `godot_log_error_ansi.log`: la misma línea envuelta en color, `\x1b[91mERROR: Error importing 'res://assets/models/broken.glb'.\x1b[0m`, con bytes ESC reales (escríbela con `printf`).
    - `godot_log_script_error.log`: `SCRIPT ERROR: Invalid call. Nonexistent function 'foo' in base 'Node'.`
    - `godot_log_parse_error.log`: `Parse Error: Unexpected "Indent" in class body.`
    - `godot_log_failed_resource.log`: `Failed loading resource: res://scenes/missing.tscn.`
- **Tests obligatorios** (`tools/ci/qa_scan_godot_log.sh`, bash, `set -euo pipefail`; cada caso imprime `PASS <nombre>` o `FAIL <nombre>`; el script sale con 1 si hay algún FAIL):

  | Caso | Entrada | Código esperado | Criterio |
  |---|---|---|---|
  | `clean` | `godot_log_clean.log` | 0 | 1 |
  | `error` | `godot_log_error.log` | 1 | 1, 3 |
  | `error_ansi` | `godot_log_error_ansi.log` | 1 | 1 |
  | `script_error` | `godot_log_script_error.log` | 1 | 1 |
  | `parse_error` | `godot_log_parse_error.log` | 1 | 1 |
  | `failed_resource` | `godot_log_failed_resource.log` | 1 | 1 |
  | `no_args` | sin argumentos | 2 | 1 |
  | `missing_file` | `tests/fixtures/ci/no_existe.log` | 2 | 1 |
  | `prints_line` | `godot_log_error.log` | la salida contiene `broken.glb` | 1 |

- **Comandos de cierre**: `./tools/ci/qa_scan_godot_log.sh` (todo PASS, sale con 0) · `python3 tools/ci/check_scope.py` · `./tools/ci/check_patterns.sh` · `./tools/ci/lint.sh`

## Cierre (2026-10-23)
- Criterio 9: CI en `master` tras integrar PKG-1 y PKG-2, en verde con los pasos de Blender (12/12): https://github.com/suarezoscar/velvet-heist-84/actions/runs/39865140278
- `/verify` en `master` (`1db3398`): import 0, check_scripts 0, run_tests 69/69, run_blender_tests 12/12, qa_scan_godot_log 9 PASS.
- `run_blender_tests.sh` y `qa_*.sh` añadidos a la regla 05 (la usa `/verify`).
- Hueco aceptado: la fixture ANSI no detecta un analizador que deje de quitar los colores, porque `ERROR:` aparece entero dentro del código de color.

## Riesgos y decisiones abiertas
- **Bibliotecas de Blender en el runner**: la lista de `apt` es la habitual para `blender -b` en Ubuntu. Si CI falla por una biblioteca que falta, es una vuelta de corrección de PKG-1: se añade el paquete que nombre el error.
- **Coste de CI**: la descarga de Blender (~350 MB) solo ocurre sin acierto de caché.
- **El criterio 9 lo cierra Claude**, no un paquete: tras integrar los tres paquetes, Claude registra el enlace de la ejecución en verde. Como no hay `gh` en local, el usuario puede pegar el enlace desde la pestaña Actions.
- **Al cerrar la FEAT**, Claude añade `run_blender_tests.sh` a la skill `/verify` y a la regla 05. Esos archivos son de Claude y quedan fuera de los paquetes.
