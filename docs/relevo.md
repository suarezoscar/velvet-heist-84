# Relevo — #186 niebla de guerra e iluminación noir

**Hecho**
- Prototipo de tres estilos de niebla (`style` en `assets/shaders/fog_of_war.gdshader`: 0 actual, 1 oscuridad, 2 plano en azul tinta con contorno por profundidad y normales).
- Luz noir probada solo desde la prueba de capturas: ambiente ×0,35, SDFGI ×0,5, luna ×0,7, borde 0,4 m.
- Página de comparación enviada al usuario: https://claude.ai/artifact/MWg7hGNaAb1UV2DsPSDETQ
- Inventario de luces: 38 Lamp3D, 2 linternas y 20 focos de cámaras cuentan para el sigilo; 20 focos de cuadros, 5 monitores y 4 cajas de puertas son decorado; 1 luna.

**Falta**
- Que el usuario elija el estilo.
- Después: valores en `.tres` (vision_rules, night_look), tratar las luces decorativas, actualizar R1 y R2 de vision.md, tests y capturas.

**Pendiente en «plano»**
- El contorno es denso en servicio.
- El tramado de rayos X sale con puntitos.
