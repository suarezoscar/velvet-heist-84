# Roadmap del PoC (2026-10-23)

- **Estado**: aprobado por el usuario el 2026-10-23.
- **Tablero**: https://claude.ai/artifact/NqbvqYvbiGu1h2CNEngtfC (privado; Claude mueve las tarjetas al lanzar, revisar e integrar).

## Por qué
Hasta FEAT-012 el trabajo se centró en afinar las reglas de sigilo: percepción, luz y ruido. Mientras tanto, el riesgo principal del juego sigue sin probar: si una partida asimétrica de 1 ladrón contra 2 guardias humanos es divertida. El online tiene una regresión abierta y nadie ha jugado una partida real.

## Meta y criterio de salida
**3 personas juegan 5 partidas seguidas en el museo (1 ladrón contra 2 guardias, en LAN), con arte provisional, y quieren jugar la sexta.**

El PoC termina con un playtest (`/playtest`) que cumple esa frase o que explica por qué no.

## Hitos
Van en orden; cada uno se apoya en el anterior.

| Hito | Contenido | Hecho cuando |
|---|---|---|
| H1 Cerrar FEAT-012 | Audio de ruido, vúmetro, exposición y silueta | FEAT-012 `hecha` y aprobada al jugarla (criterio 14). Las mecánicas de sigilo quedan congeladas hasta el playtest |
| H2 Red mínima | Servidor autoritativo recortado (paquete F) para 1 contra 2 en LAN: movimiento, percepción, ruido, golpe, botín y visibilidad del ladrón filtrada por guardia | 3 equipos en LAN juegan una partida completa sin desincronizar y sin que un guardia vea lo que no debe |
| H3 Bucle de partida | Entrar, robar, escapar o ser capturado; fin de ronda, resultado y revancha; lobby por IP con elección de bando (reutiliza FEAT-003) | Se juegan 5 rondas seguidas sin reiniciar el juego |
| H4 Legibilidad | Quién es quién y hacia dónde mira; lámparas e interruptores en el museo | En una captura a 1080p se distingue cada personaje, su bando y su orientación |
| H5 Playtest | 3 personas y 5 partidas; informe con `/playtest` | Informe con hallazgos clasificados y una decisión: seguir, ajustar o cambiar |

## Cómo trabajamos durante el PoC
- **Lo que es "sensación"** (aspecto, sonido, HUD) se prueba primero con un prototipo rápido y desechable en una rama, y el usuario lo ve antes de escribir la spec. Así se evita lo que pasó con los anillos, que recorrieron el circuito completo para acabar descartados.
- **Lo que es una regla o un sistema** sigue el flujo normal: spec, agy, `reviewer`, PR y CI.
- **El avance se mide en días hasta la primera partida online real**, no en FEAT cerradas.

## Aparcado hasta después del PoC
- personajes con animaciones de Mixamo (incluida la de sujetar la linterna);
- rehacer la geometría del estetoscopio;
- lámparas en la mansión;
- quitar el parche `_hide_collision_helpers`;
- tests honestos (grupo C);
- refactor de `validate_asset.py` y `test_validator.py`;
- telemetría;
- bot ladrón;
- gadgets, disfraz y walkie;
- muestras de audio propias (caja fuerte, coche, reloj, walkie);
- subtítulos de ruido para accesibilidad;
- migrar el tablero a GitHub Projects.

Si un aparcado resulta imprescindible para la meta (por ejemplo, si los personajes no se leen sin animación en H4), entra en el PoC con la aprobación del usuario.

## Cambio de método (2026-10-24)
A petición del usuario, desde el 2026-10-24 todo lo hace Claude: Opus en la sesión principal para lo pesado y subagentes Sonnet para lo rápido. Se retiran agy, opencode, `dispatch.sh`, el control de propiedad por agente (`ownership.yml`, `check_scope.py`), los paquetes cerrados por agente, el paquete QA aparte y los PR solo de documentación. Las FEAT pasan a ser notas cortas y `reviewer` solo revisa los cambios con riesgo. Detalle en `AGENTS.md` y `CLAUDE.md`.

## Cambio de meta: internet en vez de LAN (2026-10-24)
El usuario quiere jugar con amigos por internet contra un servidor dedicado; abrirá el UDP 7777 en su router. La meta pasa a ser "3 personas juegan 5 partidas seguidas por internet". Consecuencias:
- H2 añade la **predicción del jugador local** (FEAT-014 la dejaba para después del PoC), tras medir el retraso en una primera partida real.
- H4 incluye el **museo v2** (`docs/gdd/levels/museum_v2.md`, aprobado): generador por datos y maqueta gris primero, vestido con assets CC0 después.
- Relojes con consecuencia y monitores CCTV legibles (decisiones 3 y 5 del museo v2) pasan por `/design`.
