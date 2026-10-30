---
name: playtest
description: Convierte una sesión de prueba de Velvet Heist '84 (en solitario, contra bots o con un grupo) en un informe estructurado con hallazgos clasificados y enrutados a diseño, balance o bugs. Úsala después de probar el juego o al recibir datos de telemetría de partidas.
---
# /playtest — informe de sesión de prueba

La ejecuta `game-designer`.

1. **Modo**: `solo` (el usuario prueba, controlando personajes con F1–F5), `bots` (partidas simuladas) o `grupo` (con personas).
2. **Datos**: busca la telemetría de la sesión si existe (formato y ruta los fija su FEAT). Sin telemetría, el informe se basa en lo que cuenta el usuario y así se indica.
3. **Entrevista**: crea `docs/playtests/AAAA-MM-DD-<modo>.md` con `references/report-template.md` y rellénalo con el usuario, con preguntas cortas y una sección cada vez. Anota lo que vio, no tu interpretación.
4. **Clasificación**: cada hallazgo va a una sola categoría:
   - **Diseño**: confusión, falta de contrajuego, algo que contradice la fantasía o un pilar → `/design` sobre el sistema afectado.
   - **Balance**: un número se siente mal o los datos salen de rango → `/balance`.
   - **Bug**: defecto reproducible → descripción con pasos de reproducción para una FEAT de corrección.
   - **Pulido**: fricción que no bloquea → se queda en el informe.
5. **Cierre**: resumen de las tres prioridades de la sesión y el siguiente paso de cada una.

Hecho cuando: cada hallazgo tiene categoría y siguiente paso, y la sección de datos dice de dónde salen.
