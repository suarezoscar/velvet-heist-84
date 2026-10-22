# Personajes: vestuario, silueta y presupuesto

- **Estado**: aprobado por el usuario el 2026-10-22.
- **Origen**: MASTER_GSD §2 (fantasía de los roles) y §6.1 (paleta y medidas); auditoría de la Fase 1 (pilar 1 y presupuesto de triángulos). 2026-10-22.
- **Relacionado**: `stealth.md` (los puntos de visibilidad dependen de la altura del modelo), `.agents/rules/02-blender-assets.md` (pipeline y fichas).

## Fantasía
- **Ladrón**: un ladrón de guante blanco de cine de los 80, elegante y sin armas. Se le reconoce por la silueta, no por luces.
- **Guardias**: vigilantes de seguridad privada de 1984, uniformados y algo cansados; se les reconoce por la gorra y la linterna, no por el equipo táctico.

## Reglas
- **Decisión**: se sustituyen `thief_crypto.glb` y `guard_swat.glb` por modelos de proporciones realistas, de Mixamo o retexturizados en Blender. Las dos alternativas estilizadas del repo (`thief_stylized`, `guard_stylized`) aciertan en el vestuario, pero son cabezonas: chocan con "neo-noir, no caricaturesco" (pilar 1).
- **Vestuario objetivo del ladrón**: jersey de cuello alto o esmoquin negro (VelvetBlack), pantalón estrecho, guantes negros (decisión del usuario, 2026-10-22; "guante blanco" en el GSD es una expresión, no el color), zapatos de suela blanda; como mucho un gorro o un antifaz.
- **Vestuario objetivo del guardia**: gorra de plato, camisa con parche o placa (GuardNavy o azul claro), corbata, pantalón de uniforme, zapatos o botas de servicio, cinturón con llavero, porra de madera, walkie-talkie y Maglite.
- **Prohibido en los dos** (pilares 1 y 6): luces emisivas o LED, gafas de visión nocturna o tácticas, cascos, chalecos tácticos, rodilleras, pistoleras, armas de fuego y manchas que se lean como sangre.
- **Silueta**: ladrón y guardia se distinguen en negro sobre fondo claro a 140 px de alto, el tamaño en pantalla con la cámara ortográfica de tamaño 14 a 1080p.
- **Medidas**: altura de 1,7-1,85 m. La cabeza debe quedar cerca del punto de visibilidad de cabeza de `stealth.md` (1,6 m) y el pecho cerca del de pecho (1,2 m); si el modelo se aparta más de 0,1 m, se revisan los puntos en `stealth.md`.
- **Animaciones** que debe traer cada modelo: reposo, paso, sigilo (puede ser `tiptoe_walk`) y carrera; el ladrón, además, agachado en reposo y en marcha. No hacen falta animaciones de cuerpo a tierra ni de cobertura (aplazadas en `stealth.md`).

## Números
No van en `.tres`: el presupuesto se fija en la ficha de cada asset (`tools/blender_scripts/specs/<nombre>.json`), como manda la regla 02.

| Mando | Dónde | Tipo | Rango aceptable | Valor y por qué |
|---|---|---|---|---|
| Triángulos por personaje | ficha del asset → presupuesto de triángulos | sensación (legibilidad y coste) | 5.000-10.000 | ≤ 10.000. A unos 140 px de alto no se aprecia más detalle, y hay hasta 5 personajes con varias pasadas de sombra por las linternas. Se aplica a los modelos nuevos; no se reducen los actuales, que se sustituyen. |

## Contrajuego
No es una mecánica. Su papel en la asimetría es la legibilidad: cuando el guardia ilumina al ladrón tiene que reconocerlo al instante, y el ladrón tiene que distinguir a cada guardia por su linterna y su silueta.

| Acción | Quién | Qué percibe el otro bando | Cómo puede responder |
|---|---|---|---|
| Entrar en el cono de una linterna | ladrón | Silueta oscura inconfundible frente a la de un guardia | Salir del cono y agacharse tras cobertura. |

## Qué medir
| Evento o comprobación | Pregunta que responde | Señal de alarma |
|---|---|---|
| Validación del asset (FEAT-001) | ¿Respeta el presupuesto, la altura y los materiales? | Triángulos > 10.000, altura fuera de 1,7-1,85 m, un material emisivo. |
| Captura de silueta a 140 px | ¿Se distinguen los dos roles? | Revisión del usuario: los confunde. |

## Estado
Los modelos actuales (`assets/models/characters/thief_crypto.glb`, 29.012 tris, y `guard_swat.glb`, 19.450 tris) incumplen el vestuario y el presupuesto; se sustituyen en una FEAT de `technical-artist`. Las previews de `assets/previews/characters/` están rotas (miembros sueltos y torsos en negro).

## Preguntas abiertas
Ninguna.
