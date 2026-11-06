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
- **Entorno**: `NightEnvironmentSetup` (`src/vfx/setup_environment.gd`): cielo `.hdr`
  (procedural si falta), SSR para suelos pulidos, SDFGI, glow suave y niebla volumétrica 0,015
  para el haz de las linternas. Luna fría con sombras.

## Assets generados con IA
Cada asset lleva en su ficha herramienta, fecha, prompt y términos de uso de la herramienta, y
pasa el validador (medidas en metros, pivote en el suelo, frente hacia -Z).
