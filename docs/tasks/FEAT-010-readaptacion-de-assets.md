# FEAT-010 — Readaptación de assets: fichas para todos, colisión invisible y gadgets sin deformar

- **Estado**: aprobada (2026-10-23)
- **Diseño**: `n/a — técnica`. Decisiones del usuario del 2026-10-23:
  - pivotes por tipo;
  - presupuestos de 2.000 y 5.000 triángulos;
  - la ficha de los gadgets toma su tamaño real.
- **Revisor**: `reviewer` (Claude)
- **Rama de integración**: `master`
- **Depende de**: FEAT-009 (validador estricto, `validate_all.py`).

## Objetivo
Tras FEAT-009, 15 assets están en `pass`, pero quedan cuatro huecos.

**1. Colisión visible en el juego.** Godot conserva como malla visible lo que lleva sufijo `-col`; `-colonly` crea solo la colisión. Comprobado por Claude el 2026-10-23 instanciando los `.glb` en Godot:
- `escape_car_84` tiene una malla visible `Car` (su caja de colisión) que tapa el coche;
- lo mismo pasa con `SafeBox`, `wood_wedge` y `ceramic_vase_02-col`.

**2. Nueve `.glb` en uso sin ficha.** Los 7 de Poly Haven tienen:
- la escala sin aplicar (factor de unidades; las medidas sí son las reales según la API de Poly Haven);
- pivotes desplazados (`marble_bust` está a 0,81 m en X);
- hasta 35.100 triángulos;
- `grandfather_clock` arrastra una `Icosphere` auxiliar de 2 m y un armature.

  Los otros dos son procedurales: `cctv_camera_84` y `museum_display_case`. Sus `.glb` están desfasados: nombres con puntos y materiales que no son de la paleta. Su generador actual ya produce nombres y materiales válidos.

**3. Gadgets deformados.** `gen_gadgets_assets.py` escala cada eje para cuadrar con la ficha. Factores medidos: `stethoscope` Z ×0,50, `inspection_mirror` Z ×1,53, `tripwire_bell` X ×1,20, `alarm_clock` Y ×1,13.

**4. Pivotes sin tipo.** Hay assets que cuelgan (`chandelier`) o van en pared (`picture_frame`, `cctv_camera_84`). El validador solo conoce `bottom_center`.

## Alcance y fuera de alcance
- Dentro:
  - colisión `-colonly` en todos los assets;
  - tipos de pivote;
  - ficha y readaptación de los 9 assets;
  - gadgets sin escalado no uniforme;
  - `validate_all.py` falla ante un `.glb` sin ficha;
  - regla 02 actualizada (Claude, al aprobar).
- Fuera:
  - personajes (`assets/models/characters/`): van con la FEAT de personajes nuevos;
  - recolocar props en los mapas: los cambios de pivote son de pocos centímetros, salvo el reloj de pie, que pierde su esfera auxiliar;
  - `museum_level_builder_3d.gd` y sus escalas (`grandfather_clock` 0,85; `picture_frame` 0,9): se quedan como están;
  - aspecto artístico de las texturas.

## Reglas nuevas (valores de esta spec)
| Regla | Valor |
|---|---|
| Sufijo de colisión | `-colonly`. El validador rechaza cualquier objeto terminado en `-col` (check `collision_mesh`). |
| Tipos de pivote (`pivot` de la ficha) | `bottom_center`: como en FEAT-009. `top_center`: centro X/Y con la tolerancia XY de FEAT-009 y `abs(max_z) ≤ PIVOT_Z_TOL`. `back_center`: centro X y centro Z (vertical) con la tolerancia XY de FEAT-009 aplicada a sus ejes, y `min(abs(min_y), abs(max_y)) ≤ PIVOT_Z_TOL` (la cara trasera en el plano Y=0). |
| Check de pivote | Se renombra `pivot_bottom_center` → `pivot_position` |
| Presupuesto de triángulos | 5.000 en piezas protagonistas (`chandelier`, `grandfather_clock`, `marble_bust`); 2.000 en el resto de props |
| Reducción | Modificador Decimate (`COLLAPSE`) aplicado, con `ratio = 0.95 × presupuesto / triángulos actuales`; si aún se pasa, se repite multiplicando el ratio por 0,9, como máximo 5 veces |
| Colisión generada | Un cubo con la AABB visual, llamado `<name>-colonly`, solo si `collision: true` |
| `.glb` sin ficha | `validate_all.py` lo cuenta como fallo (`FAIL <name>: sin ficha`) en vez de aviso. Solo primer nivel de `assets/models/`. |

## Fichas de los 9 assets
Dimensiones en ejes de Blender (X ancho, Y fondo, Z alto), medidas por Claude el 2026-10-23. `source` de Poly Haven:
- `origin`: `polyhaven`;
- `url`: `https://polyhaven.com/a/<slug>`;
- `license`: `CC0`;
- `author`: tomado de la API de Poly Haven.

| `name` | `dimensions` | `pivot` | `max_triangles` | `materials` | `collision` | Origen (`slug` o generador) | `author` |
|---|---|---|---|---|---|---|---|
| `ceramic_vase` | [0.220, 0.221, 0.309] | bottom_center | 2000 | `["ceramic_vase_02"]` | true | `ceramic_vase_02` | James Ray Cock |
| `chandelier` | [0.746, 0.816, 0.798] | top_center | 5000 | `["basecolor_classic_chandelier_1", "lamps_classic_chandelier_1"]` | false | `Chandelier_01` | Kirill Sannikov |
| `grandfather_clock` | [0.626, 0.426, 2.191] | bottom_center | 5000 | `["vintage_grandfather_clock_01", "vintage_grandfather_clock_01_glass"]` | true | `vintage_grandfather_clock_01` | Yann Kervran, James Ray Cock |
| `marble_bust` | [0.272, 0.300, 0.515] | bottom_center | 5000 | `["marble_bust_01"]` | true | `marble_bust_01` | Rico Cilliers |
| `metal_office_desk` | [2.000, 0.917, 0.788] | bottom_center | 2000 | `["metal_office_desk"]` | true | `metal_office_desk` | Ulan Cabanilla |
| `picture_frame` | [0.661, 0.089, 0.771] | back_center | 2000 | `["fancy_picture_frame_02"]` | false | `fancy_picture_frame_02` | Rob Tuytel, Rico Cilliers |
| `security_tv` | [0.400, 0.350, 0.411] | bottom_center | 2000 | `["television_02"]` | true | `television_02` | Benny Weimer |
| `cctv_camera_84` | [0.180, 0.505, 0.300] | back_center | 2000 | `["BakeliteBlack", "CctvCasing", "CctvLed", "CctvLens", "Steel80s"]` | true | `tools/blender_scripts/gen_museum_assets.py` (procedural, `propia`, `velvet-heist-84`) | — |
| `museum_display_case` | [0.860, 0.860, 1.510] | bottom_center | 2000 | `["BrassGold", "CarpetWine", "GlassClear", "MahoganyWood"]` | true | `tools/blender_scripts/gen_museum_assets.py` (procedural, `propia`, `velvet-heist-84`) | — |

`feat` de estas fichas: `"FEAT-010"`. `description`: una frase en español que describa el objeto.

## Criterios de aceptación
| # | Criterio (medible) | Evidencia |
|---|---|---|
| 1 | Ningún `.glb` de primer nivel de `assets/models/` instancia en Godot una `MeshInstance3D` procedente de una malla de colisión: todas las colisiones son `-colonly` | `test_asset_import.gd::test_collision_meshes_are_invisible` (PKG-QA) |
| 2 | `collision_mesh` falla si existe un objeto `-col`, y pasa con `-colonly` | `test_validator.py::test_collision_suffix_*` |
| 3 | `pivot_position` aplica los tres tipos: cada tipo pasa con su pivote correcto y falla con el de otro tipo; un valor de `pivot` desconocido falla `spec_schema` | `test_validator.py::test_pivot_types_*` |
| 4 | Los 24 `.glb` de primer nivel tienen ficha y están en `pass`; `validate_all.py` sale con 0 y escribe 24 JSON | Salida de `validate_all.py` y `reports/` |
| 5 | `validate_all.py` sale con 1 ante un `.glb` de primer nivel sin ficha | `tools/ci/qa_validate_all.sh` (ampliado) |
| 6 | `gen_gadgets_assets.py` no escala ninguna malla: `normalize_and_apply_visuals` solo traslada. Las 5 fichas de gadgets tienen el tamaño medido del modelo sin deformar | Revisión del código y `validate_all.py` en 0 |
| 7 | Los 7 de Poly Haven parten de una copia intacta en `assets/models/raw/polyhaven/<name>.glb` (ignorada por Godot con `.gdignore`), y `adapt_polyhaven_assets.py` es idempotente: ejecutarlo dos veces da el mismo número de triángulos | Informe de PKG-1 (dos ejecuciones y conteos) |
| 8 | `grandfather_clock` no contiene `Icosphere` ni armature | `validate_all.py` (dimensiones de la ficha) y revisión |
| 9 | `test_assets_match_their_cards` recorre las 24 fichas y aplica el tipo de pivote de cada una | `test_asset_import.gd` |
| 10 | Las 24 previews cumplen la cobertura de FEAT-009 | `render_preview.py` en 0 y `qa_validate_all.sh` |
| 11 | Los mapas siguen importando sin errores ni referencias rotas | `./tools/ci/import.sh` en 0 y `run_tests.sh` en verde |

## Contratos

### `validate_asset.py`
- `PIVOT_TYPES = ("bottom_center", "top_center", "back_center")`. `spec_schema` exige que `pivot` sea uno de ellos.
- `check_pivot_position(visual_objects, spec)` sustituye a `check_pivot_bottom_center`, con nombre `pivot_position` en el JSON. Va en la misma posición de la lista de checks.
- `is_collision_object` reconoce `-col` y `-colonly`, para seguir excluyéndolos de la malla visual.
- `check_collision_mesh` falla si hay algún objeto cuyo nombre termina en `-col`, con detalle `usa '-col' (visible en Godot); renombra a '-colonly'`. Después aplica la regla de `collision` de la ficha con `-colonly`.

### `validate_all.py`
- Un `.glb` de primer nivel sin ficha se cuenta como fallo: imprime `FAIL <name>: sin ficha` y entra en el total `N/M`, donde M es el número de fichas más el de `.glb` sin ficha.
- Nuevo argumento `--models-dir <ruta>`, por defecto `assets/models/`: de ahí se leen los `.glb` de cada ficha y se buscan los `.glb` sin ficha.

### `lib/blender_utils.py` (nuevo)
Funciones compartidas por los generadores:
- `def decimate_to_budget(objects: list, budget: int) -> int`: aplica la regla de reducción sobre las mallas visuales y devuelve los triángulos finales.
- `def add_box_collision(objects: list, name: str) -> "bpy.types.Object"`: crea `<name>-colonly` con la AABB visual de `objects`.
- `def center_by_pivot(objects: list, pivot: str) -> None`: traslada todas las mallas (incluida la colisión) para cumplir el tipo de pivote. En `back_center` deja la cara trasera en el lado de Y que ya estaba más cerca de 0. Solo traslada, nunca escala.

`gen_core_assets.py` sustituye su `center_on_aabb` por `center_by_pivot(objs, "bottom_center")`.

### Generadores
- `gen_core_assets.py`, `gen_gadgets_assets.py` y `gen_museum_assets.py` nombran la colisión `<Prefijo>-colonly` en lugar de `-col`.
- `gen_gadgets_assets.py`: `normalize_and_apply_visuals(visual_objects)` pierde los parámetros `exp_x`, `exp_y` y `exp_z`, y solo aplica transformaciones y traslada a `bottom_center` (con `center_by_pivot`).
- `gen_museum_assets.py`:
  - aplica `decimate_to_budget(objs, 2000)` antes de exportar cada asset;
  - aplica `center_by_pivot`: `back_center` para la CCTV y `bottom_center` para la vitrina;
  - acepta nombres tras `--`, como `gen_core_assets.py`.

### `adapt_polyhaven_assets.py` (nuevo)
- Uso: `blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/adapt_polyhaven_assets.py -- [<name> ...]`. Sin nombres, los 7.
- Tabla interna `ASSETS: Dict[str, Dict]` con `pivot`, `max_triangles` y `collision` de cada asset, copiados de la tabla de fichas de esta spec.
- Para cada asset:
  1. Si no existe `assets/models/raw/polyhaven/<name>.glb`, copia ahí el `assets/models/<name>.glb` actual (`shutil.copy2`). Desde entonces, la fuente es esa copia y nunca se sobrescribe.
  2. Importa la copia y borra todo lo que no sea malla visual: armatures, `Icosphere`, colisiones existentes. Antes de borrar el armature, separa los hijos manteniendo su transformación (`parent_clear` con `CLEAR_KEEP_TRANSFORM`).
  3. Aplica transformaciones, `decimate_to_budget`, `center_by_pivot` y, si `collision`, `add_box_collision`.
  4. Exporta a `assets/models/<name>.glb` con los mismos ajustes de exportación que `gen_core_assets.py`. Los nombres de objetos y materiales visuales se conservan.
- Sale con 1 si algún asset supera su presupuesto tras la reducción.
- `assets/models/raw/polyhaven/.gdignore` (vacío): Godot no importa las fuentes.

## Assets necesarios
Los 24 `.glb` de primer nivel se regeneran o readaptan. No hay ninguno nuevo.

## Impacto en red
Ninguno.

## Estado de los paquetes
| PKG | Agente | Rama | Depende de | Estado | Vueltas | Notas |
|---|---|---|---|---|---|---|
| PKG-1 | technical-artist | `feat/010-pkg1` | FEAT-009 PKG-1 y PKG-2 | entregado | 0 | `bloqueado` previsto por tests antiguos; los adapta en la vuelta 1 |
| PKG-QA | qa-engineer | `feat/010-pkgqa` | PKG-1 | pendiente | 0 | |

## Paquetes de ejecución

### PKG-1 — Validador, generadores y readaptación
- **Agente / rama**: `technical-artist` / `feat/010-pkg1`
- **Archivos permitidos**:
  ```allowed
  tools/blender_scripts/validate_asset.py
  tools/blender_scripts/validate_all.py
  tools/blender_scripts/lib/blender_utils.py
  tools/blender_scripts/gen_core_assets.py
  tools/blender_scripts/gen_gadgets_assets.py
  tools/blender_scripts/gen_museum_assets.py
  tools/blender_scripts/adapt_polyhaven_assets.py
  tools/blender_scripts/specs/*.json
  tools/blender_scripts/reports/*_validation.json
  assets/models/*.glb
  assets/models/*.glb.import
  assets/models/*.jpg
  assets/models/*.jpg.import
  assets/models/*.png
  assets/models/*.png.import
  assets/models/raw/polyhaven/.gdignore
  assets/models/raw/polyhaven/*.glb
  assets/previews/*_iso.png
  assets/previews/*_iso.png.import
  tools/blender_scripts/test_validator.py  # excepción: adaptar los tests existentes a `pivot_position` y `-colonly`, sin añadir tests nuevos
  tests/unit/test_asset_import.gd  # excepción: adaptar `test_assets_match_their_cards` a los tipos de pivote, sin añadir tests nuevos
  ```
- **Pasos**:
  1. `./tools/ci/import.sh`.
  2. `lib/blender_utils.py`, luego `validate_asset.py` y `validate_all.py`, según los contratos.
  3. Generadores según el contrato. Ejecuta, uno detrás de otro:
     - `blender -b --factory-startup -P tools/blender_scripts/gen_core_assets.py`;
     - `blender -b --factory-startup -P tools/blender_scripts/gen_gadgets_assets.py`;
     - `blender -b --factory-startup -P tools/blender_scripts/gen_museum_assets.py`.
  4. Crea `assets/models/raw/polyhaven/.gdignore` (vacío) y `adapt_polyhaven_assets.py`. Ejecútalo dos veces y anota en el informe los triángulos de cada asset en ambas ejecuciones (deben coincidir).
  5. Fichas:
     - crea las 9 de la tabla;
     - en las 5 de gadgets, cambia solo `dimensions` por el tamaño medido: ejecuta `validate_all.py`, toma el valor `medido=` del detalle de `target_dimensions` de cada gadget y redondéalo a 3 decimales;
     - en las 15 de FEAT-009 no cambia nada más.
  6. `blender -b --factory-startup -P tools/blender_scripts/render_preview.py` (sale con 0).
  7. `blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/validate_all.py -- --reports-dir tools/blender_scripts/reports` (sale con 0; 24/24).
  8. `./tools/ci/import.sh`. Si aparecen texturas extraídas nuevas o desaparecen otras, `git add` / `git rm` de cada una por su ruta.
- **Reglas de ejecución**: sin comodines en ningún comando; un `git add` o `git rm` por ruta. Nada de MCP de Blender.
- **Tests**: `./tools/ci/run_blender_tests.sh` y `./tools/ci/run_tests.sh` en verde. Los tests existentes que fallen solo por el contrato nuevo se adaptan aquí, sin cambiar lo que prueban:
  - el nombre `pivot_position`;
  - las colisiones `-colonly`;
  - los tipos de pivote en `test_assets_match_their_cards`, con Godot Y = Blender Z y Godot Z = −Blender Y.

  Los tests nuevos los escribe PKG-QA.
- **Comandos de cierre**: `./tools/ci/import.sh` · `./tools/ci/check_scripts.sh` · `./tools/ci/lint.sh` · `./tools/ci/check_patterns.sh` · `python3 tools/ci/check_scope.py` · `./tools/ci/run_tests.sh` · `./tools/ci/run_blender_tests.sh` · el comando del paso 7.
- **Fuera de alcance**: escenas de `scenes/`, `src/`, personajes, `test_validator.py`, `tests/`.

### PKG-QA — Tests de aceptación
- **Agente / rama**: `qa-engineer` / `feat/010-pkgqa`
- **Archivos permitidos**:
  ```allowed
  tools/blender_scripts/test_validator.py  # excepción: los tests del validador viven junto a él
  tools/ci/qa_validate_all.sh
  tests/unit/test_asset_import.gd
  ```
- **Tests obligatorios**:
  - `test_validator.py`:
    - `test_collision_suffix_*` → crit. 2: falla con `Box-col` y pasa con `Box-colonly`, comprobando el check `collision_mesh`;
    - `test_pivot_types_*` → crit. 3, sobre una pieza de 0,25 m:
      - `top_center`: pasa con `max_z = 0`; falla con la pieza apoyada en Z=0;
      - `back_center`: pasa con `max_y = 0` y el centro vertical en 0; falla con la pieza apoyada en Z=0 y centrada en Y;
      - `bottom_center` falla con una pieza colgada (`max_z = 0`);
      - `pivot: "side"` falla `spec_schema`.
  - `test_asset_import.gd`:
    - `test_assets_match_their_cards` (adaptado en PKG-1): comprueba con una mutación que falla si una ficha `top_center` se valida como `bottom_center` → crit. 9;
    - nuevo `test_collision_meshes_are_invisible`: para cada `.glb` de primer nivel, ninguna `MeshInstance3D` tiene un nombre derivado de una colisión (termina en `-col`, `-colonly` o coincide con el nombre de un nodo `CollisionShape3D` o `StaticBody3D` hermano) → crit. 1.

      Antes de darlo por bueno, comprueba que fallaría contra un `.glb` con `-col`: usa `assets/models/raw/polyhaven/ceramic_vase.glb`, que conserva `ceramic_vase_02-col`, cargándolo por ruta con `GLTFDocument`, porque `.gdignore` impide importarlo. Ese caso va como test propio, `test_collision_check_detects_visible_col`.
  - `qa_validate_all.sh` → crit. 5: añade un paso que cree un directorio temporal con los `.glb` de las fichas más una copia de `wood_wedge.glb` llamada `orphan_asset.glb`, ejecute `validate_all.py -- --models-dir <temporal>` y espere 1 y la línea `FAIL orphan_asset: sin ficha`.
- **Comandos de cierre**: los de PKG-1, más `bash tools/ci/qa_validate_all.sh`.

## Riesgos y decisiones abiertas
- **Escalas del generador en `museum_level_builder_3d.gd`.** El reloj de pie se instancia a 0,85 y el cuadro a 0,9. Con el reloj sin la esfera de 2 m, el tamaño visible no cambia (la esfera no tenía material). Revisarlas jugando no entra en esta FEAT.
- **Parche actual en los mapas.** `HeistMap3D._hide_collision_helpers` oculta las mallas `-col`/`-colonly`. Además, `mansion_belmonte.gd` y `museum_velvet_84.gd` ocultan a mano `Car` y `marble_bust`, lo que confirma el problema. Con `-colonly` el parche sobra, pero no molesta. Quitarlo toca tus mapas, así que queda para otra FEAT.
- **Reducción del cuadro.** Pasa de 35.100 a 2.000 triángulos (ratio 0,054) y perderá molduras. A la escala de cámara del juego no debería notarse; la preview lo mostrará.
