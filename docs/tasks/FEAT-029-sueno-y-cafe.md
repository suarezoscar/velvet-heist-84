# FEAT-029 — El sueño del guardia y el café (entrega 2 del golpe)

- **Estado**: hecha
- **Diseño**: `docs/gdd/systems/heist.md` R5 (aprobado el 2026-10-28)
- **Hito del PoC**: rediseño contra la acampada, antes del playtest
- **Rama**: `feat/029-sueno-y-cafe`

## Objetivo
Que quedarse en un mismo sitio cueste: al guardia que acampa le entra sueño (bosteza, ve menos y da cabezadas) y solo se le quita con un café en la garita.

## Criterios
| # | Criterio | Evidencia |
|---|---|---|
| 1 | Acampar se mide por permanencia: en la última ventana (60 s), el 75 % dentro de un círculo de 8 m. Ir y venir dentro no sirve; patrullar, sí | `test_camping_is_presence_not_stillness` |
| 2 | El sueño sube acampando; somnoliento, bosteza (ruido «voice» de 7 m, con sonido) y ve un 80 %; agotado, además da cabezadas de 1,5 s sin ver nada | `test_camping_guard_gets_drowsy_yawns_and_sees_less` y script en el museo: 150 s quieto, agotado y 6 bostezos |
| 3 | El café de la garita (E, 3 s, ruido de 8 m) deja el sueño a 0 y 120 s despejado. Si se aleja mientras se sirve, no cuenta | `test_coffee_clears_sleep_and_must_stay` |
| 4 | No duermen la IA ni quien persigue al ladrón | `test_ai_guards_and_chases_do_not_sleep` |
| 5 | El sueño solo le llega a su guardia (estado privado `guard_N`). El guardia ve una taza con su estado y la pantalla a negro en cada cabezada | `test_sleep_state_is_private_to_its_guard`, partida en red (guardia `level=0,85`, ladrón 0) y captura |
| 6 | La cafetera es un asset CC0 adaptado y validado; el bostezo, un sonido propio reproducible | `tools/blender_scripts/specs/coffee_cart.json` (validación `pass`), `test_asset_import.gd` y `tools/audio/gen_yawn.py` |

## Contratos
- `GuardSleepRules` (`data/balance/guard_sleep.tres`).
- `CampingMeter` (lógica pura).
- `GuardSleep`, hijo «Sleep» de cada guardia:
  - `level`, `stage()`, `nodding`, `drinking_left`, `fresh_left`, `step(delta)` y `start_coffee()`;
  - cambia `guard.perception` por un perfil con los alcances de vista escalados.
- `CoffeeMachine3D`, `SleepHud84` y `HeistBuilder.build_coffee(...)`.
- Datos del nivel: la entrada `coffee` (museo: muro sur de la garita).
- `NoiseMix`: categoría `voice` (`voice_db` y `voice`).

## Riesgos y decisiones abiertas
- **El bostezo es un sonido sintético provisional** (síntesis de formantes). Si suena mal, se cambia por una grabación libre.
- **El carrito mide 2,2 m**, tamaño real. Si estorba en la garita, se mueve en `museum_v2.json`.
- **Validación local**: mi Blender es la 5.2.3 y el proyecto fija la 5.2.2. Validé con la misma función del validador, sin la comprobación de versión; el CI valida con la 5.2.2.

## Cierre
2026-10-28. La revisión del PR #83 pidió tres cambios, ya hechos:
- la audiencia del sueño sale del orden en `map.guards` (como el rol de red), no de `guard_id`;
- en una cabezada el guardia tampoco ve las cámaras (`GuardSleep.sees_cameras` en `NetVisibility` y en la vista local);
- la cafetera baja a 1.897 triángulos: es un prop (≤ 2.000), no una pieza protagonista.

Además: el haz de la linterna se encoge con la vista y el carrito ya no invade el muro sur.

Pendiente: «con la alerta en alarma no sube» llega con la entrega 3; hasta entonces lo frena perseguir al ladrón. La cafetera está a 1,5-4 m de los monitores. Acampar en los monitores cuesta un café con ruido cada ~4 minutos; lo dirá el playtest.
