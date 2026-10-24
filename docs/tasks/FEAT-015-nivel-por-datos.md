# FEAT-015 — Nivel por datos y maqueta gris del museo v2

- **Estado**: hecha (maqueta gris; el vestido con assets va en otra FEAT)
- **Diseño**: `docs/gdd/levels/museum_v2.md` (aprobado el 2026-10-24)
- **Hito del PoC**: H4
- **Rama**: `feat/015-nivel-por-datos`

## Objetivo
Construir el museo v2 desde un archivo de datos, para jugar la maqueta gris por internet y ajustar el plano antes de vestirlo con assets. El museo viejo se borra cuando la maqueta funcione en red.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | `data/levels/museum_v2.json` contiene las 16 zonas, las 24 puertas, la ventana V1, los tabiques, las coberturas, las lámparas por circuito, los interruptores, el botín, la caja fuerte, los 4 relojes, las 3 cámaras con sus monitores, el coche, las apariciones y las patrullas de §4–§8 del diseño | `tests/unit/test_level_data.gd` (recuentos e ids) |
| 2 | Los muros siguen los bordes de las salas sin duplicarse en los bordes compartidos, con un hueco del ancho de cada puerta en su posición | `test_level_builder.gd`: con un rayo a través de cada puerta no choca y a 1 m de ella sí |
| 3 | Cada suelo tiene `noise_multiplier` del `.tres` de su superficie (`data/balance/surface_*.tres`) | `test_level_builder.gd` |
| 4 | La colisión de muros mide 3,2 m. La vista solo es baja (1,2 m) en los muros que no son el perímetro norte ni oeste, para que la cámara isométrica vea dentro de las salas | `test_level_builder.gd` |
| 5 | `scenes/maps/museum_v2.tscn` (`HeistMap3D`) construye el nivel en `_ready` antes de buscar actores; el ladrón y los guardias aparecen en sus puntos y con sus patrullas | `test_level_builder.gd` y partida |
| 6 | Construir el nivel dos veces da los mismos nombres y rutas de nodos, que la red necesita en servidor y clientes | `test_level_builder.gd` |
| 7 | Se juega en red: servidor dedicado y dos clientes cargan `museum_v2` | Partida de prueba |

## Formato de `data/levels/*.json`
Coordenadas del diseño: x crece hacia el este y z hacia el sur, en metros. Godot = `(x + offset[0], y, z + offset[1])`.

```json
{
  "name": "museum_v2",
  "offset": [-24, -18],
  "wall": {"height": 3.2, "thickness": 0.3, "low_height": 1.2},
  "rooms": [{"id": "VES", "name": "Vestíbulo", "rect": [16, 26, 16, 10], "surface": "marble", "exterior": false}],
  "doors": [{"id": "P01", "a": "ALY", "b": "VES", "pos": [24, 36], "width": 2.4}],
  "windows": [{"id": "V1", "from": [34, 27], "to": [34, 29], "sill": 1.0}],
  "partitions": [{"id": "GW_tabique", "from": [3, 19], "to": [13, 19], "height": 2.4}],
  "covers": [{"id": "VES_mostrador", "pos": [20, 29], "size": [3.0, 0.8, 1.1], "rot_deg": 0, "kind": "counter"}],
  "lamps": [{"id": "C1_a", "pos": [20, 31], "type": "ceiling", "circuit": 1, "on": true}],
  "switches": [{"id": "SW_C1_P04", "pos": [24, 26.6], "circuit": 1}],
  "loot": [{"id": "L1", "pos": [5, 4], "name": "Escarabajo de oro", "value": 1500, "heavy": false, "masterpiece": false}],
  "safe": {"pos": [46, 12], "value": 3000},
  "clocks": [{"id": 1, "pos": [36, 24.2], "rot_deg": 0}],
  "cameras": [{"id": "CAM-1", "pos": [31.5, 26.5], "yaw_deg": 225}],
  "monitors": [{"camera": "CAM-1", "pos": [41.5, 25], "rot_deg": 90}],
  "car": {"pos": [3, 40], "rot_deg": 90},
  "spawns": {"thief": [8, 40], "guards": [[37, 26], [39, 26]]},
  "patrols": [[[37, 26], [33, 20]], [[39, 26], [44, 19]]]
}
```
- `surface`: `marble`, `wood_parquet`, `carpet`, `linoleum` o `asphalt`. Su multiplicador sale de `data/balance/surface_<id>.tres`; `asphalt` vale 1,0 si no existe.
- `exterior: true` (el callejón): suelo sin muros propios.
- `lamps.type`: `ceiling`, `desk` o `street`, que corresponden a `data/balance/lamp_<type>.tres`.
- `rot_deg` y `yaw_deg`: giro sobre Y en grados. 0 = mirando al norte (−Z); 90 = al este.
- `kind` de las coberturas: solo para el nombre y el color de la maqueta. La altura sale de `size[2]`.

## Riesgos y decisiones abiertas
- La maqueta gris usa cajas de colores. El vestido con assets CC0 (Loafbrr Interiors y piezas propias de Blender) es otra FEAT.
- Las patrullas del documento son recorridos largos; en la maqueta, la IA usa los puntos de `patrols` en línea recta. Si choca con muros, se añaden puntos intermedios.
