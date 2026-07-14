# 💻 Arch Linux Desktop Setup & Asistente de Voz

Este repositorio contiene la configuración estándar para la instalación de Arch Linux (entorno GNOME + WhiteSur) y utilidades integradas de productividad local.

---

## 🎙️ Guía del Asistente de Voz Local (AI-Desktop)

El asistente de voz permite realizar dictados rápidos (escribir con la voz) y ejecutar acciones del sistema usando inteligencia artificial local (`llama.cpp` + `whisper.cpp`).

### ⌨️ Atajos de Teclado
*   **`Super + T`**: Dictado por voz (Escribe lo que dices en cualquier ventana).
*   **`Super + Y`**: Comando por voz con IA (Ejecuta acciones/abre aplicaciones).

---

## 🛠️ Cómo Activar y Verificar el Asistente

Como la extensión de GNOME se acaba de copiar a los archivos de configuración, debes realizar los siguientes pasos para activarla por primera vez:

### 1. Reiniciar la Sesión
*   Cierra tu sesión de usuario en GNOME y vuelve a iniciarla (o reinicia el computador por completo). Esto obligará a GNOME a escanear y cargar la nueva extensión.

### 2. Activar la Extensión
*   Abre la aplicación **Extensions** (o **Extension Manager**) en tu sistema.
*   Busca la extensión llamada **AI Voice Status** y actívala.
*   *(Opcional: Si no la ves activa, puedes forzar su activación corriendo: `gnome-extensions enable ai-status@termihoe.github.io`)*.

### 3. Prueba de Depuración en Terminal (Verificar que grabe y transcriba)
Puedes probar el script directamente en tu terminal para ver logs detallados y verificar la transcripción sin depender de los atajos globales:

1.  **Inicia la grabación** ejecutando:
    ```bash
    python3 ~/Documents/Desktop/voice-assistant/assistant.py --mode type
    ```
    *(Escucharás un pitido del sistema indicando que comenzó a grabar).*
2.  **Habla por el micrófono.**
3.  **Detén la grabación** ejecutando el mismo comando:
    ```bash
    python3 ~/Documents/Desktop/voice-assistant/assistant.py --mode type
    ```
    *(Escucharás otro pitido, el sistema procesará la transcripción y verás el texto detectado impreso en la terminal. Además, se copiará al portapapeles y se autopegará si la extensión de GNOME está activa).*

---

## 🚀 Archivos Principales del Proyecto

*   **[setup-master.sh](file:///home/termihoe/Documents/Desktop/setup-master.sh)**: Script principal de instalación del sistema. Actualiza automáticamente keyrings de pacman para evitar errores de GPG y firma, instala todas las dependencias y desactiva la validación estricta de versiones de extensiones en GNOME.
*   **[roadmap.sh](file:///home/termihoe/Documents/Desktop/roadmap.sh)**: Menú interactivo CLI que detalla la visión a futuro para la instalación automatizada del software POS (**NeoPOS**) en clientes.
*   **[voice-assistant/assistant.py](file:///home/termihoe/Documents/Desktop/voice-assistant/assistant.py)**: Controlador en Python que maneja la grabación, transcripción con Whisper, copiado de portapapeles y lógica de llamadas de comandos a la IA local.
*   **[voice-assistant/install_voice_assistant.sh](file:///home/termihoe/Documents/Desktop/voice-assistant/install_voice_assistant.sh)**: Automatiza la descarga del modelo Whisper, copia y activa la extensión de GNOME, y configura los accesos directos `Super + T` y `Super + Y`.
