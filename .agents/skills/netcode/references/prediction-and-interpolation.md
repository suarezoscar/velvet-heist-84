# Predicción del actor local e interpolación de remotos

## Predicción y reconciliación (solo el actor local)
1. Cada tick de física el cliente aplica su input en local de inmediato, lo guarda en un búfer con su número de tick y lo envía al servidor.
2. El servidor simula ese input y responde con la posición canónica y el último tick procesado.
3. Al recibirla, el cliente descarta del búfer los inputs con tick ≤ confirmado, vuelve a la posición del servidor y reaplica los inputs pendientes.
4. Si la diferencia con lo predicho es pequeña, corrige suavemente en 100-200 ms; si supera un umbral, salta. El umbral evita temblores por microcorrecciones.
5. El búfer está acotado (unos 128 ticks).

La simulación de movimiento tiene que ser la misma función en cliente y servidor (misma velocidad, estamina y postura leídas del mismo `.tres`); si no, la reconciliación corrige todo el rato.

## Interpolación (actores remotos)
- Los snapshots llegan a 20 Hz y se dibuja a 60 FPS o más. Sin interpolación, los remotos saltan.
- Guarda el snapshot anterior y el actual con su marca de tiempo y mezcla en `_process` según el tiempo transcurrido entre ellos. La versión robusta dibuja unos 100 ms por detrás con un búfer de snapshots.
- La interpolación vive en `Visuals` (presentación); el nodo de simulación no se toca en el cliente.
- `Engine.get_physics_interpolation_fraction()` sigue los ticks de física, no los de red: no sirve para esto.

## Ancho de banda
- Solo lo necesario para reconstruir la presentación: posición, velocidad, rotación, postura (enum como int) y estado de animación.
- Continuos por canal no fiable; cambios de estado por fiable.
- Cuantizar floats (centímetros en enteros de 16 bits) si el ancho de banda lo pide.

## Comprobación
- [ ] Solo el servidor escribe propiedades sincronizadas.
- [ ] `set_multiplayer_authority()` se llama al instanciar, con el peer correcto.
- [ ] Remotos interpolados en `_process`; local predicho y reconciliado.
- [ ] Búfer de inputs acotado y umbral de reconciliación definido en la spec.
- [ ] El servidor valida todo golpe, captura y recogida; los clientes nunca se los atribuyen.
