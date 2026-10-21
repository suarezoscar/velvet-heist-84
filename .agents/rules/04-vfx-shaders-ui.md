---
trigger: model_decision
description: "Aplicar al crear shaders, VFX, decals, partículas, ondas de sonido, HUD o interfaz de usuario."
---
# VFX, shaders y UI

- Estética: años 80 analógico. Nada de aspecto sci-fi (los láseres son haces rojos gruesos).
- `SoundWave3D`: `QuadMesh` horizontal en Y = 0.05 con `ShaderMaterial` (`unshaded`, `depth_test_disabled`, `blend_add`), anillo SDF cuyo radio crece de 0 a `max_radius` con un Tween de 0.8 s. Se dispara desde `SignalBus.noise_emitted_3d`.
- Los shaders viven en `assets/shaders/` y se parametrizan con uniforms; sin valores fijos dentro del código del shader.
- Rendimiento: usar pooling para ondas, huellas (`Decal`) y partículas; no instanciar nodos cada frame; limitar el número de decals activos y documentar el límite en la spec.
- Cada VFX tiene una escena de prueba aislada para verlo sin jugar la partida.
- La UI solo escucha `SignalBus` o consulta componentes de forma reactiva; nunca modifica la lógica de juego. El HUD usa estética de casete, rueda de caja fuerte y dial.
