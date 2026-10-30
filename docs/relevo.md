# Relevo: #113 La E no acierta con puertas y piezas: elegir el objetivo en abanico

- **Rama**: `feat/113-interaccion-abanico` · **PR**: sin abrir · **Tarjeta**: En curso
- **Última herramienta**: Antigravity, 2026-10-30

## Hecho
- Issue, tablero y ramas abiertas revisados.
- Relevo tomado de opencode.
- Implementación de selección en abanico de 120° y 2 m (`Interactor3D`, `InteractionRules`, `interaction_rules.tres`).
- Contorno visual suave ámbar (`interaction_outline.gdshader`, `InteractionOutline3D`, escena aislada).
- Replicación y saneamiento de cursor en red (`NetSession`, `NetSessionClient`, `NetSessionServer`, `NetInputRules`).
- Ajustes de límites de 300 líneas en `player_base_3d.gd` y `net_session_server.gd`.
- Formato con `gdformat` y validación con `gdlint` en verde (0 errores).
- Pruebas unitarias de abanico, puertas y contorno en verde.
- Suite completa de GUT (389 tests) en verde.

## Falta
- Confirmar commits atómicos en español.
- Subir rama a origin.
- Revisión de seguridad y red con el subagente `reviewer`.
- Abrir PR con vinculación `Closes #113`.
- Validar CI en remoto e integrar en `master`.

## Decisiones tomadas
- Se respeta el diseño de abanico de 120° y alcance de 2,0 m centralizado en `data/balance/interaction_rules.tres`.
- La oclusión utiliza comprobación horizontal a altura de torso (`WALL_CHECK_HEIGHT = 1.0`) mediante `VisionLogic.wall_free` sobre `LAYER_WALLS`.
- El contorno visual es no destructivo (duplica instancias de mallas sólo para el cliente local) y se limpia inmediatamente al perder foco o cambiar de jugador.

## Preguntas pendientes al usuario
- Ninguna.
