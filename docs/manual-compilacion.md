# Manual: compilar, compartir y alojar una partida

Cómo sacar ejecutables de Velvet Heist '84 para Linux y Windows, pasárselos a tus amigos y arrancar el servidor para jugar por internet.

## 0. Lo más fácil: descargar la última versión
Cada versión publicada está en **https://github.com/suarezoscar/velvet-heist-84/releases/latest**, con un paquete para Windows (`.zip`) y otro para Linux (`.tar.gz`). Pasa ese enlace a tus amigos: no hace falta compilar nada.

### Publicar una versión nueva
No hace falta hacer nada: **cada integración en `master` publica una versión** (salvo las que solo tocan documentación). Se trabaja en ramas como siempre; las ramas solo pasan el CI.

La versión sigue el formato `X.Y.Z` y sube sola el último número: 0.1.0, 0.1.1, 0.1.2… Para dar un salto (0.2.0 o 1.0.0), cambia `config/version` en `project.godot` en un PR; la release siguiente sale con ese número y a partir de ahí vuelve a subir sola.

La pipeline `Release` de GitHub Actions hace lo siguiente:
1. calcula la versión (`tools/build/next_version.sh`);
2. pasa los tests;
3. compila Linux y Windows;
4. crea la etiqueta `vX.Y.Z` y publica la release con los dos paquetes y las notas de los cambios.

También se puede lanzar a mano, para una versión concreta como `0.2.0-rc1`:
- **desde git**: `git tag v0.2.0-rc1` y `git push origin v0.2.0-rc1`;
- **desde GitHub**: pestaña **Actions → Release → Run workflow**, con la versión y la rama.

Tarda unos 5 minutos. La versión se graba en el juego: sale abajo a la izquierda del menú, en el panel F9, en el `LEEME.txt` y en la consola del servidor. Una versión con guion, como `0.2.0-rc1`, se publica como *pre-release* y no cambia el enlace `latest`.

## 1. Preparar el PC (una sola vez)
Necesitas, en Linux:
- **Godot 4.7.2** como orden `godot` en el PATH. Es la versión fijada en `tools/ci/godot_version.env`; compruébalo con `godot --version`.
- `curl`, `unzip`, `tar` y `python3`, que suelen venir instalados.

Instala las plantillas de exportación de Godot. Son unos 1 GB y van a `~/.local/share/godot/export_templates/4.7.2.stable/`:

```bash
tools/build/install_templates.sh
```

## 2. Compilar
Desde la raíz del repositorio:

```bash
tools/build/export.sh          # Linux y Windows
tools/build/export.sh linux    # solo Linux
tools/build/export.sh windows  # solo Windows
```

Tarda unos segundos y deja en `build/` (carpeta que git ignora) un paquete por plataforma con la versión en el nombre. En una compilación local la versión es la base de `project.godot` más el commit, por ejemplo `0.1.0-dev+91666af`:

| Archivo | Contenido |
|---|---|
| `build/VelvetHeist84-<versión>-linux.tar.gz` | `VelvetHeist84.x86_64`, `servidor.sh` y `LEEME.txt` |
| `build/VelvetHeist84-<versión>-windows.zip` | `VelvetHeist84.exe`, `VelvetHeist84.console.exe`, `servidor.bat` y `LEEME.txt` |

Cada ejecutable lleva el juego entero dentro, así que no hace falta nada más. Los presets están en `export_presets.cfg`. Dejan fuera `tests/`, `tools/`, `docs/` y los complementos de desarrollo (GUT y el MCP de Godot).

**Todos los jugadores y el servidor deben usar la misma compilación.** Si cambias el juego, vuelve a compilar y vuelve a repartir.

## 3. Compartir con tus amigos
Pásales el archivo de su sistema por Drive, WeTransfer, Discord o lo que uséis. Pesan unos 115 MB.

- **Windows**: descomprimir y abrir `VelvetHeist84.exe`. Como el ejecutable no está firmado, Windows SmartScreen avisará; se abre con «Más información» y luego «Ejecutar de todos modos».
- **Linux**: `tar -xzf VelvetHeist84-<versión>-linux.tar.gz` y después `./linux/VelvetHeist84.x86_64`.

## 4. Alojar la partida (servidor dedicado)
El servidor es el mismo ejecutable del juego, arrancado sin ventana. No hay que compilar nada aparte. Un PC hace de servidor; puede ser el tuyo, y desde ese mismo PC también puedes jugar.

### 4.1 Arrancar el servidor
Elige una opción:

- **Desde la compilación**:
  - Linux: `./servidor.sh`, o `./servidor.sh 7777` para elegir el puerto.
  - Windows: `servidor.bat`. Abre una consola con el registro del servidor.
- **Desde el código** (sin compilar; usa el Godot del PC): `tools/net/run_server.sh`. Para ver qué pasa por la red: `tools/net/run_server.sh 7777 --net-log`.
- **A mano**: `VelvetHeist84.x86_64 --headless --server --port 7777`.

Cuando arranca, el servidor escribe: `[NetManager] Servidor dedicado iniciado con exito en puerto 7777`. Se detiene con Ctrl+C.

### 4.2 Abrir el puerto
1. **Router**: crea una redirección de puertos (*port forwarding*) del puerto **UDP 7777** a la IP local del PC servidor. La IP local se mira con `ip -4 addr` en Linux o `ipconfig` en Windows; suele ser 192.168.x.x.
2. **Cortafuegos del PC servidor**:
   - Linux con firewalld: `sudo firewall-cmd --add-port=7777/udp` (añade `--permanent` para que dure).
   - Linux con ufw: `sudo ufw allow 7777/udp`.
   - Windows: acepta el aviso del cortafuegos la primera vez («Redes privadas y públicas»).

### 4.3 Conectarse
Cada jugador abre el juego y sigue estos pasos:
1. Entra en **Multijugador** y escribe la dirección del servidor.
2. Pulsa **Unirse** y elige bando. Caben un ladrón y hasta tres guardias, y para empezar hace falta el ladrón y al menos un guardia. No hay guardias de IA en red: hay uno por cada jugador guardia.
3. Alguien pulsa **Empezar partida**.

| Quién | Dirección |
|---|---|
| Tú, en el mismo PC que el servidor | `127.0.0.1` |
| Alguien de tu misma casa o red | la IP local del servidor (192.168.x.x) |
| Tus amigos por internet | tu IP pública (https://ifconfig.me) |

### 4.4 Medir la conexión
Pulsa **F9** durante la partida, o activa **Opciones → Panel de rendimiento y red**, para ver abajo a la derecha:
- los FPS;
- tu ping y tu pérdida de paquetes;
- el tráfico;
- el ping de cada jugador.

El servidor dedicado escribe lo mismo en su consola cada 10 s (líneas `[NetStats]`).

## 5. Problemas frecuentes
- **«No se pudo conectar»**:
  - comprueba que el servidor está arrancado y que la IP y el puerto son los correctos;
  - desde fuera de casa, revisa la redirección del router y el cortafuegos.
- **CGNAT.** Si la IP WAN que muestra el router no coincide con la de https://ifconfig.me, tu operador te tiene detrás de CGNAT y la redirección de puertos no funcionará. Hay dos salidas:
  - pedir a tu operador una IP pública (muchos lo hacen gratis);
  - usar una red privada virtual como Tailscale o ZeroTier: todos se unen a la misma red y se conectan con la IP que asigna.
- **Desincronías o errores raros**: casi siempre son versiones distintas. Comparad la versión del menú (abajo a la izquierda) con la de la consola del servidor y usad todos la misma release.
- **Retraso**: el PoC aún no tiene predicción del jugador local, así que con mucho ping el movimiento propio llega con algo de retardo. Cuéntamelo con las cifras del panel (F9) si lo notas, porque es lo siguiente que se trabaja en red.
