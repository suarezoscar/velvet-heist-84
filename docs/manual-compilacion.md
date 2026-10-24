# Manual: compilar, compartir y alojar una partida

Cómo sacar ejecutables de Velvet Heist '84 para Linux y Windows, pasárselos a tus amigos y arrancar el servidor para jugar por internet.

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

Tarda unos segundos y deja en `build/` (carpeta que git ignora):

| Archivo | Contenido |
|---|---|
| `build/VelvetHeist84-linux.tar.gz` | `VelvetHeist84.x86_64`, `servidor.sh` y `LEEME.txt` |
| `build/VelvetHeist84-windows.zip` | `VelvetHeist84.exe`, `VelvetHeist84.console.exe`, `servidor.bat` y `LEEME.txt` |

Cada ejecutable lleva el juego entero dentro, así que no hace falta nada más. Los presets están en `export_presets.cfg`. Dejan fuera `tests/`, `tools/`, `docs/` y los complementos de desarrollo (GUT y el MCP de Godot).

**Todos los jugadores y el servidor deben usar la misma compilación.** Si cambias el juego, vuelve a compilar y vuelve a repartir.

## 3. Compartir con tus amigos
Pásales el archivo de su sistema por Drive, WeTransfer, Discord o lo que uséis. Pesan unos 115 MB.

- **Windows**: descomprimir y abrir `VelvetHeist84.exe`. Como el ejecutable no está firmado, Windows SmartScreen avisará; se abre con «Más información» y luego «Ejecutar de todos modos».
- **Linux**: `tar -xzf VelvetHeist84-linux.tar.gz` y después `./linux/VelvetHeist84.x86_64`.

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
2. Pulsa **Unirse** y elige bando. Para empezar hace falta un ladrón.
3. Alguien pulsa **Empezar partida**.

| Quién | Dirección |
|---|---|
| Tú, en el mismo PC que el servidor | `127.0.0.1` |
| Alguien de tu misma casa o red | la IP local del servidor (192.168.x.x) |
| Tus amigos por internet | tu IP pública (https://ifconfig.me) |

## 5. Problemas frecuentes
- **«No se pudo conectar»**:
  - comprueba que el servidor está arrancado y que la IP y el puerto son los correctos;
  - desde fuera de casa, revisa la redirección del router y el cortafuegos.
- **CGNAT.** Si la IP WAN que muestra el router no coincide con la de https://ifconfig.me, tu operador te tiene detrás de CGNAT y la redirección de puertos no funcionará. Hay dos salidas:
  - pedir a tu operador una IP pública (muchos lo hacen gratis);
  - usar una red privada virtual como Tailscale o ZeroTier: todos se unen a la misma red y se conectan con la IP que asigna.
- **Desincronías o errores raros**: casi siempre son versiones distintas. Recompila y reparte la misma compilación a todos.
- **Retraso**: el PoC aún no tiene predicción del jugador local, así que con mucho ping el movimiento propio llega con algo de retardo. Cuéntamelo con cifras si lo notas, porque es lo siguiente que se trabaja en red.
