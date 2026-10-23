# FEAT-009 — Validador estricto, fichas y previews

- **Estado**: aprobada (2026-10-23; decisiones 1–4 según la propuesta)
- **Diseño**: `n/a — técnica`
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`

## Objetivo
La auditoría de la Fase 1 (`docs/decisions/2026-10-22-fase-1-auditoria.md`, grupo E) encontró que un asset "en `pass`" no garantiza la regla 02:
- el validador acepta materiales por nombre aunque sus valores no sean los de la paleta, y la lista `materials` de la ficha amplía en vez de restringir;
- las tolerancias tienen un mínimo de 1,5 cm, lo que en piezas pequeñas permite errores del 19 % al 37 %; el centrado admite 3,5 cm;
- ninguna ficha tiene el bloque `source` que exige la regla 02;
- las 13 previews son PNG transparentes (la cámara apunta fuera del modelo);
- hay dos carpetas de fichas (`data/asset_specs/` son enlaces simbólicos a `tools/blender_scripts/specs/`);
- solo 5 assets tienen JSON de validación;
- el test de Godot repite a mano las medidas en vez de leer las fichas.

Medición previa (Claude, 2026-10-23, sobre `master` `873f4f7`) de los 17 assets con ficha frente a las reglas nuevas:
- dimensiones y valores de paleta: los 17 exactos;
- centrado fuera de tolerancia: `safe_box_84` (Y 0,030 m), `time_clock_84` (X 0,020 m; Y 0,015 m) y `guard_pawn` (Y 0,010 m);
- nombres de objeto en PascalCase en 11 assets (`SafeBox_Mesh`…), que la regla 02 pone como ejemplo.

## Alcance y fuera de alcance
- Dentro:
  - validador estricto: esquema de ficha, `source`, paleta por valor, `materials` restrictiva, tolerancias reales y nombres;
  - `validate_all.py` y JSON de validación de todos los assets con ficha;
  - previews arregladas con comprobación de imagen vacía;
  - una sola carpeta de fichas;
  - centrado de `safe_box_84` y `time_clock_84`;
  - borrado de los assets sin uso;
  - test de Godot guiado por las fichas;
  - CI valida todos los assets.
- Fuera:
  - **FEAT-010** (readaptación de modelos, sin spec aún):
    - los 9 `.glb` en uso sin ficha (7 de Poly Haven, `cctv_camera_84`, `museum_display_case`), que incumplen escala, pivote o presupuesto;
    - quitar el escalado no uniforme de `gen_gadgets_assets.py` (factores medidos: hasta ×0,5 en Z en `stethoscope` y ×1,53 en `inspection_mirror`).
  - Fichas de los personajes Mixamo y `Soldier_body1.001`: van con la FEAT de personajes nuevos (`docs/gdd/systems/characters.md`), que los sustituye.
  - Renombrar objetos PascalCase a minúsculas (ver decisión 1).

## Reglas del validador (valores de esta spec)
| Constante (`validate_asset.py`) | Valor | Uso |
|---|---|---|
| `DIM_TOL_REL` | 0.01 | tolerancia de cada dimensión: `max(DIM_TOL_REL × esperada, DIM_TOL_MIN)` |
| `DIM_TOL_MIN` | 0.001 | m |
| `PIVOT_Z_TOL` | 0.002 | m; `abs(min_z)` de la AABB visual |
| `PIVOT_XY_TOL_REL` | 0.01 | centro X/Y de la AABB visual: `max(PIVOT_XY_TOL_REL × dimensión esperada del eje, PIVOT_XY_TOL_MIN)` |
| `PIVOT_XY_TOL_MIN` | 0.005 | m |
| `PBR_TOL` | 0.01 | por canal lineal de Base Color, y para Roughness, Metallic y Alpha (si la paleta define `alpha`) |
| `ASSET_NAME_RE` | `^[a-z0-9_]+$` | `name` de la ficha y nombre del `.glb` |
| `OBJECT_NAME_RE` | `^[A-Za-z0-9_]+(-col\|-colonly)?$` | cada objeto importado |
| `MATERIAL_NAME_RE` | `^[A-Za-z0-9_]+$` | cada material de las mallas visuales |
| `SOURCE_ORIGINS` | `("procedural", "polyhaven", "mixamo", "otro")` | `source.origin` |

`render_preview.py`: `PREVIEW_ALPHA_MIN` = 0.01 (un píxel cuenta si su alfa es mayor) y `PREVIEW_MIN_COVERAGE` = 0.02 (fracción mínima de píxeles que cuentan).

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | El check `spec_schema` falla si a la ficha le falta o tiene mal tipado cualquiera de `name` (cumple `ASSET_NAME_RE`), `dimensions` (lista de 3 números > 0), `pivot` (`"bottom_center"`), `max_triangles` (entero > 0), `materials` (lista no vacía de strings), `collision` (bool) o `source` (dict con `origin` en `SOURCE_ORIGINS` y `url`, `license`, `author` strings no vacíos) | `test_validator.py::test_spec_schema_*` (PKG-QA) |
| 2 | `target_dimensions` falla con un error del 1,5 % en una pieza de 0,08 m y pasa con 0,5 % | `test_validator.py::test_dimensions_tolerance_*` |
| 3 | `pivot_bottom_center` falla con la base a 3 mm de Z=0 o el centro X a 1 cm en una pieza de 0,25 m, y pasa con 1 mm y 2 mm | `test_validator.py::test_pivot_tolerance_*` |
| 4 | `palette_materials` falla si: un material no está en `materials` de la ficha; en un asset `procedural`, un material no es clave exacta de `PALETTE`; o su Base Color, Roughness o Metallic difiere de la paleta en más de `PBR_TOL`. Pasa con los valores exactos de la paleta. Un asset `polyhaven` con material fuera de la paleta pasa si está en `materials` | `test_validator.py::test_palette_*` |
| 5 | `snake_case_names` falla con un objeto `Bad Mesh`, `Mesh.001` o `mesh-0.3` y con un material `Steel80s.001`; pasa con `SafeBox_Mesh` y `SafeBox-col` | `test_validator.py::test_names_*` |
| 6 | `validate_all.py` valida cada ficha de `tools/blender_scripts/specs/` contra `assets/models/<name>.glb`, sale con 0 si todas pasan y con 1 si alguna falla o le falta su `.glb`; con `--reports-dir` escribe `<name>_validation.json` | `tools/ci/qa_validate_all.sh` (PKG-QA) y su salida en el informe |
| 7 | Los 15 assets con ficha están en `pass` y su JSON está en `tools/blender_scripts/reports/` | Los 15 JSON con `"pass": true`; `validate_all.py` sale con 0 |
| 8 | Las 15 previews (`assets/previews/<name>_iso.png`) tienen al menos un 2 % de píxeles con alfa > 0,01; `render_preview.py` sale con 1 si alguna no llega | Salida de `render_preview.py` en el informe de PKG-1; `qa_validate_all.sh` comprueba la cobertura |
| 9 | No existe `data/asset_specs/`; el validador ya no busca fichas ahí | `git ls-files data/asset_specs` vacío; `grep -n asset_specs tools/blender_scripts/*.py` vacío |
| 10 | `tests/unit/test_asset_import.gd` lee las fichas de `res://tools/blender_scripts/specs/` y comprueba para cada una, en Godot, tamaño, base, centrado y colisión con las tolerancias de esta spec; recorre al menos 15 fichas | `test_asset_import.gd::test_assets_match_their_cards` |
| 11 | CI ejecuta `validate_all.py` en el job de Blender y falla si sale con 1 | `tools/ci/run_blender_tests.sh` (revisión) y CI del PR de PKG-2 |
| 12 | Borrados sin referencias rotas: `guard_pawn`, `thief_pawn`, `museum_building_84`, `test_axis` y `vintage_flashlight` (con sus texturas, `.import`, previews, fichas y generadores) | `./tools/ci/import.sh` en 0; `grep -rn` de los cinco nombres en `src/ scenes/ tests/ tools/` vacío |

## Contratos

### Ficha (`tools/blender_scripts/specs/<name>.json`)
```json
{
  "name": "wood_wedge",
  "feat": "FEAT-004",
  "description": "Cuña de madera biselada para atrancar puertas bajo el marco.",
  "dimensions": [0.25, 0.08, 0.08],
  "pivot": "bottom_center",
  "max_triangles": 300,
  "materials": ["MahoganyWood"],
  "collision": true,
  "source": {
    "origin": "procedural",
    "url": "tools/blender_scripts/gen_gadgets_assets.py",
    "license": "propia",
    "author": "velvet-heist-84"
  }
}
```
`dimensions` en ejes de Blender: X ancho, Y fondo, Z alto. En Godot el tamaño es `Vector3(d[0], d[2], d[1])`.

### `source` de las 15 fichas
Todas `origin: "procedural"`, `license: "propia"`, `author: "velvet-heist-84"`. `url`:
- `tools/blender_scripts/gen_core_assets.py`:
  - `floor_carpet`, `floor_marble`, `floor_parquet`, `wall_mahogany`;
  - `safe_box_84`, `rotary_phone_84`, `time_clock_84`, `escape_car_84`;
  - `loot_cash`, `loot_masterpiece`.
- `tools/blender_scripts/gen_gadgets_assets.py`:
  - `alarm_clock`, `wood_wedge`, `stethoscope`, `inspection_mirror`, `tripwire_bell`.

### `validate_asset.py`
- Constantes de la tabla "Reglas del validador", a nivel de módulo.
- Checks, en este orden y con estos nombres en el JSON:
  - `spec_schema`;
  - `snake_case_names`;
  - `applied_transforms` (sin cambios);
  - `pivot_bottom_center`;
  - `target_dimensions`;
  - `triangle_budget` (sin cambios);
  - `palette_materials`;
  - `no_procedural_nodes` (sin cambios);
  - `collision_mesh` (sin cambios).
- Si `spec_schema` falla, el resto de checks se ejecuta igual con lo que haya; los que necesitan un campo ausente fallan con un detalle que lo dice.
- Se eliminan los alias `target_dimensions` / `triangles_budget` de la ficha, la forma dict de `dimensions`, la búsqueda en `data/asset_specs/` y el corte del nombre por `.` en materiales.
- `def validate_asset(asset_path: str, spec: Dict[str, Any]) -> Dict[str, Any]` mantiene firma y formato de salida (`asset`, `checks`, `pass`).

### `lib/palette.py`
- `is_material_in_palette` y `is_color_close` desaparecen (su único uso es el validador).
- Nueva función `check_material_against_palette(mat: "bpy.types.Material", key: str, tol: float) -> Tuple[bool, str]`:
  - compara el Principled BSDF de `mat` con `PALETTE[key]`: Base Color lineal por canal frente a `hex_to_linear_rgb`, Roughness, Metallic, y Alpha si la entrada tiene `alpha`;
  - `key` debe ser clave exacta (sensible a mayúsculas);
  - un material sin Principled BSDF falla.

### `validate_all.py` (nuevo)
- Uso: `blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/validate_all.py -- [--reports-dir <ruta>] [--specs-dir <ruta>]`. `--specs-dir` sustituye a `tools/blender_scripts/specs/` (lo usa PKG-QA para probar el fallo).
- Comprueba la versión de Blender igual que el validador (sale con 2).
- Recorre `sorted(specs/*.json)`; para cada ficha, `validate_asset(assets/models/<name>.glb, ficha)`.
- Si falta el `.glb`, es un fallo con check `execution`.
- Imprime una línea `PASS <name>` o `FAIL <name>: <checks fallidos>`, y al final `==> N/M assets en pass`.
- Lista, solo como aviso (`AVISO sin ficha: <name>`), los `.glb` de primer nivel de `assets/models/` sin ficha.
- Sale con 0 si todas pasan y con 1 si no.

### `render_preview.py`
- Cámara: rotación `(54.736°, 0, 45°)` y `cam_obj.location = center - forward × dist`, con `forward = cam_obj.rotation_euler.to_matrix() @ Vector((0, 0, -1))`. Comprobado por Claude: con esto `safe_box_84` cubre el 41,5 % de la imagen; con la cámara actual, el 0 %.
- Sin argumentos renderiza los `name` de todas las fichas de `specs/`.
- Tras cada render, carga el PNG y calcula la cobertura (`PREVIEW_ALPHA_MIN`, `PREVIEW_MIN_COVERAGE`), imprimiendo `PREVIEW <name> <cobertura %>`.
- Sale con 1 si alguna queda por debajo o si falta un `.glb` pedido.

### `gen_core_assets.py`
- `def center_on_aabb(objects: list) -> None`:
  - calcula la AABB de mundo de las mallas visuales (sin `-col` / `-colonly`) de `objects`;
  - desplaza los vértices de **todas** las mallas de `objects` (incluida la colisión) en `(-centro_x, -centro_y, -min_z)`;
  - deja `location`, `rotation_euler` y `scale` en identidad;
  - solo traslada, nunca escala.
- Se llama justo antes de exportar en `generate_safe_box` y `generate_time_clock`.
- `main()` acepta nombres tras `--` (`blender -b -P gen_core_assets.py -- safe_box_84 time_clock_84`) y genera solo esos; sin nombres, todos.
- Se borran `generate_thief_pawn` y `generate_guard_pawn` y sus llamadas.

## Assets necesarios
Ninguno nuevo. Se regeneran `safe_box_84.glb` y `time_clock_84.glb` (solo traslación; mismas dimensiones de ficha).

## Impacto en red
Ninguno.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | technical-artist | `feat/009-pkg1` | — | pendiente | 0 | |
| PKG-2 | integrator | `feat/009-pkg2` | PKG-1 | pendiente | 0 | |
| PKG-QA | qa-engineer | `feat/009-pkgqa` | PKG-1 | pendiente | 0 | |

## Paquetes de ejecución

### PKG-1 — Validador, fichas, previews y limpieza
- **Agente / rama**: `technical-artist` / `feat/009-pkg1`
- **Archivos permitidos**:
  ```allowed
  tools/blender_scripts/validate_asset.py
  tools/blender_scripts/validate_all.py
  tools/blender_scripts/lib/palette.py
  tools/blender_scripts/render_preview.py
  tools/blender_scripts/gen_core_assets.py
  tools/blender_scripts/gen_museum_level.py
  tools/blender_scripts/specs/*.json
  tools/blender_scripts/reports/*_validation.json
  data/asset_specs/*.json
  assets/models/safe_box_84.glb
  assets/models/time_clock_84.glb
  assets/models/guard_pawn.glb
  assets/models/guard_pawn.glb.import
  assets/models/thief_pawn.glb
  assets/models/thief_pawn.glb.import
  assets/models/test_axis.glb
  assets/models/test_axis.glb.import
  assets/models/museum_building_84*
  assets/models/vintage_flashlight*
  assets/previews/*_iso.png
  assets/previews/*_iso.png.import
  tests/unit/test_asset_import.gd  # excepción: quitar las entradas de guard_pawn y thief_pawn, que se borran
  ```
- **Pasos**:
  1. `./tools/ci/import.sh`.
  2. `palette.py`: contrato `check_material_against_palette`; borra `is_material_in_palette` e `is_color_close`.
  3. `validate_asset.py`: constantes, checks y eliminaciones del contrato.
  4. Añade `source` (tabla del contrato) a las 15 fichas sin tocar sus otros campos. Borra `specs/guard_pawn.json` y `specs/thief_pawn.json`.
  5. Borra con `git rm` los 17 enlaces de `data/asset_specs/`.
  6. `gen_core_assets.py`: contrato. Ejecuta `blender -b --factory-startup -P tools/blender_scripts/gen_core_assets.py -- safe_box_84 time_clock_84`.
  7. Borra con `git rm`:
     - `gen_museum_level.py`;
     - `assets/models/museum_building_84*` y `assets/models/vintage_flashlight*`;
     - `test_axis.glb`, `guard_pawn.glb` y `thief_pawn.glb`, con sus `.import`;
     - `assets/previews/guard_pawn_iso.png*` y `assets/previews/thief_pawn_iso.png*`.
  8. `tests/unit/test_asset_import.gd`: borra solo las claves `"thief_pawn.glb"` y `"guard_pawn.glb"` de `ASSET_EXPECTATIONS`.
  9. `render_preview.py`: contrato. Ejecuta `blender -b --factory-startup -P tools/blender_scripts/render_preview.py` (sale con 0).
  10. `validate_all.py`: contrato. Ejecuta `blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/validate_all.py -- --reports-dir tools/blender_scripts/reports` (sale con 0). Borra con `git rm` cualquier JSON de `reports/` cuyo asset ya no tenga ficha.
  11. `./tools/ci/import.sh` de nuevo: crea los `.import` de las previews nuevas y comprueba que no hay referencias rotas.
- **Valores**: tablas "Reglas del validador" y "`source` de las 15 fichas" de esta spec. Los números de las fichas no cambian.
- **Tests**: `./tools/ci/run_blender_tests.sh` debe seguir en verde sin tocar `test_validator.py`. Si falla un test existente, entrega `bloqueado` con la salida; no lo cambies.
- **Comandos de cierre**: `./tools/ci/import.sh` · `./tools/ci/check_scripts.sh` · `./tools/ci/lint.sh` · `./tools/ci/check_patterns.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh` · `./tools/ci/run_blender_tests.sh` · el comando de `validate_all.py` del paso 10.
- **Fuera de alcance**:
  - `gen_gadgets_assets.py` y los `.glb` de gadgets;
  - los 9 `.glb` sin ficha;
  - personajes;
  - renombrar objetos;
  - `test_validator.py`;
  - `tools/ci/`.

### PKG-2 — CI valida todos los assets
- **Agente / rama**: `integrator` / `feat/009-pkg2` (sale de `master` con PKG-1 integrado)
- **Archivos permitidos**:
  ```allowed
  tools/ci/run_blender_tests.sh
  ```
- **Cambio**: tras la suite del validador, `run_blender_tests.sh` ejecuta `blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/validate_all.py` (sin `--reports-dir`), propaga su código de salida con el mismo patrón `STATUS` del archivo e imprime `==> Error: hay assets que no pasan el validador.` o `==> Todos los assets con ficha en pass.`.
- **Comandos de cierre**: `./tools/ci/import.sh` · `./tools/ci/run_blender_tests.sh` · `python3 tools/ci/check_scope.py`.
- **Fuera de alcance**: `ci.yml` (ya llama a `run_blender_tests.sh`).

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/009-pkgqa` (sale de `master` con PKG-1 integrado)
- **Archivos permitidos**:
  ```allowed
  tools/blender_scripts/test_validator.py  # excepción: los tests del validador viven junto a él
  tools/ci/qa_validate_all.sh
  tests/unit/test_asset_import.gd
  tests/unit/test_asset_import.gd.uid
  ```
- **Tests obligatorios** (en `test_validator.py`, con el patrón `assert_check_fails` existente; añade un helper `assert_check_passes(check_name, title, setup_fn, spec)` para los casos que deben pasar; cada spec de test incluye `pivot` y `source` válidos salvo en los tests de esquema):
  - `test_spec_schema_*` → crit. 1: una ficha válida pasa `spec_schema`; fallan una sin `source`, una con `source.origin = "web"`, una con `source.license = ""`, una con `dimensions` de 2 elementos y una con `name = "Bad-Name"`.
  - `test_dimensions_tolerance_*` → crit. 2: cubo de 0,08 m de alto y ficha 0,08: con Z real 0,0812 (1,5 %) falla; con 0,0804 (0,5 %) pasa.
  - `test_pivot_tolerance_*` → crit. 3: pieza de 0,25 × 0,25 × 0,25: base en Z=0,003 falla y Z=0,001 pasa; centro X en 0,010 falla y 0,002 pasa.
  - `test_palette_*` → crit. 4:
    - pasan `Steel80s` con los valores de la paleta y un asset `polyhaven` con material `ceramic_vase_02` declarado en `materials`;
    - fallan:
      - `Steel80s` con Roughness 0,42 (paleta 0,40);
      - `Steel80s` con Base Color desplazado 0,02 en R;
      - `Steel80s` no listado en `materials`;
      - `steel80s` (minúsculas) en un asset `procedural`.
  - `test_names_*` → crit. 5: los cinco casos del criterio.
  - Los tests existentes siguen pasando; si alguno dependía de la laxitud anterior, lo adaptas al contrato nuevo y lo explicas en la entrega.
- **`tools/ci/qa_validate_all.sh`** → crit. 6 y 8:
  - ejecuta `validate_all.py` sobre el repo y espera 0;
  - copia `tools/blender_scripts/specs/` a un directorio temporal (`mktemp -d`) y añade una ficha `missing_asset.json` válida sin `.glb`;
  - ejecuta `validate_all.py -- --specs-dir <temporal>` y espera 1;
  - comprueba con Blender que cada `assets/previews/<name>_iso.png` de las fichas tiene cobertura ≥ 2 %.
- **`test_asset_import.gd`** → crit. 10:
  - sustituye `ASSET_EXPECTATIONS`, `test_all_key_assets_import_and_bounds` y `test_gadgets_assets_import_and_bounds` por `test_assets_match_their_cards`, que:
    - lista `res://tools/blender_scripts/specs/*.json` con `DirAccess`;
    - parsea cada ficha con `JSON.parse_string`;
    - comprueba con `assert_gte(count, 15)` que ha recorrido al menos 15;
    - aplica `_verify_asset` con tamaño Godot `Vector3(d[0], d[2], d[1])` y las tolerancias de esta spec (`DIM_TOL_*` para el tamaño, `PIVOT_Z_TOL` para la base, `PIVOT_XY_TOL_*` para el centro X/Z);
    - comprueba la colisión según `collision`;
  - los valores se declaran como constantes del test citando esta spec;
  - `test_character_models_proportions_and_bounds` no cambia.
- **Comandos de cierre**: `./tools/ci/import.sh` · `./tools/ci/check_scripts.sh` · `./tools/ci/lint.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh` · `./tools/ci/run_blender_tests.sh` · `bash tools/ci/qa_validate_all.sh`.

## Riesgos y decisiones abiertas
1. **Nombres de objeto.** La regla 02 dice "snake_case" pero pone como ejemplo `SafeBox_Mesh`, y 11 assets usan PascalCase. Lo que de verdad rompe referencias son los espacios y los puntos. Propuesta: permitir `[A-Za-z0-9_]` en objetos y materiales, exigir minúsculas solo en el nombre del asset y corregir el texto de la regla. La alternativa es renombrar los objetos de 11 assets y regenerarlos.
2. **Borrados.** No los usa ninguna escena, script ni test, salvo el propio test de importación en el caso de los *pawn*:
   - `guard_pawn` y `thief_pawn`: los sustituyen los personajes;
   - `museum_building_84` y su generador;
   - `test_axis`;
   - `vintage_flashlight`, de Poly Haven y recuperable.
3. **Pivote = centro de la AABB visual.** `safe_box_84` tiene el cuerpo centrado y el dial sobresale 3 cm por delante. Con esta regla el cuerpo se desplaza 3 cm hacia atrás y el asset se mueve 3 cm en los mapas que lo usan. Es imperceptible, pero toca escenas de `scenes/maps/` sin editarlas.
4. **Regla 02.** Al aprobar la spec actualizo la regla 02 y `asset-card.md`:
   - una sola carpeta de fichas;
   - la paleta remite a `lib/palette.py`, en vez de duplicar una tabla incompleta (le falta `ChromeTrim`, entre otras);
   - tolerancias nuevas;
   - bisel con `width ≤ 0,02 m` y `≤ 10 %` de la menor dimensión de la pieza.

   En el PR de cierre quito `data/asset_specs/**` de `ownership.yml`.
