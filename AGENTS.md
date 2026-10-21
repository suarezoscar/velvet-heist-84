# VELVET HEIST '84 — MASTER GSD & MULTI-AGENT SPECIFICATION (v3.0)

> **Propósito de este documento:** Este archivo es la Fuente Única de Verdad (SSOT) para el entorno de desarrollo asistido por agentes (**Antigravity**). Contiene el Diseño de Juego (GSD), la Arquitectura Técnica en **Godot Engine 4.3+ (3D Ortográfico/Isométrico)**, el pipeline de generación de modelos 3D mediante **Blender MCP / Headless Python (`bpy`)** y los contratos estrictos entre agentes.

---

## 1. FICHA TÉCNICA Y CONCEPTO PRINCIPAL

| Atributo | Especificación |
| :--- | :--- |
| **Título del Proyecto** | Velvet Heist '84 (Terciopelo Negro) |
| **Género** | Sigilo táctico / Acción asimétrica multijugador (1 Ladrón vs 2-4 Guardias) |
| **Motor y Versión** | Godot Engine 4.7+ (Renderizador `Forward+`) |
| **Perspectiva y Cámara** | **3D Isométrico** (`Camera3D` en modo `PROJECTION_ORTHOGONAL`, inclinación `X: -35.264°`, rotación `Y: 45°`) |
| **Dirección de Arte** | *Low-Poly Stylized* años 80, materiales PBR limpios con aristas biseladas (`Bevel`), sombras duras proyectadas en tiempo real |
| **Ambientación** | Años 80 analógico (mansiones ostentosas, museos clásicos, bancos de época, estética *synth-jazz*) |
| **Pipeline de Assets** | 100% Código-a-3D vía **Blender MCP (`blender-mcp`)** y scripts Python (`blender -b -P`) exportados a `.glb` |

### 1.1. High Concept
Un juego multijugador asimétrico ambientado en 1984 donde **un Ladrón de guante blanco** debe infiltrarse en un recinto de alta seguridad, robar una cuota mínima de botín más una Pieza Maestra y escapar en su coche antes de que se agote el tiempo, mientras un equipo de **2 a 4 Guardias de seguridad** coopera para patrullar, detectar anomalías físicas y atraparlo.

### 1.2. Regla de Oro de Diseño: "Cero Alta Tecnología"
Queda estrictamente prohibido cualquier elemento de ciencia ficción o tecnología moderna (sin drones, sin hackeos digitales, sin radares automáticos ni invisibilidad óptica). Toda la interacción es **física, mecánica, analógica y táctil**: muelles, cerraduras, madera que cruje, polvo de talco, teléfonos de disco, cuñas de madera e interferencias de radio analógica.

---

## 2. ASIMETRÍA DE ROLES Y MECÁNICAS BASE

| Característica | El Ladrón (1 Jugador) | Los Guardias (2-4 Jugadores) |
| :--- | :--- | :--- |
| **Fantasía del Rol** | Elegante, calculador, no violento. Su arma es la anticipación, el oído y el ingenio mecánico. | Seguridad privada clásica de los 80. Fuerza numérica, control de zonas y comunicación por radio. |
| **Visión y Percepción** | **Visión 360° amplia.** Ve la geometría del mapa, los haces de luz de las linternas enemigas (`SpotLight3D`) y ondas visuales 3D de sonido a través de los muros. | **Cono de visión limitado** (linterna *Maglite* `SpotLight3D`) + radio corto de percepción periférica. El ladrón es invisible para el guardia si no está iluminado o en línea de visión directa (`RayCast3D`). |
| **Movilidad (`CharacterBody3D`)** | Alta. Camina en silencio, corre (generando ruido), se esconde dentro de armarios 3D o tras cortinas y usa conductos/ventanas. | Media. Correr drena estamina rápidamente y hace sonar el manojo de llaves y las botas pesadas. |
| **Interacción con el Mapa** | Forzar cerraduras con ganzúa, abrir cajas fuertes de combinación, desenroscar bombillas, llamar por teléfonos fijos de disco. | Cerrar puertas con llave maestra, encender interruptores (`OmniLight3D`), fichar en relojes de ronda mecánicos, tender trampas físicas. |
| **Condición de Victoria** | Robar la Pieza Maestra + alcanzar la cuota de dinero (ej. 10.000$) y llegar al punto de extracción. | Neutralizar al ladrón (2 impactos de porra / placaje cuerpo a cuerpo) o proteger el recinto hasta que acabe el reloj (8-10 minutos). |

---

## 3. ARSENAL ANALÓGICO: HERRAMIENTAS Y EQUIPO

Cada jugador selecciona su equipamiento en el lobby antes de comenzar la partida. Las estadísticas de cada herramienta residen en recursos `.tres` dentro de `res://data/balance/`.

### 3.1. El Maletín del Ladrón (Elección de 3 herramientas)
1. **Estetoscopio de Bolsillo (`stethoscope`):**
   - **Mecánica:** Al pegarse a una puerta cerrada o muro fino, duplica el radio en el que el ladrón percibe las ondas sonoras de pasos al otro lado (`multiplier = 2.0`). Al abrir cajas fuertes de combinación, amplifica el indicador visual y sonoro del "clic" correcto.
2. **Espejo de Dentista / Periscopio (`dentist_mirror`):**
   - **Mecánica:** Permite asomarse por esquinas o mirar por debajo de puertas cerradas desplazando el foco de cámara/visión hacia la sala contigua sin exponer el `CharacterBody3D` del ladrón.
3. **Polvera de Talco / Spray de Laca (`talc_spray`):**
   - **Mecánica:** Al pulverizarlo en una sala, revela de forma permanente los haces de luz infrarroja (láseres rojos gruesos ochenteros) cambiando la opacidad (`alpha`) de los cilindros láser de `0.02` a `0.85`.
4. **Cuñas de Madera y Cuerda de Piano (`wood_wedge`):**
   - **Mecánica:** Las cuñas bloquean físicamente puertas cerradas (obligando al guardia a interactuar/empujar 3 veces seguidas generando ondas de ruido altas). La cuerda permite derribar jarrones (`RigidBody3D`) o apagar lámparas a distancia.
5. **Despertador de Cuerda y Monedas (`windup_alarm`):**
   - **Mecánica:** Las monedas se lanzan describiendo un arco parabólico y emiten un impacto sonoro inmediato al tocar el suelo. El despertador se coloca en el suelo con un temporizador mecánico de `10.0s`; al expirar, vibra y emite ondas sonoras de radio `12.0m` durante `5.0s`.
6. **Bloque de Cera para Moldes (`wax_mold`):**
   - **Mecánica:** Si el ladrón permanece a menos de `1.2m` a la espalda de un guardia durante `2.0s` sin ser detectado, clona su llave maestra en cera, permitiendo abrir cualquier puerta con cerradura al instante sin minijuego de ganzúa.

### 3.2. El Cinturón de los Guardias (Equipo Base + 1 Especialidad)
- **Equipo Base (Todos los Guardias):**
  1. **Linterna Maglite (`SpotLight3D`):** Proyecta un cono de luz real con sombras dinámicas (`shadow_enabled = true`) que apunta hacia la posición del cursor en el plano 3D.
  2. **Porra de Madera:** Ataque cuerpo a cuerpo de corto alcance (`1.5m`). Dos impactos atrapan al ladrón.
  3. **Walkie-Talkie Analógico (Comunicación con Riesgo):** Cada vez que un guardia habla o envía un *ping* táctico a sus compañeros, su Walkie-Talkie emite un sonido de estática (`"Chssht-Bip"`) que genera una onda sonora de `6.0m` en el mundo 3D, delatando su posición ante el ladrón si está cerca.
- **Especialidades (Elegir 1 por Guardia):**
  1. **Silbato de Policía (`police_whistle`):** Al tener línea de visión con el ladrón, el guardia puede pitar para revelar la última posición 3D conocida del ladrón a todos los guardias durante `3.0s` y aplicarle el estado `"Nervioso"` (tiembla la interfaz de ganzúa).
  2. **Hilo de Pescar con Campanillas (`bell_tripwire`):** Permite colocar hasta 3 cables tensados (`Area3D`) en marcos de puertas o pasillos oscuros. Si el ladrón los cruza sin ir en modo sigilo/agachado o sin cortarlos, suenan estrepitosamente.
  3. **Bote de Polvo de Talco / Harina (`talc_powder`):** Esparce una mancha blanca (`Decal`) en entradas clave. Si el ladrón pisa el área, durante `15.0s` instancia `Decal` de huellas visibles cada paso que da.
- **Mecánica Anti-Camping — Relojes de Fichar (`time_clock`):**
  - Repartidos en extremos opuestos del mapa hay relojes mecánicos de pared. Los guardias deben acudir y girar su llave antes de que expire el ciclo de ronda (`90.0s`), evitando que se queden quietos vigilando únicamente la Pieza Maestra.

---

## 4. SISTEMAS DEL ENTORNO E INTERACCIÓN 3D

### 4.1. Acústica de Superficies
Cada módulo de suelo (`StaticBody3D`) incluye el metadato `noise_multiplier: float`. Un `RayCast3D` vertical en los pies de cada personaje lee este valor al caminar:
- **Alfombra Persa (`carpet`):** `noise_multiplier = 0.2` (Amortigua el 80% del ruido; permite trotar casi en silencio).
- **Parqué de Madera Vieja (`wood_parquet`):** `noise_multiplier = 1.5` (Cruje fuertemente a menos que se camine en modo sigilo con `Shift`).
- **Mármol / Baldosas (`marble`):** `noise_multiplier = 1.2` (Eco constante a velocidad normal y carrera).

### 4.2. Red de Teléfonos Fijos de Disco (`rotary_phone`)
- Cada sala principal cuenta con un teléfono fijo con un identificador de extensión (`@export var extension_id: int`, ej. `101`, `102`, `104`).
- Cuando el ladrón pasa cerca de un teléfono, registra su número en su libreta de UI. Desde cualquier otro teléfono del mapa puede marcar esa extensión para que el teléfono destino vibre y emita anillos sonoros en la otra punta del edificio.

### 4.3. Sistema de Peso del Botín
- **Botín Ligero (Joyas, fajos de billetes, relojes de oro):** Se guarda en el maletín sin penalización.
- **Botín Pesado (Cuadros al óleo, bustos de bronce, cajas de caudales):** Se acopla visualmente a las manos del ladrón (`CarryAnchor3D`), multiplica su velocidad de movimiento por `0.8` (`-20%`) e impide utilizar gadgets hasta que lo deposite en el suelo o en el coche de huida.

---

## 5. ARQUITECTURA TÉCNICA EN GODOT ENGINE 4.3+ (3D)

### 5.1. Árbol de Directorios Estandarizado
```text
res://
├── AGENTS.md                  # Instrucciones operativas para Antigravity
├── project.godot              # Configuración Godot 4.3 (Forward+)
├── docs/
│   └── MASTER_GSD.md          # Este documento de especificación
├── core/
│   ├── signal_bus.gd          # Autoload: Bus global de eventos tipados
│   ├── game_manager.gd        # Autoload: Estado de partida, reloj y cuota
│   └── net_manager.gd         # Autoload: ENetMultiplayerPeer, Host/Client y RPCs
├── data/
│   ├── balance/               # Recursos .tres (PlayerStats, GadgetStats)
│   └── loot_tables/           # Configuración de botín por semilla (seed)
├── assets/
│   ├── models/                # Archivos .glb generados por Blender MCP
│   ├── shaders/               # Shaders 3D (SoundWave, LaserBeam, WallCutaway)
│   └── audio/                 # SFX analógicos años 80 y synth-jazz
├── src/
│   ├── entities/
│   │   ├── player_base_3d.gd  # Movimiento XZ rotado 45°, RayCast3D de suelo
│   │   ├── thief/             # Controlador del Ladrón, ocultación y ganzúa
│   │   └── guard/             # Controlador del Guardia, SpotLight3D y porra
│   ├── gadgets/               # Clases modulares de herramientas analógicas
│   ├── systems/               # RotaryPhone3D, SafeBox3D, TimeClock3D, Door3D
│   ├── network/               # Spawners y sincronizadores de red
│   └── vfx/                   # SoundWave3D, FootprintDecal, Tweens
├── scenes/
│   ├── maps/                  # Niveles ensamblados (Mansion1984.tscn)
│   └── ui/                    # HUD años 80 (casete, rueda de caja fuerte, dial)
└── tools/
    └── blender_scripts/       # Scripts Python (bpy) para generación headless de .glb
```

### 5.2. Matemáticas de Cámara y Movimiento 3D Isométrico
Configuración de `Camera3D`:
```gdscript
projection = Camera3D.PROJECTION_ORTHOGONAL
size = 14.0
rotation_degrees = Vector3(-35.264, 45.0, 0.0)
```

Corrección del Vector de Movimiento (XZ):
El vector de entrada 2D (WASD) se convierte a `Vector3(input.x, 0.0, input.y)` y se rota 45° alrededor del eje `Vector3.UP` (Y) para que pulsar "Arriba" mueva al personaje hacia la diagonal superior de la pantalla:
```gdscript
var move_dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, deg_to_rad(45.0)).normalized()
```

Apuntado de Linterna / Mirada con el Ratón en 3D:
Se proyecta un rayo desde la cámara ortográfica hacia un plano matemático horizontal `Plane(Vector3.UP, global_position.y)` para obtener el punto exacto donde mira el personaje en el mundo 3D:
```gdscript
var drop_plane: Plane = Plane(Vector3.UP, global_position.y)
var mouse_pos: Vector2 = get_viewport().get_mouse_position()
var look_target: Variant = drop_plane.intersects_ray(camera.project_ray_origin(mouse_pos), camera.project_ray_normal(mouse_pos))
```

### 5.3. Sistema de Visibilidad y Sigilo 3D (Anti-Cheat Visual)
En los clientes de los Guardias, el nodo visual del Ladrón (`VisualRoot: Node3D`) permanece con `visible = false` por defecto.
En cada `_physics_process`, se comprueba si el Ladrón cumple alguna de estas dos condiciones respecto a cualquier guardia o lámpara encendida:
1. Está dentro de la distancia y el ángulo (`spot_angle`) de un `SpotLight3D` u `OmniLight3D` activo Y un `PhysicsRayQueryParameters3D` desde el origen de la luz hasta el torso del ladrón no choca con ningún muro (`collision_mask` de entorno).
2. Está dentro del radio de detección inmediata por proximidad (`1.8m`) de un guardia sin paredes de por medio.
Si se cumple, se interpola su visibilidad a `visible = true`.

### 5.4. Ondas de Sonido 3D (SoundWave3D)
Cuando se emite la señal `SignalBus.noise_emitted_3d(world_pos, max_radius, team)`, se instancia un `MeshInstance3D` con un `QuadMesh` orientado horizontalmente a `Y = 0.05`.
Utiliza un `ShaderMaterial` con `render_mode unshaded, depth_test_disabled, blend_add;` que dibuja un anillo SDF cuyo radio crece de `0.0` a `max_radius` mediante un `Tween` de `0.8s`, siendo visible a través de paredes y oscuridad.

### 5.5. Contratos del Bus de Señales (`res://core/signal_bus.gd`)
```gdscript
extends Node

# Acústica y Percepción 3D
signal noise_emitted_3d(world_position: Vector3, radius: float, source_team: StringName)
signal footprint_stepped_3d(world_position: Vector3, rotation_y: float)

# Interacción Analógica con el Entorno
signal rotary_phone_called(target_extension_id: int)
signal rotary_phone_answered(extension_id: int)
signal time_clock_punched(clock_id: int, guard_peer_id: int)
signal door_wedge_changed(door_id: int, is_wedged: bool)

# Estado del Golpe
signal loot_stolen(value: int, is_masterpiece: bool)
signal thief_spotted(last_known_position: Vector3)
signal thief_captured(guard_peer_id: int)
```

---

## 6. PIPELINE DE ARTE PROCEDURAL CON BLENDER MCP
Todo el arte 3D es generado por agentes usando Blender MCP (`blender-mcp`) o scripts Python ejecutados en modo headless (`blender -b -P <script.py>`).

### 6.1. Especificaciones Técnicas de Modelado para Godot 4
- **Escala Métrica:** 1.0 unidad en Blender = 1.0 metro en Godot.
- **Muros modulares:** 2.0m ancho x 3.0m alto x 0.2m grosor.
- **Marcos de puerta:** hueco de 1.2m ancho x 2.2m alto.
- **Personajes (cápsula):** 0.8m diámetro x 1.8m alto.
- **Pivote (Origin):** Siempre en la base inferior central del objeto (`Z = 0.0` en Blender, que se convierte en `Y = 0.0` en Godot al exportar con `+Y Up`).
- **Sufijos de Colisión Automática de Godot:**
  Todo objeto estático con colisión debe incluir en el archivo de Blender una malla simple con el sufijo `-col` (ej. `SafeBox_Mesh` + `SafeBox-col`). Al importar el `.glb`, Godot 4 crea automáticamente el `StaticBody3D` con su `CollisionShape3D`.
- **Paleta de Materiales PBR "Velvet '84":**
  - **MahoganyWood (Caoba):** Hex `#3B1E14`, Roughness = 0.35, Metallic = 0.0.
  - **BrassGold (Latón/Oro):** Hex `#D4AF37`, Roughness = 0.20, Metallic = 0.90.
  - **Steel80s (Acero Caja Fuerte):** Hex `#2B2D42`, Roughness = 0.40, Metallic = 0.80.
  - **VelvetBlack (Esmoquin Ladrón):** Hex `#16161A`, Roughness = 0.85, Metallic = 0.0.
  - **GuardNavy (Uniforme Guardia):** Hex `#1B263B`, Roughness = 0.65, Metallic = 0.1.
  - **BakeliteBlack (Teléfono/Walkie):** Hex `#111113`, Roughness = 0.15, Metallic = 0.05.
- **Geometría y Biselado:**
  Aplicar siempre un modificador `BEVEL` (`width = 0.02`, `segments = 2`) antes de exportar para que las aristas capturen los reflejos especulares de las linternas `SpotLight3D`.
- **Comando de Exportación Estándar (`bpy`):**
```python
bpy.ops.export_scene.gltf(
    filepath=output_glb_path,
    export_format='GLB',
    use_selection=False,
    export_apply=True,
    export_yup=True
)
```

---

## 7. ARQUITECTURA DEL SISTEMA MULTIAGENTE (ENFOQUE ANTIGRAVITY)
Para desarrollar el proyecto en Antigravity, el trabajo se divide en 6 agentes especializados con fronteras de archivos estrictas para evitar condiciones de carrera o corrupción de escenas `.tscn`.

| ID Agente | Rol | Responsabilidad Principal | Directorios Bajo Su Control |
| :--- | :--- | :--- | :--- |
| **@lead_arch** | Arquitecto Principal e Integrador | Vela por el cumplimiento del GSD, mantiene `project.godot`, `core/signal_bus.gd`, revisa el tipado estático GDScript y coordina las tareas. | `project.godot`, `core/`, `AGENTS.md`, `docs/` |
| **@asset_mcp** | Artista Técnico 3D (Blender MCP) | Se conecta a `blender-mcp` o ejecuta scripts bpy para modelar y exportar todos los `.glb` con materiales PBR y sufijos `-col`. | `tools/blender_scripts/`, `assets/models/` |
| **@gd_core3d** | Programador Gameplay & Sigilo 3D | Programa `CharacterBody3D`, cámara ortográfica, linterna `SpotLight3D`, `RayCast3D` de ocultación/suelo y lógica de gadgets. | `src/entities/`, `src/systems/`, `src/gadgets/` |
| **@tech_vfx** | Especialista en Shaders 3D, VFX & UI | Crea el shader de ondas sonoras 3D, Decal de huellas de talco, láseres infrarrojos, Tween procedurales y HUD años 80. | `assets/shaders/`, `src/vfx/`, `scenes/ui/` |
| **@gd_net** | Ingeniero de Red (Multiplayer API) | Configura `ENetMultiplayerPeer`, `MultiplayerSpawner`, `MultiplayerSynchronizer` y RPCs con autoridad en el servidor. | `src/network/`, `core/net_manager.gd` |
| **@game_des** | Diseñador de Sistemas y Niveles | Crea los recursos `.tres` de balanceo, tablas de botín y ensambla los mapas 3D modulares ("La Mansión de 1984"). | `data/`, `scenes/maps/` |

### 7.1. Reglas Operativas Globales para Todos los Agentes en Antigravity
1. **Tipado Estático Estricto en GDScript:** Ningún agente puede escribir variables, parámetros o funciones sin tipo explícito (`var radius: float = 5.0`, `func interact(actor: PlayerBase3D) -> void:`).
2. **Prohibición de Rutas Frágiles:** Prohibido usar `get_parent().get_parent()` o rutas absolutas hardcodeadas. Toda comunicación entre módulos desacoplados pasa por `SignalBus` o inyección mediante `@export`.
3. **Protección de Archivos `.tscn`:** Los agentes deben escribir toda la lógica compleja en scripts `.gd` y shaders `.gdshader`, manteniendo las escenas `.tscn` limpias y modulares.
4. **Verificación de Ejecución:**
   - Cuando `@asset_mcp` crea un script en `tools/blender_scripts/`, debe ejecutarlo vía CLI (`blender -b -P <script.py>`) y verificar que el archivo `.glb` se ha creado en `assets/models/`.
   - Cuando `@gd_core3d` o `@lead_arch` crean scripts GDScript, pueden validar la sintaxis ejecutando `godot --headless --quit` por consola.

### 7.2. Guía de Estilo, Modularidad y Buenas Prácticas (Clean Architecture)
Para asegurar que el proyecto sea legible, mantenible, escalable y fácilmente depurable, todos los agentes deben seguir estas directrices:

1. **Archivos Pequeños y Principio de Responsabilidad Única (SRP):**
   - Cada archivo `.gd` debe tener un propósito único y bien delimitado (idealmente entre 60 y 150 líneas, evitando superar las 200).
   - Separar comportamientos reutilizables en **componentes independientes** (por ejemplo, detección de superficies, conos de visión, o interactuadores) dentro de `src/entities/components/`.
2. **Separación Estricta de Conceptos (Separation of Concerns):**
   - **Lógica de Juego (Entidades):** No modifican nodos de UI directamente; emiten señales o actualizan su propio estado.
   - **Interfaz (UI / HUD):** Solo escucha señales del `SignalBus` o consulta de forma reactiva el estado de los componentes.
   - **Sistemas del Mundo (Cajas, Coches, Relojes):** Implementan contratos estándar de interacción (`can_interact()`, `get_interaction_text()`, `interact()`).
3. **Documentación y Comentarios Claros (en Español):**
   - Cada script debe comenzar con un docstring (`##`) resumiendo su responsabilidad y dependencias.
   - Usar la sintaxis de documentación nativa de Godot 4 (`##`) sobre clases, variables exportadas y funciones públicas para que aparezcan en el panel de ayuda del editor.
   - Comentar el *porqué* de las decisiones de diseño o algoritmos matemáticos complejos (como rotación isométrica a 45° o detección de conos de luz).
4. **Depurabilidad y Trazabilidad (Debuggability):**
   - Usar prefijos identificativos legibles al registrar información en consola cuando sea necesario (ej. `[SafeBox3D]`, `[ThiefController3D]`).
   - Validaciones defensivas tempranas con `assert()` o salidas tempranas (`guard clauses`) para evitar estados nulos o desincronizados.
   - Separar las constantes mágicas en constantes con nombre explícito (`const INTERACTION_DISTANCE: float = 1.8`).

---

## 8. HOJA DE RUTA DE IMPLEMENTACIÓN (BACKLOG ORDENADO PARA ANTIGRAVITY)
Antigravity debe abordar el desarrollo siguiendo secuencialmente estas 4 fases:

### Fase 1: Cimientos 3D, Cámara Ortográfica y Primeros Modelos .glb
- [x] **@lead_arch**: Inicializar `project.godot`, `core/signal_bus.gd` y `core/game_manager.gd`.
- [x] **@asset_mcp**: Crear y ejecutar `tools/blender_scripts/gen_core_assets.py` para generar:
  - Módulos de suelo (`floor_carpet.glb`, `floor_parquet.glb`, `floor_marble.glb`) y muro (`wall_mahogany.glb`).
  - Cápsulas estilizadas del Ladrón (`thief_pawn.glb`) y Guardia con linterna (`guard_pawn.glb`).
  - Props interactivos: `safe_box_84.glb` y `rotary_phone_84.glb` con sus mallas `-col`.
- [x] **@gd_core3d**: Implementar `PlayerBase3D`, `ThiefController3D` y `GuardController3D` con cámara ortográfica a 45°, apuntado al cursor en el plano XZ, linterna `SpotLight3D` con sombras reales y sistema de visibilidad condicional por `RayCast3D`.
- [x] **@tech_vfx**: Implementar el shader y escena `SoundWave3D` para visualizar los pasos según el multiplicador de ruido del suelo.

### Fase 2: Interacción Analógica y Bucle de Partida Local (1 vs N)
- [x] **@gd_core3d**: Implementar `SafeBox3D` (con rueda de combinación), `LootItem3D` (con distinción entre botín ligero y pesado -20% velocidad) y zona de extracción (`EscapeCar3D`).
- [x] **@gd_core3d**: Implementar captura cuerpo a cuerpo del guardia con la porra y relojes de fichar mecánicos (`TimeClock3D`).
- [ ] **@gd_net**: Configurar lobby LAN con `ENetMultiplayerPeer`, `MultiplayerSpawner` y sincronización de posiciones, ángulos de linterna y estados de robo.

### Fase 3: El Maletín y el Cinturón (Gadgets de los Años 80)
- [ ] **@asset_mcp**: Generar los modelos `.glb` de herramientas: despertador de campana (`alarm_clock.glb`), cuña de madera (`wood_wedge.glb`), estetoscopio (`stethoscope.glb`), espejo (`mirror.glb`) y trampa de campanillas (`tripwire.glb`).
- [ ] **@gd_core3d + @tech_vfx**: Programar la red de teléfonos fijos de disco por ID de extensión, las huellas temporales de polvo de talco (`Decal`), la revelación de láseres infrarrojos con spray de laca y la emisión de ruido al usar el Walkie-Talkie.

### Fase 4: Nivel Completo "La Mansión de 1984" y Pulido
- [ ] **@game_des**: Ensamblar el mapa `Mansion1984.tscn` con múltiples rutas de infiltración, ubicaciones aleatorias de botín por seed, cajas de fusibles y ajuste de balanceo en `res://data/balance/*.tres`.
- [ ] **@tech_vfx**: Crear la interfaz de selección de equipamiento pre-partida con estética de cinta de casete y planos analógicos de los años 80.
