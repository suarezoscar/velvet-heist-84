# Relevo — #178 fase 3 · props y materiales

**Decisiones (Q73-Q78)**
- Orden: primero las cajas de color de las coberturas, después el botín y el decorado de Poly Haven, y por último vitrinas, cajas fuertes y cuadros si hace falta.
- Muebles hechos con scripts de Blender: low-poly, sin texturas, con una paleta corta (ParquetWood, MahoganyWood, Steel80s, MarbleWhite, ServicePaint, ArchivePaper).
- Cada mueble se estira a su caja de colisión exacta (`_stretched`), así que el juego no cambia.
- Botín y decorado de Poly Haven: una tabla de colores a mano por modelo; se rehace solo lo que no se lea.
- Primero un prototipo con 6 tipos; el resto en tanda (Sonnet hace los scripts y Opus revisa cada pieza).

**Hecho**
- `tools/blender_scripts/gen_museum_props.py` con shelf, crate, statue, cabinet, table y locker, con sus fichas validadas.
- `LevelDressingBuilder.PROP_MODELS` y `_stretched`.
- Página de comparación: https://claude.ai/artifact/9ohA3fM8cbkNupj87iw55i

**Falta**
- Que el usuario apruebe el estilo.
- Los otros 22 tipos.
- La tabla de colores del botín.
- La regla de estilo en `art_style.md`.
- Tests.
