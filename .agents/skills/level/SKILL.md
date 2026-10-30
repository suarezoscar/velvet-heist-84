---
name: level
description: Diseña o revisa un nivel de Velvet Heist '84 como datos (salas, puertas, rutas, botín, relojes, cámaras, superficies) listo para el generador de maquetas. Úsala al crear un mapa nuevo, rediseñar uno existente o revisar el flujo de infiltración de un nivel.
---
# /level — diseño de nivel como datos

La ejecuta `game-designer`. El resultado es `docs/gdd/levels/<nivel>.md` aprobado por el usuario y, cuando exista el formato, su recurso `data/levels/<nivel>.tres`. El usuario decora la maqueta generada; tú decides la distribución.

1. **Contexto**: lee `docs/gdd/pillars.md`, los documentos de `docs/gdd/systems/` que usa el nivel (botín, relojes, teléfonos, cámaras, sigilo) y, si es un rediseño, el nivel de partida (escena y su documento).
2. **Preguntas**: número de guardias de referencia (1v2 a 1v4), duración objetivo, fantasía del lugar y qué debe conservarse del nivel anterior.
3. **Esqueletos**: propón 2-3 distribuciones como diagrama ASCII de salas con sus compromisos (rutas, cuellos de botella, distancia a la salida). El usuario elige.
4. **Detalle**: escribe el documento con estas tablas, en metros reales y con muros en múltiplos de 2 m y puertas de 1,2 m:
   - Salas: id, tipo, rectángulo (x, z, ancho, fondo), suelo y su ruido.
   - Puertas: id, salas que une, posición, cerradura, si admite cuña.
   - Puntos de interés: botín (ligero o pesado, valor), Pieza Maestra, relojes de fichar, teléfonos (extensión), cámaras y monitores, luces apagables, escondites, aparición de cada bando, coche de huida.
   - Rutas: ruta crítica del ladrón y cada ruta alternativa, con su tiempo andando y su riesgo.
   - Patrullas: recorrido que imponen los relojes de fichar y su duración frente al ciclo de ronda.
5. **Comprobación**: pasa `references/level-checklist.md` y corrige hasta que no quede ningún punto en rojo.
6. **Datos**: el nivel es un JSON en `data/levels/` (`LevelData`; los construyen `LevelArchitectureBuilder`, `LevelEntitiesBuilder` y `LevelDressingBuilder`). Escribe o ajusta ese JSON desde las tablas.
7. **Aprobación**: resumen, puntos de la checklist en tensión y preguntas abiertas. Con el visto bueno del usuario, estado `aprobado`.

Hecho cuando: todas las tablas completas, la checklist sin puntos en rojo y el usuario ha aprobado.
