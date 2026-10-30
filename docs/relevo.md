# Relevo: #114 Miniondas de ruido: ver de dónde viene lo que oyes

- **Rama**: `feat/114-miniondas-ruido` · **PR**: sin abrir · **Tarjeta**: En curso
- **Última herramienta**: Claude Code (Opus), 2026-10-30 (relevo de Antigravity)

## Hecho
- Issue leído, tarjeta movida a «En curso», rama creada desde `master` (6f166c0).
- Explorado: `NoiseAudioPresenter.handle_noise` ya aplica la regla de quién oye qué, sin red y en el cliente (el servidor filtra con la misma regla y el cliente llama a `handle_noise`). Es el punto de enganche de las ondas.

- (Antigravity) Reglas puras `NoiseWaveRules` y números en `noise_feedback.tres`.
- (Claude Code) Shader `noise_wave.gdshader`, `NoiseWave3D`, `NoiseWavePool` (12 ondas) y enganche en `NoiseAudioPresenter.handle_noise`.

## Falta
- Escena aislada de la onda, tests, `stealth.md` P2.4, capturas para el usuario (es sensación: enseñar antes de pulir) y verificación completa.

## Decisiones tomadas
- (agente) La onda solo sale para ruidos del bando contrario que alcanzan al jugador local: los guardias ven los del ladrón y el ladrón los de los guardias. Lo propio y lo del propio bando no hace onda (el issue lo dice así).
- (agente) Se dispara desde `handle_noise` y no desde `SignalBus.noise_emitted_3d` (como dice la regla 04 para los antiguos anillos), para respetar la regla de audición y la red.
- (agente) Capa de render 19 (la de la niebla): solo la dibuja la cámara del mapa, no las CCTV; y prioridad de render por encima de la niebla para verse en ella.

## Preguntas pendientes al usuario
- Ninguna.
