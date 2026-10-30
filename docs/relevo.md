# Relevo: #113 La E no acierta con puertas y piezas: elegir el objetivo en abanico

- **Rama**: `feat/113-interaccion-abanico` · **PR**: sin abrir · **Tarjeta**: En curso
- **Última herramienta**: Antigravity, 2026-10-30

## Hecho
- Issue, tablero y ramas abiertas revisados.
- Relevo tomado de opencode.
- Implementación de selección en abanico de 120° y 2 m (`Interactor3D`, `InteractionRules`, `interaction_rules.tres`).
- Contorno visual suave ámbar (`interaction_outline.gdshader`, `InteractionOutline3D`, escena aislada).
- Replicación y saneamiento de cursor en red (`NetSession`, `NetSessionClient`, `NetSessionServer`, `NetInputRules`).
- Primera revisión con subagente `reviewer`: identificados 2 bloqueantes (interacción a corta distancia/dentro del volumen de puertas y persistencia residual del cursor en servidor).
- Corregido Bloqueante 1: impacto interior tratado como distancia 0.0, evaluación de abanico hacia el interactuable y exclusión de la propia hoja/cuerpos hijos del target en `_is_behind_wall`.
- Corregido Bloqueante 2: saneamiento estricto a `Vector3.INF` sin fallback residual y reseteo inmediato de `interaction_cursor_position` tras procesar la acción de interactuar.
- Optimizada la asignación de formas y queries físicas en `Interactor3D._broad_phase`.
- Pruebas ampliadas en `test_interactor_door_fan.gd` (matriz de distancias cortas a 0.3, 0.5, 0.8 y 1.6 m) y `test_interactor_fan.gd` (restauración de proximidad y saneamiento).
- Archivos bajo el límite de 300 líneas y formateados con `gdformat`.

## Falta
- Confirmar aprobación del subagente `reviewer`.
- Borrar `docs/relevo.md` en el commit final previo a integrar.
- Abrir PR (`gh pr create`) con vinculación `Closes #113`.
- Validar CI en remoto e integrar en `master`.

## Decisiones tomadas
- Las partes del propio interactuable (como la hoja de una puerta con capa `LAYER_WALLS`) se excluyen del trazado de oclusión en `_is_behind_wall` para evitar que el interactuable se autooculte.
- El cursor de interacción es puramente efímero y se descarta en el servidor inmediatamente tras evaluar la interacción discreta.

## Preguntas pendientes al usuario
- Ninguna.
