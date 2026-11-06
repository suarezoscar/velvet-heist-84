# Relevo — #177 Fase 2: kit modular del museo

## Hecho
- Prototipo por shader, sin tocar cajas, colisión ni navegación:
  - `museum_wall.gdshader`: familias pública, servicio, cámara y exterior, con un mapa de salas.
  - `museum_floor.gdshader`: mármol, espiga, moqueta, vinilo con franja y asfalto.
- Acabados en `data/visual/museum_finishes.tres` (`MuseumFinishes`) y `MuseumFinishBuilder`, que se llama desde `LevelDressingBuilder`.
- Capturas del prototipo enseñadas al usuario.

## Falta
- Lo que diga el usuario del prototipo.
- Piezas `.glb` en Blender:
  - marcos de puerta de los 35 pasos abiertos;
  - pilastras en esquinas y cruces;
  - rejillas;
  - marco de ventana;
  - puerta de la garita.
- Tests, lint y la documentación en `art_style.md`.

## Decisiones (grill-me P29–P42)
- Las piezas las hago yo con Blender.
- Las paredes siguen siendo las cajas de siempre, pintadas por shader.
- Solo la garita lleva hoja de puerta.
- Las piezas sobresalen como mucho 6 cm, sin colisión, y se recortan con los rayos X.

## Preguntas pendientes
- Visto bueno del prototipo.
