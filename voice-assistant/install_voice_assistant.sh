#!/bin/bash
set -e

# ==============================================================================
#  INSTALADOR DE ASISTENTE DE VOZ LOCAL (Arch Linux + GNOME)
# ==============================================================================

# Colores
GREEN='\033[0;32m' ; YELLOW='\033[1;33m' ; BLUE='\033[0;34m' ; RED='\033[0;31m' ; NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🎙️  INSTALACIÓN DEL ASISTENTE DE VOZ LOCAL (AI-DESKTOP)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. Instalar dependencias del sistema
echo -e "\n📦 [1/4] Instalando dependencias de Arch (pacman)..."
sudo pacman -S --needed --noconfirm wtype wl-clipboard whisper-cpp-vulkan alsa-utils curl libnotify

# 2. Descargar modelo de Whisper de antemano
echo -e "\n🧠 [2/4] Configurando modelo de Whisper..."
WHISPER_MODEL_DIR="$HOME/.cache/whisper-models"
WHISPER_MODEL_PATH="$WHISPER_MODEL_DIR/ggml-base.bin"

if [ ! -f "$WHISPER_MODEL_PATH" ]; then
    echo "Descargando modelo 'ggml-base.bin' (140MB)..."
    mkdir -p "$WHISPER_MODEL_DIR"
    curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" -o "$WHISPER_MODEL_PATH"
    echo -e "${GREEN}✓ Modelo descargado con éxito.${NC}"
else
    echo -e "${GREEN}✓ El modelo Whisper ya existe en $WHISPER_MODEL_PATH.${NC}"
fi

# 3. Registrar extensión de Gnome
echo -e "\n🧩 [3/4] Instalando extensión de GNOME para visualización de estado..."
EXT_UUID="ai-status@termihoe.github.io"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"

# Limpiar si ya existe
rm -rf "$EXT_DIR"
mkdir -p "$EXT_DIR"

# Copiar archivos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/extension/metadata.json" "$EXT_DIR/"
cp "$SCRIPT_DIR/extension/extension.js" "$EXT_DIR/"

# Dar permisos de ejecución al script principal
chmod +x "$SCRIPT_DIR/assistant.py"

echo "Habilitando extensión de GNOME..."
# Activar extensión
gnome-extensions enable "$EXT_UUID" 2>/dev/null || true

# 4. Configurar atajos de teclado globales en GNOME
echo -e "\n⚙️  [4/4] Configurando atajos de teclado globales (Super+T, Super+Y y Super+Grave)..."

# Rutas de comandos
COMMAND_TYPE="/usr/bin/python3 $SCRIPT_DIR/assistant.py --mode type"
COMMAND_AI="/usr/bin/python3 $SCRIPT_DIR/assistant.py --mode ai"
COMMAND_LAUNCHER="/usr/bin/python3 $SCRIPT_DIR/launcher.py"

# Asegurar permisos de ejecución
chmod +x "$SCRIPT_DIR/assistant.py"
chmod +x "$SCRIPT_DIR/launcher.py"

# Obtener atajos de teclado existentes
current_bindings=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

# Formatear arreglo
if [ "$current_bindings" = "@as []" ] || [ "$current_bindings" = "[]" ] || [ -z "$current_bindings" ]; then
    new_bindings="['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_type/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_ai/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_launcher/']"
else
    # Eliminar duplicaciones previas de todos nuestros bindings
    clean_bindings=$(echo "$current_bindings" | sed -E "s/',? *'\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/custom_voice_(type|ai|launcher)\///g")
    
    if [ "$clean_bindings" = "[]" ] || [ "$clean_bindings" = "@as []" ]; then
        new_bindings="['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_type/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_ai/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_launcher/']"
    else
        # Insertar los tres nuevos bindings al final de la lista
        new_bindings=$(echo "$clean_bindings" | sed "s/]/, '\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/custom_voice_type\/', '\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/custom_voice_ai\/', '\/org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/custom_voice_launcher\/']/g")
    fi
fi

# Aplicar arreglo de atajos
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_bindings"

# Configurar shortcut para voice-type (Super+T)
PATH_TYPE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_type/"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_TYPE name "AI Voice Dictation (Super+T)"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_TYPE binding "<Super>t"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_TYPE command "$COMMAND_TYPE"

# Configurar shortcut para voice-ai (Super+Y)
PATH_AI="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_ai/"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_AI name "AI Voice Command (Super+Y)"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_AI binding "<Super>y"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_AI command "$COMMAND_AI"

# Configurar shortcut para launcher (Super+Shift+Y)
PATH_LAUNCHER="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_voice_launcher/"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_LAUNCHER name "AI Command Launcher (Super+Shift+Y)"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_LAUNCHER binding "<Shift><Super>y"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$PATH_LAUNCHER command "$COMMAND_LAUNCHER"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "✅ ¡ASISTENTE DE VOZ INSTALADO Y CONFIGURADO!"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Atajos listos:"
echo -e "  - ${YELLOW}Super + T${NC}: Dictado de Voz (Escribe lo que dices)"
echo -e "  - ${YELLOW}Super + Y${NC}: Comando de Voz con IA (Ejecuta acciones/abre apps)"
echo -e "  - ${YELLOW}Super + Shift + Y${NC}: Lanzador de comandos escrito con IA"
echo -e "\n📢 ${YELLOW}NOTA IMPORTANTE:${NC}"
echo -e "Para activar la visualización del estado en la barra superior,"
echo -e "reinicia sesión de GNOME (cierra sesión y vuelve a iniciar) o activa"
echo -e "la extensión 'AI Voice Status' desde la aplicación 'Extensiones' o 'Extension Manager'."
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
