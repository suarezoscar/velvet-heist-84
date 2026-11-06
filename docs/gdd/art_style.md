# Estilo artístico

Estado: en curso (bloque 6, fase 1 #181). Sustituye al estilo plano previsto en #148.

## Dirección
Cel-shading de cómic ochentero sobre una noche neo-noir de 1984: luz en tres bandas, contorno
negro y una paleta nocturna con neones. El tono sigue siendo neo-noir, no caricaturesco
(`pillars.md`, pilar 1): el cartoon está en el trazo, no en las proporciones ni en el humor.
Manda la legibilidad del sigilo: la niebla de guerra va encima de todo y lo que se ve o no se
ve tiene que leerse a la primera.

## Paleta
| Uso | Color |
|---|---|
| Noche, fondo | `#0b0e1a` |
| Noche, sombra | `#1b2140` |
| Muro oscuro | `#2e3666` |
| Muro iluminado | `#4a5590` |
| Piel | `#e0a98a` |
| Ropa | `#3a2e4f` |
| Neón rosa (ladrón, luz de borde) | `#ff3ea5` |
| Neón cian (guardias, luz de borde) | `#2ef2ff` |
| Alarma | `#ff3b30` |
| Lámpara ámbar | `#ffb627` |

Los valores viven en `data/visual/night_look.tres` (`NightLook`).

## Cómo se aplica
- **Luz**: `assets/shaders/cel_light.gdshaderinc`, tres bandas (luz, penumbra tintada, sombra).
  La sombra es la luz ambiente plana azul noche del `WorldEnvironment`.
- **Materiales**: `cel_toon.gdshader` (color, textura, mapa de normales, emisión con máscara y
  luz de borde Fresnel). `CelConverter` lo pone en lugar de cada `StandardMaterial3D` del mapa
  al cargarlo; ningún `.glb` se reexporta. Lo transparente, lo que no recibe luz y el grupo
  `no_cel` se quedan como están.
- **Muros**: `wall_xray.gdshader` comparte la luz cel y el recorte de WallXRay.
- **Contorno**: `outline.gdshader`, malla invertida como `next_pass`; las cajas se inflan hacia
  sus esquinas (`box_mode`) para que no se abran. Los suelos no llevan contorno.
- **Entorno**: `NightEnvironmentSetup` (`src/vfx/setup_environment.gd`): cielo synthwave procedural
  `night_sky.gdshader` sin texturas, SSR para suelos pulidos, SDFGI, glow suave y niebla volumétrica 0,015
  para el haz de las linternas. Luna fría con sombras.

## Kit del museo (#177, fase 2)
Las paredes siguen siendo las cajas de `LevelArchitectureBuilder`, así que la colisión, la vista, la navegación y los rayos X no cambian. Solo se pinta su superficie y se añaden piezas sueltas sin colisión.

**Paredes.** Las pinta `museum_wall.gdshader`. Al cargar el nivel, `MuseumFinishBuilder` genera desde el JSON un mapa de salas, con celdas de 0,25 m. Cada cara mira en ese mapa a qué sala da, y la sala decide su familia:

| Familia | Salas | Acabado |
|---|---|---|
| Pública | galerías, vestíbulo, despacho, biblioteca | zócalo, friso de caoba en paneles, moldura de latón y paño de color propio de la sala, a rayas suaves |
| Servicio | pasillos, taller, archivo, garita, vestuario, muelle | bloque gris cálido con juntas y franja ámbar de señalización |
| Cámara | cámara, joyas | paneles de acero con juntas y remaches |
| Exterior | callejón | bloque oscuro |

**Suelos.** Los pinta `museum_floor.gdshader` según la superficie que da el JSON a cada sala:

| Superficie | Dibujo |
|---|---|
| `marble` | ajedrezado con vetas |
| `wood_parquet` | espiga |
| `carpet` | rombos ochenteros con cenefa, con un color por sala |
| `linoleum` | baldosa con franja ámbar junto a las paredes |
| `asphalt` | asfalto con manchas |

**Piezas.** Salen de `tools/blender_scripts/gen_museum_kit.py` y las coloca `MuseumKitBuilder`:
- Un marco en cada paso, de familia `public`, `service` o `vault`. Si las dos salas son de familias distintas, gana la más fuerte: cámara, luego servicio, luego pública.
- Un dintel de muro sobre cada paso, a partir de 2,4 m.
- Pilastras de mármol en las esquinas y cruces que solo tocan salas públicas.
- El marco de la ventana de la garita.

Todas las piezas usan materiales de `WallXRay`: luz cel, contorno, y recorte delante del jugador local.

Los colores viven en `data/visual/museum_finishes.tres` (`MuseumFinishes`).

## Assets generados con IA
Cada asset lleva en su ficha herramienta, fecha, prompt y términos de uso de la herramienta, y
pasa el validador (medidas en metros, pivote en el suelo, frente hacia -Z).
