---
name: grilling
description: Interroga sin descanso al usuario sobre un plan, una decisión o una idea. Úsala cuando quiera poner a prueba su razonamiento o use cualquier frase de «grill» (por ejemplo, «grill me»).
---

Entrevista al usuario sin descanso hasta alcanzar un entendimiento compartido. Traza el asunto como un **árbol de diseño**: cada decisión se ramifica en las decisiones que cuelgan de ella.

Recorre el árbol por **rondas**. La **frontera** es el conjunto de decisiones cuyos prerrequisitos ya están resueltos: las preguntas que puedes hacer _ahora_ sin adivinar respuestas que aún no has oído. Pregunta toda la frontera en una ronda: numera cada pregunta y da tu respuesta recomendada. Después espera las respuestas del usuario antes de la siguiente ronda.

Da formato a una ronda así:

```
❓ **P1** - **<título de la pregunta>**: <cuerpo de la pregunta, puede tener varios párrafos, incluidas varias opciones>

➡️ <tu respuesta recomendada>

---

❓ **P2** - **<título de la pregunta>**: <cuerpo de la pregunta, puede tener varios párrafos, incluidas varias opciones>

➡️ <tu respuesta recomendada>
```

Redacta cada pregunta de modo que un «sí» acepte tu respuesta recomendada.

Las respuestas del usuario en cada ronda remodelan el árbol: las decisiones resueltas empujan la frontera hacia fuera y desbloquean preguntas que dependían de ellas. Recalcula la frontera y haz la siguiente ronda. Una pregunta cuya respuesta depende de otra que sigue abierta en esta ronda pertenece a una ronda _posterior_, no a esta.

Averiguar los _hechos_ es tu trabajo, nunca el del usuario. Cuando una pregunta de la frontera necesite un dato del entorno (sistema de archivos, herramientas, etc.), lanza un subagente para averiguarlo; no pidas al usuario nada que puedas consultar tú. No te bloquees por ello: una exploración en marcha es un prerrequisito sin resolver, así que solo esperan al informe del subagente las preguntas que dependen de él; haz ya el resto de la frontera. Las _decisiones_ son del usuario: plantéaselas y espera.

La sesión termina cuando la frontera está vacía: se ha visitado cada rama del árbol de diseño y no queda nada asumido en silencio. No actúes sobre el resultado hasta que el usuario confirme que habéis alcanzado un entendimiento compartido.
