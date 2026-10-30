# Autorrevisión de un documento de diseño

Aplica cada lente al documento completo y anota los hallazgos como bloqueantes o sugerencias.

## Lentes
- **Completitud**: las siete secciones de la plantilla tienen contenido real, no encabezados vacíos.
- **Fantasía**: las reglas entregan la fantasía declarada. Una regla que sirve a la implementación pero rompe la sensación es bloqueante.
- **Pilares**: repasa los seis de `docs/gdd/pillars.md` uno por uno. Una tensión con un pilar se declara y se justifica en el documento.
- **Asimetría**: cada acción tiene su fila de contrajuego; la ausencia de respuesta (pilar 4) o una opción que gana siempre (estrategia degenerada) es bloqueante.
- **Sonido**: cada acción relevante produce un rastro audible o visible (pilar 2); un silencio total lleva justificación.
- **Extremos**: lleva cada número a su mínimo y su máximo plausibles. Un resultado degenerado (invulnerable, inalcanzable, instantáneo, negativo) es bloqueante.
- **Ritmo**: el sistema cabe en una partida de 8-10 minutos y empuja hacia la tensión, no hacia la espera.
- **Tono 1984**: todo lo que aparece existía en 1984 o es un artilugio mecánico creíble estilo Q de Bond; sin visión nocturna.
- **Medible**: cada regla se puede comprobar con un test o un evento de telemetría. "Se siente equilibrado" no es comprobable.
- **Coherencia**: sin contradicciones con otros documentos de `systems/` ni con los `.tres`; las dependencias están declaradas en ambos lados.

## Veredicto
- `APROBABLE`: sin bloqueantes.
- `REVISAR`: bloqueantes que se corrigen sin cambiar la idea.
- `REHACER`: la idea choca con un pilar o no tiene contrajuego posible.

Alcance estimado: S (un sistema, sin fórmulas) · M (1-2 fórmulas, 3-6 dependencias) · L (varios sistemas o red) · XL (transversal, toca la arquitectura).
