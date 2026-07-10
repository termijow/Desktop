#!/usr/bin/env python3
import os
import sys
import subprocess
import signal
import time
import json
import re
import threading
import urllib.request
import urllib.error
import argparse

PID_FILE = "/tmp/voice_assistant_recording.pid"
AUDIO_FILE = "/tmp/voice_assistant_recording.wav"
TRANSCRIPT_PREFIX = "/tmp/voice_assistant_transcription"
TRANSCRIPT_FILE = "/tmp/voice_assistant_transcription.txt"
STATUS_FILE = "/tmp/ai_status.txt"
WINDOW_INFO_FILE = "/tmp/ai_focused_window.json"
WHISPER_MODEL_DIR = os.path.expanduser("~/.cache/whisper-models")
WHISPER_MODEL_PATH = os.path.join(WHISPER_MODEL_DIR, "ggml-base.bin")
WHISPER_MODEL_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"

def write_status(text):
    try:
        with open(STATUS_FILE, "w") as f:
            f.write(text)
    except Exception as e:
        print(f"Error escribiendo estado: {e}", file=sys.stderr)

def clear_status():
    write_status("")

def play_beep():
    # Intentamos reproducir un sonido del sistema para indicar acción
    try:
        sound_paths = [
            "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga",
            "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga",
            "/usr/share/sounds/freedesktop/stereo/bell.oga"
        ]
        for path in sound_paths:
            if os.path.exists(path):
                subprocess.Popen(["paplay", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                break
    except Exception:
        pass

def notify(title, message):
    try:
        subprocess.Popen(["notify-send", title, message])
    except Exception as e:
        print(f"Error al enviar notificación: {e}", file=sys.stderr)

def is_recording_running():
    if not os.path.exists(PID_FILE):
        return False, None
    try:
        with open(PID_FILE, "r") as f:
            pid = int(f.read().strip())
        # Verificar si el proceso sigue vivo
        os.kill(pid, 0)
        return True, pid
    except (ValueError, ProcessLookupError, FileNotFoundError):
        return False, None


def live_transcription_loop(proc):
    temp_wav = "/tmp/voice_assistant_live.wav"
    temp_prefix = "/tmp/voice_assistant_live"
    temp_txt = "/tmp/voice_assistant_live.txt"
    
    # Limpiar archivos temporales anteriores
    for f in [temp_wav, temp_txt]:
        if os.path.exists(f):
            try: os.remove(f)
            except Exception: pass
            
    while True:
        # Si el proceso terminó, salir
        if proc.poll() is not None:
            break
            
        time.sleep(1.5)
        
        if proc.poll() is not None:
            break
            
        if os.path.exists(AUDIO_FILE) and os.path.getsize(AUDIO_FILE) > 5000:
            try:
                # Copiar archivo en crecimiento
                subprocess.run(["cp", AUDIO_FILE, temp_wav], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                
                # Ejecutar whisper-cli rápido
                subprocess.run(
                    [
                        "whisper-cli",
                        "-m", WHISPER_MODEL_PATH,
                        "-f", temp_wav,
                        "-l", "es",
                        "--no-timestamps",
                        "-otxt",
                        "-of", temp_prefix
                    ],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                
                if os.path.exists(temp_txt):
                    with open(temp_txt, "r", encoding="utf-8") as f:
                        text = f.read().strip()
                        
                    # Limpiar alucinaciones comunes
                    hallucinations = ["subtítulos", "amara.org", "transcripción", "música", "gracias"]
                    for hal in hallucinations:
                        if hal in text.lower() and len(text) < len(hal) + 15:
                            text = ""
                            break
                            
                    if text:
                        # Limitar a las últimas 6 palabras para la barra de estado
                        words = text.split()
                        if len(words) > 6:
                            display_text = "🎙️ ..." + " ".join(words[-6:])
                        else:
                            display_text = "🎙️ " + text
                        write_status(display_text)
            except Exception as e:
                print(f"Error en live transcription: {e}", file=sys.stderr)
                
    # Limpieza final al salir
    for f in [temp_wav, temp_txt]:
        if os.path.exists(f):
            try: os.remove(f)
            except Exception: pass


def start_recording():
    running, pid = is_recording_running()
    if running:
        print("Ya se está grabando.")
        return False

    write_status("🎤 Grabando...")
    play_beep()

    # Iniciar grabación a 16kHz, mono, 16 bits (requerido por whisper)
    try:
        # Verificar si pw-record está instalado
        has_pw = False
        try:
            res = subprocess.run(["which", "pw-record"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if res.returncode == 0:
                has_pw = True
        except Exception:
            pass

        if has_pw:
            # Usar pw-record (nativo de PipeWire)
            proc = subprocess.Popen(
                ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", AUDIO_FILE],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print(f"Grabación iniciada con pw-record (PID {proc.pid})")
        else:
            # Usar arecord (ALSA fallback)
            proc = subprocess.Popen(
                ["arecord", "-f", "S16_LE", "-c", "1", "-r", "16000", "-t", "wav", AUDIO_FILE],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print(f"Grabación iniciada con arecord (PID {proc.pid})")

        with open(PID_FILE, "w") as f:
            f.write(str(proc.pid))
            
        # Ejecutar bucle de transcripción en tiempo real (mientras graba)
        live_transcription_loop(proc)
        
        return True
    except Exception as e:
        write_status("❌ Error de grabación")
        notify("Asistente de Voz", f"Error al iniciar grabación: {e}")
        clear_status()
        return False

def stop_recording(pid):
    write_status("✍️ Deteniendo grabación...")
    play_beep()
    try:
        os.kill(pid, signal.SIGINT)
        # Esperar a que el proceso termine de escribir el archivo WAV
        for _ in range(20):
            time.sleep(0.05)
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
    except Exception as e:
        print(f"Error al detener proceso {pid}: {e}")
    
    if os.path.exists(PID_FILE):
        try:
            os.remove(PID_FILE)
        except FileNotFoundError:
            pass
    print("Grabación detenida.")

def ensure_whisper_model():
    if os.path.exists(WHISPER_MODEL_PATH):
        return True
    
    os.makedirs(WHISPER_MODEL_DIR, exist_ok=True)
    write_status("⬇️ Descargando modelo Whisper...")
    notify("Asistente de Voz", "Descargando modelo Whisper (base, ~140MB). Por favor espera...")
    
    try:
        # Usar curl para descargar y mostrar progreso si es posible
        subprocess.run(
            ["curl", "-L", "-o", WHISPER_MODEL_PATH, WHISPER_MODEL_URL],
            check=True
        )
        notify("Asistente de Voz", "Modelo Whisper descargado con éxito.")
        return True
    except Exception as e:
        write_status("❌ Error descargando modelo")
        notify("Asistente de Voz", f"Error al descargar modelo Whisper: {e}")
        clear_status()
        return False

def transcribe():
    if not ensure_whisper_model():
        return ""

    if not os.path.exists(AUDIO_FILE):
        write_status("❌ Archivo de audio no encontrado")
        time.sleep(2)
        clear_status()
        return ""

    write_status("✍️ Transcribiendo...")
    
    # Limpiar transcripción anterior
    if os.path.exists(TRANSCRIPT_FILE):
        try:
            os.remove(TRANSCRIPT_FILE)
        except FileNotFoundError:
            pass

    try:
        # Correr whisper-cli
        # whisper-cli -m <modelo> -f <audio> -l es --no-timestamps -otxt -of <output_prefix>
        subprocess.run(
            [
                "whisper-cli",
                "-m", WHISPER_MODEL_PATH,
                "-f", AUDIO_FILE,
                "-l", "es",
                "--no-timestamps",
                "-otxt",
                "-of", TRANSCRIPT_PREFIX
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
    except FileNotFoundError:
        write_status("❌ Falta whisper-cli")
        notify("Asistente de Voz", "Error: 'whisper-cli' no está instalado. Ejecuta el instalador.")
        clear_status()
        return ""
    except Exception as e:
        write_status("❌ Error de transcripción")
        notify("Asistente de Voz", f"Error durante la transcripción: {e}")
        clear_status()
        return ""

    if not os.path.exists(TRANSCRIPT_FILE):
        return ""

    try:
        with open(TRANSCRIPT_FILE, "r", encoding="utf-8") as f:
            text = f.read().strip()
        
        # Limpieza de alucinaciones comunes de Whisper en silencios
        hallucinations = [
            "subtítulos", "amara.org", "transcripción", "música", "gracias por ver",
            "gracias por ver este video", "gracias", "subtitulado por", "subtítulo"
        ]
        
        clean_text = text
        for hal in hallucinations:
            if hal in clean_text.lower() and len(clean_text) < len(hal) + 15:
                clean_text = ""
                break
                
        return clean_text.strip()
    except Exception as e:
        print(f"Error al leer transcripción: {e}")
        return ""

def get_focused_window_info():
    if not os.path.exists(WINDOW_INFO_FILE):
        return {"class": "", "title": "", "pid": 0}
    try:
        with open(WINDOW_INFO_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {"class": "", "title": "", "pid": 0}

def get_terminal_cwd(terminal_pid):
    if not terminal_pid:
        return None
    try:
        # Mapear parent -> children
        parent_map = {}
        proc_names = {}
        for pid_str in os.listdir('/proc'):
            if pid_str.isdigit():
                pid = int(pid_str)
                try:
                    with open(f'/proc/{pid}/stat', 'r') as f:
                        stat_content = f.read()
                    parts = stat_content.rsplit(')', 1)
                    comm = parts[0].split('(', 1)[1]
                    ppid = int(parts[1].split()[1])
                    parent_map.setdefault(ppid, []).append(pid)
                    proc_names[pid] = comm
                except Exception:
                    continue
        
        # Buscar shells
        shells = {'zsh', 'bash', 'fish', 'sh'}
        candidates = []
        
        def dfs(curr_pid):
            name = proc_names.get(curr_pid, '').lower()
            if any(s in name for s in shells):
                candidates.append(curr_pid)
            children = parent_map.get(curr_pid, [])
            for child in children:
                dfs(child)
        
        dfs(terminal_pid)
        
        if candidates:
            shell_pid = candidates[-1] # Preferir el shell más profundo
            cwd_link = f'/proc/{shell_pid}/cwd'
            if os.path.exists(cwd_link):
                return os.readlink(cwd_link)
    except Exception as e:
        print(f"Error resolviendo directorio del terminal: {e}")
    return None

def type_text(text):
    if not text:
        write_status("⚠️ No se detectó texto")
        time.sleep(1.5)
        clear_status()
        return

    write_status("📋 Pegando...")
    try:
        # Copiar al portapapeles
        wl_copy = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
        wl_copy.communicate(input=text.encode("utf-8"))
        
        # Dormir un instante para asegurar que wl-clipboard se actualice
        time.sleep(0.1)

        # Detectar si es una terminal
        win_info = get_focused_window_info()
        win_class = win_info.get("class", "").lower()
        
        is_terminal = any(term in win_class for term in [
            "blackbox", "terminal", "kitty", "alacritty", "konsole", 
            "wezterm", "xterm", "gnome-terminal"
        ])
        
        # Escribir el comando de paste para que la extensión de GNOME lo ejecute con el teclado virtual
        cmd_file = "/tmp/ai_paste.txt"
        with open(cmd_file, "w") as f:
            if is_terminal:
                f.write("paste_terminal")
            else:
                f.write("paste")
            
        print(f"Comando de pegado enviado para: {text}")
    except Exception as e:
        notify("Asistente de Voz", f"Error al pegar texto: {e}")
    
    time.sleep(0.5)
    clear_status()

def read_ai_cli_config():
    # Leer el .env de ai-cli
    ai_cli_env = os.path.expanduser("~/Documents/ai-cli/.env")
    port = 8081
    url = None
    
    if os.path.exists(ai_cli_env):
        try:
            with open(ai_cli_env, "r") as f:
                lines = f.readlines()
            for line in lines:
                line = line.strip()
                if line.startswith("#") or not line:
                    continue
                if "=" in line:
                    key, val = line.split("=", 1)
                    key = key.strip()
                    val = val.strip()
                    if key == "PORT":
                        port = int(val)
                    elif key == "AI_API_URL":
                        url = val
        except Exception as e:
            print(f"Error leyendo config de ai-cli: {e}")

    # Si se especificó una URL en el .env, la usamos. Pero si la URL apunta a localhost/127.0.0.1
    # con un puerto inconsistente con PORT (debido a un error de configuración en el .env),
    # o si no se especificó URL, forzamos que use el puerto activo.
    if url:
        from urllib.parse import urlparse
        try:
            parsed = urlparse(url)
            if (parsed.hostname in ("localhost", "127.0.0.1", "0.0.0.0")) and parsed.port != port:
                url = f"{parsed.scheme}://{parsed.hostname}:{port}{parsed.path}"
        except Exception:
            url = f"http://127.0.0.1:{port}/v1/chat/completions"
    else:
        url = f"http://127.0.0.1:{port}/v1/chat/completions"
        
    return {
        "port": port,
        "url": url
    }
def strip_thinking_blocks(text):
    if not text:
        return text
    # 1. Eliminar bloques <|channel>thought ... <channel|>
    text = re.sub(r"<\|channel>thought.*?<channel\|>", "", text, flags=re.DOTALL)
    # 2. Eliminar bloques <think> ... </think>
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL)
    # 3. Eliminar bloques <thought> ... </thought>
    text = re.sub(r"<thought>.*?</thought>", "", text, flags=re.DOTALL)
    # 4. Eliminar bloques <thought_process> ... </thought_process>
    text = re.sub(r"<thought_process>.*?</thought_process>", "", text, flags=re.DOTALL)
    return text.strip()


def extract_json_from_text(text):
    text = text.strip()
    
    # 1. Intentar cargar el texto completo directamente
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    
    # 2. Intentar buscar bloques de código markdown: ```json ... ``` o ``` ... ```
    code_block_pattern = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.DOTALL)
    matches = code_block_pattern.findall(text)
    for match in matches:
        try:
            return json.loads(match.strip())
        except json.JSONDecodeError:
            pass

    # 3. Intentar buscar la primera '{' y la última '}'
    first_brace = text.find('{')
    last_brace = text.rfind('}')
    if first_brace != -1 and last_brace != -1 and last_brace > first_brace:
        candidate = text[first_brace:last_brace+1]
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass
            
    # Si todo falla, intentar cargar el original para que lance el JSONDecodeError esperado
    return json.loads(text)


def query_ai(text):
    if not text:
        write_status("⚠️ No se detectó voz")
        time.sleep(1.5)
        clear_status()
        return

    # Mostrar lo que se escuchó
    write_status(f"🗣️ \"{text}\"")
    time.sleep(1.5)
    
    write_status("🤖 Pensando...")
    
    # Obtener endpoint local
    config = read_ai_cli_config()
    url = config["url"]
    
    # Verificar conexión rápida al puerto
    import socket
    from urllib.parse import urlparse
    parsed_url = urlparse(url)
    host = parsed_url.hostname or "127.0.0.1"
    port = parsed_url.port or 8081
    
    try:
        # Timeout de 1.5s
        with socket.create_connection((host, port), timeout=1.5):
            pass
    except Exception:
        write_status("⚠️ Servidor apagado")
        notify(
            "Asistente de Voz", 
            f"El servidor de IA local en puerto {port} no está activo.\nEjecuta 'ai-serve' primero."
        )
        time.sleep(3)
        clear_status()
        return

    system_prompt = (
        "Eres un asistente de voz local para Linux Arch. Tu tarea es entender el comando de voz del usuario y decidir qué acción realizar.\n"
        "Puedes ejecutar comandos del sistema o abrir aplicaciones.\n"
        "El usuario puede auto-corregirse a mitad de frase o dar instrucciones de corrección dentro de su comando "
        "(ej. 'abre chrome... ah no me equivoqué abre firefox' o 'abre chrome... me equivoqué es firefox'). "
        "Analiza la intención final del usuario considerando estas correcciones para generar el comando definitivo.\n"
        "Debes responder UNICAMENTE en formato JSON plano y limpio, sin bloques de código markdown como ```json. "
        "El JSON debe tener exactamente estos 3 campos:\n"
        "{\n"
        '  "explanation": "Breve explicación de la acción en español (para mostrar al usuario)",\n'
        '  "command": "El comando de bash a ejecutar (o null si no requiere comando)",\n'
        '  "speak": "Frase de 2-4 palabras de confirmación (ej. \'Abriendo Code\', \'Carpeta creada\')"\n'
        "}\n"
        "Ejemplos:\n"
        "- 'abre el visual studio code en esta carpeta' -> "
        '{"explanation": "Abriendo VS Code en el directorio actual", "command": "code .", "speak": "Abriendo Code"}\n'
        "- 'abre una pestaña en brave con youtube' -> "
        '{"explanation": "Abriendo enlace en el navegador", "command": "xdg-open https://youtube.com", "speak": "Abriendo YouTube"}\n'
        "- 'crea un directorio que se llame proyecto' -> "
        '{"explanation": "Creando directorio proyecto", "command": "mkdir -p proyecto", "speak": "Directorio creado"}\n'
        "- 'abre la carpeta actual' -> "
        '{"explanation": "Abriendo carpeta actual en el explorador de archivos", "command": "xdg-open .", "speak": "Abriendo carpeta"}\n'
        "- 'ponme modo dev' o 'pon modo desarrollo' -> "
        '{"explanation": "Activando modo desarrollo", "command": "python3 /home/termihoe/Documents/Desktop/voice-assistant/assistant.py --dev-mode", "speak": "Modo dev activo"}\n'
        "- 'quien eres' -> "
        '{"explanation": "Soy tu asistente de voz de Arch", "command": null, "speak": "Asistente local"}\n\n'
        "IMPORTANTE: Prefiere 'xdg-open <url>' para abrir enlaces y 'xdg-open <dir>' para abrir carpetas. "
        "Esto asegura compatibilidad con cualquier navegador y gestor de archivos configurado por defecto."
    )

    payload = {
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text}
        ],
        "temperature": 0.1
    }

    try:
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        
        # 30 segundos timeout para inferencia local
        with urllib.request.urlopen(req, timeout=30) as response:
            res_data = response.read().decode("utf-8")
            
        res_json = json.loads(res_data)
        ai_response_text = res_json["choices"][0]["message"]["content"].strip()
        ai_response_text = strip_thinking_blocks(ai_response_text)
        data = extract_json_from_text(ai_response_text)
        explanation = data.get("explanation", "")
        command = data.get("command", None)
        speak = data.get("speak", "Completado")
        
        # Mostrar confirmación corta en la barra
        write_status(f"🤖 {speak}")
        notify("Asistente de Voz", explanation)
        
        if command:
            # Resolver cwd del terminal activo para correr el comando en el lugar correcto
            win_info = get_focused_window_info()
            win_class = win_info.get("class", "").lower()
            win_pid = win_info.get("pid", 0)
            
            is_terminal = any(term in win_class for term in [
                "blackbox", "terminal", "kitty", "alacritty", "konsole", 
                "wezterm", "xterm", "gnome-terminal"
            ])
            
            cwd = None
            if is_terminal and win_pid > 0:
                cwd = get_terminal_cwd(win_pid)
                
            if not cwd:
                cwd = os.path.expanduser("~")
                
            write_status(f"⚙️ {command}")
            write_status(f"⚙️ {command}")
            # Ejecutar el comando en segundo plano y registrar logs para depuración
            try:
                with open("/tmp/voice_assistant_cmd.log", "a") as log_file:
                    log_file.write(f"\n--- {time.strftime('%Y-%m-%d %H:%M:%S')} ---\n")
                    log_file.write(f"Directorio: {cwd}\n")
                    log_file.write(f"Comando: {command}\n")
                    
                    proc = subprocess.Popen(
                        command,
                        shell=True,
                        cwd=cwd,
                        stdout=log_file,
                        stderr=log_file
                    )
                print(f"Comando ejecutado en '{cwd}': {command}")
            except Exception as e:
                print(f"Error al ejecutar comando: {e}")
                notify("Asistente de Voz", f"Error al ejecutar el comando: {e}")
            
    except urllib.error.URLError as e:
        write_status("❌ Error de red")
        notify("Asistente de Voz", f"Error al conectar con la IA: {e}")
    except json.JSONDecodeError as e:
        write_status("❌ Error parsing JSON")
        print(f"Respuesta IA: {ai_response_text if 'ai_response_text' in locals() else 'None'}")
        notify("Asistente de Voz", "La respuesta de la IA no fue en el formato JSON esperado.")
    except Exception as e:
        write_status("❌ Error")
        notify("Asistente de Voz", f"Ocurrió un error inesperado: {e}")
        
    time.sleep(3)
    clear_status()

def run_dev_mode_tiling():
    write_status("⚙️ Activando Modo Dev...")
    paste_file = "/tmp/ai_paste.txt"
    try:
        with open(paste_file, "w", encoding="utf-8") as f:
            f.write("tile\n")
        os.utime(paste_file, None)
    except Exception as e:
        print(f"Error al escribir comando de tiling: {e}")
        
    time.sleep(1.0)
    clear_status()


def main():
    parser = argparse.ArgumentParser(description="Asistente de Voz Local para Arch Linux")
    parser.add_argument("--mode", choices=["type", "ai"], help="Modo: 'type' para escribir, 'ai' para ejecutar comandos")
    parser.add_argument("--dev-mode", action="store_true", help="Activa el modo de desarrollo acomodando ventanas")
    parser.add_argument("--text", help="Texto de entrada directo (evita la grabacion de voz)")
    args = parser.parse_args()

    if args.dev_mode:
        run_dev_mode_tiling()
        return

    if not args.mode:
        parser.error("El argumento --mode es requerido a menos que se use --dev-mode")

    if args.text:
        if args.mode == "type":
            type_text(args.text)
        elif args.mode == "ai":
            query_ai(args.text)
        return

    # Verificar si ya esta grabando
    recording, pid = is_recording_running()
    if recording:
        # Detener grabacion y procesar
        stop_recording(pid)
        transcription = transcribe()
        
        if args.mode == "type":
            # Escribir la transcripcion directa inmediatamente (como antes, sin delay de IA)
            type_text(transcription)
        elif args.mode == "ai":
            # Procesar el comando (si requiere la IA para elegir el comando)
            query_ai(transcription)
    else:
        # Iniciar grabacion
        start_recording()

if __name__ == "__main__":
    main()
