# Estilo de los textos

- **Estado**: aprobado por el usuario el 2026-10-29, tras una sesión de preguntas.
- **Para qué**: que todo lo que lee el jugador suene a la noche del golpe, en 1984, y nada le saque del juego.
- **Regla corta para los agentes**: `.agents/rules/06-textos.md`.

## 1. Qué cubre
Todo texto que lee un jugador:
- HUD y avisos de interacción;
- briefing, la carta y las pantallas finales;
- menús, opciones, controles, sala de espera y mensajes de error;
- la web del juego y las partes del README para jugadores.

Quedan fuera los documentos de desarrollo (`docs/`, el manual de compilación) y el código.

## 2. El mundo
- **Dónde**: «la ciudad», en España, en 1984. No se nombran lugares reales.
- **Quién vigila**: **vigilantes jurados** de una empresa de seguridad privada, que dan parte a **la central**.
- **Quién roba**: un ladrón de guante blanco al estilo de Arsène Lupin. Nunca es violento. Firma con la inicial de su nombre (§7).
- **La técnica**: la de 1984. Circuito cerrado de televisión, monitores de tubo, relojes de fichar, walkies y cuadros eléctricos. Nada de pantallas táctiles, drones ni «sistemas».

## 3. Tres voces
Las referencias son para el vocabulario y el ritmo, nunca para copiar frases.

| Voz | Dónde | Cómo suena | Referencias |
|---|---|---|---|
| **El ladrón** | Su briefing, su encargo, sus avisos y su victoria | Un caballero irónico y educado que habla del robo como de un oficio fino: «el encargo», «la pieza», «con mis respetos» | Maurice Leblanc (Arsène Lupin); Lawrence Block, la serie de Bernie Rhodenbarr (*El ladrón que…*) |
| **Los guardias** | Su briefing, la hoja de ronda y los avisos de su HUD | El parte de servicio de un vigilante jurado: seco, de reglamento. «La central», «la ronda», «sin novedad», «dar parte», «el relevo» | Donald E. Westlake y Richard Stark (golpes contados con sequedad profesional) |
| **El narrador** | Menús, alerta, pantallas finales y textos comunes | Novela negra breve: una frase con imagen, no un párrafo | Eduardo Mendoza (*El misterio de la cripta embrujada*), Manuel Vázquez Montalbán (Carvalho) |

## 4. Leer con calma o en un segundo
- **Con calma** (briefing, la carta, pantallas finales, plano, menús): inmersión total. Cada texto puede ser un documento del mundo: la carta del ladrón, el parte de la central, la nota del coleccionista.
- **En un segundo** (avisos de interacción, HUD): frases cortas y claras, con palabras del mundo pero sin adornos. La inmersión nunca debe costar entender qué tecla pulsar en mitad de una persecución.

## 5. Normas
- **Tratamiento**: **tú** al jugador. **Vosotros** solo para los objetivos que comparte el equipo de guardias.
- **Variante**: español de España, con la ortografía de la RAE.
- **Tecnicismos fuera**: rutas de archivos, nombres de scripts, órdenes de terminal, «servidor», «IA», «bot», «snapshot», «debug», nombres de clases, variables o códigos de error.
  - **Se permiten** la **IP y el puerto** al unirse a una partida, porque el jugador los entiende.
  - **Datos de la conexión (F9)** es la única pantalla técnica: puede mostrar ping, pérdida y kB/s.
- **Avisos de interacción**:
  - **Para actuar**: «Verbo + objeto [Tecla]», por ejemplo «Forzar la puerta [E]».
  - **Mientras dura la acción**: «Gerundio…», por ejemplo «Forzando la cerradura…».
  - **Cuando no se puede**: una frase corta que dice por qué, por ejemplo «No te queda somnífero».
- **HUD**: cabeceras en MAYÚSCULAS y el resto en frase normal.
- **Ortografía**:
  - tildes siempre;
  - «¿?» y «¡!» con el signo de apertura;
  - comillas angulares «»;
  - puntos suspensivos con un solo carácter «…»;
  - coma decimal (1,5 s).
- **Anglicismos**: fuera si hay palabra española, por ejemplo «revancha» y no «rematch». Se quedan los que se decían en 1984: walkie.
- **Es la primera versión**: el juego aún no ha salido. Nada de «ampliado», «nuevo», «ahora», «ya no», «v2» ni comparaciones con versiones anteriores; el juego se describe tal como es.
- **Errores y avisos del sistema**: primero qué ha pasado y qué hacer, en una frase clara. Después, si cabe, un toque del mundo que no estorbe. Nunca códigos.

## 6. Glosario
| Concepto | Se dice | No se dice |
|---|---|---|
| Lo que tiene que robar el ladrón | **el encargo** | la misión, los objetivos |
| Las obras que podrían estar en el encargo (vista de los guardias) | **piezas en el punto de mira** | candidatas |
| La copia del cambiazo | **réplica** (ladrón); **falsificación** (cuando un guardia la descubre) | pieza de pega |
| Robar sin desactivar la protección | **a lo bruto** | forzar sin sigilo |
| Lo que delata un robo | **rastro** | evidencia, pista |
| El estado de la patrulla | **alerta**: calma, sospecha, alarma | nivel de amenaza |
| Pasar por los relojes | **fichar**, **la ronda**, **la hoja de ronda**, **falta**, **ronda rota** | checkpoint, penalización |
| Las cámaras | **circuito cerrado**, **mesa de monitores** | CCTV |
| La empresa de seguridad | **la central** | el sistema, el servidor |
| La garita de los guardias | **la garita** | sala de control |
| La radio de los guardias | **el walkie** | radio, comunicador |
| Moverse por los conductos | **la ventilación**, **el conducto**, **la rejilla** | túnel, atajo |
| Cortar la alarma de un ala | **el cuadro eléctrico**, **cortar la corriente** | panel de energía |
| Los guardias que no maneja una persona | **los lleva el ordenador** | IA, bots |
| La pantalla técnica de F9 | **Datos de la conexión** | panel de rendimiento y red, debug |
| Esperar a que empiece la partida en red | **la sala de espera** | lobby |
| Volver a jugar con los mismos bandos | **revancha** | rematch |

**Retirado del juego**: el botín en dólares, el maletero, la cuota y la Pieza Maestra fija.

## 7. El nombre y la firma
- **Cuándo se pide**: la primera vez que se abre el juego («¿Cómo te llamas?»). Se cambia en Opciones.
- **Formato**: entre 2 y 16 caracteres. Se permiten letras (con tildes y ñ), números, espacio, guion y guion bajo. Se recortan los espacios de los extremos.
- **Firma del ladrón**: la primera **letra** de su nombre, en mayúscula, tras una raya, como «—D.». Si no tiene letras o no hay nombre, «—V.».
- **Dónde se ve**:
  - la firma, en la carta, la victoria del ladrón y la tarjeta;
  - la lista de la sala de espera;
  - la pantalla final.
  - Sobre los personajes siguen los números de guardia y «TÚ».
- **Nombres repetidos en red**: el segundo se ve con un número, como «Diego 2».

## 8. Así sí, así no
| Así no | Así sí | Por qué |
|---|---|---|
| Arranca el servidor con `tools/net/run_server.sh` y abre el puerto UDP 7777 | Pide a quien organiza la partida su IP y su puerto | Sin órdenes ni archivos; la IP y el puerto sí |
| Eres el ladrón; la IA lleva a los guardias. | Eres el ladrón. A los guardias los lleva el ordenador. | Sin «IA» |
| Fichar Ronda Mecanica (90s restantes) [E] | Fichar en el reloj 5 [E] | Tildes, sin paréntesis técnicos |
| Panel de rendimiento y red | Datos de la conexión (F9) | Lenguaje de jugador |
| Coger una pieza de pega [E] | Coger una réplica [E] | Glosario |
| Las piezas candidatas llevan una marca cian | Las piezas en el punto de mira llevan una marca cian | Glosario |
| La policia aseguro el perimetro | La central cerró el museo a tiempo. Sin novedad. | Ortografía y voz de los guardias |
| No se pudo conectar con 1.2.3.4:7777: ERR_CANT_CONNECT | No hay respuesta en 1.2.3.4:7777. Comprueba la IP y el puerto e inténtalo de nuevo. | Sin códigos; qué hacer |
| Atrapadlo antes de 12 minutos y fichad los relojes. | Atrapadlo antes de que acabe el turno (12 minutos) y no dejéis la ronda. | Vosotros solo en el objetivo del equipo; voz de parte |

## 9. Comprobación
- Toda FEAT que añada o cambie textos del jugador los repasa con esta guía.
- La revisión (`/review`, `reviewer`) comprueba, en cada texto nuevo:
  - el glosario;
  - el tratamiento;
  - los tecnicismos;
  - la ortografía.
