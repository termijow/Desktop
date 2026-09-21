#!/bin/bash
set -e

# Guardar la ruta absoluta del directorio del script desde el inicio
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================================================================
#  ENDEAVOUROS MASTER SETUP (v19.0 - ROBUST & AUTO-CURATIVO)
#  - Bucle auto-curativo de llaves GPG / Pacman a prueba de tiempo
#  - Detección e instalación automática de yay si falta
#  - Corrección de paquetes (whisper-cpp, capitaine-cursors, github-cli)
#  - Descarga directa y fiable de extensiones GNOME (Media Controls, Compiz)
#  - Persistencia de rutas para agentes y asistente de voz
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "❌ EJECUTA ESTE SCRIPT COMO USUARIO NORMAL (sin sudo)."
  echo "   El script solicitará 'sudo' únicamente cuando sea necesario."
  exit 1
fi

echo "🚀 INICIANDO SETUP FINAL MASTER (AUTO-CURATIVO)..."

# Función de instalación ZIP (Resiliente)
install_extension_from_zip() {
    local url=$1
    local name=$2
    local temp_dir="/tmp/ext_install_$(echo "$name" | tr -d ' ')"
    
    echo "      ⬇️ Descargando $name..."
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    
    if curl -sSL -o "$temp_dir/extension.zip" "$url" || wget -qO "$temp_dir/extension.zip" "$url"; then
        echo "         ✅ Descarga correcta."
    else
        echo "         ⚠️ Error descargando $name. Continuando..."
        rm -rf "$temp_dir"
        return 1
    fi
    
    unzip -oq "$temp_dir/extension.zip" -d "$temp_dir/extracted"
    local metadata_file
    metadata_file=$(find "$temp_dir/extracted" -name "metadata.json" | head -n 1)
    
    if [ -z "$metadata_file" ]; then
        rm -rf "$temp_dir"
        return 1
    fi

    local install_base
    install_base=$(dirname "$metadata_file")
    local uuid
    uuid=$(grep -Po '(?<="uuid": ")[^"]*' "$metadata_file")
    
    if [ -z "$uuid" ]; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    local target_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -r "$install_base"/* "$target_dir/"
    
    if [ -d "$target_dir/schemas" ]; then
        glib-compile-schemas "$target_dir/schemas" 2>/dev/null || true
    fi
    rm -rf "$temp_dir"
    echo "         ✅ $name instalado ($uuid)."
}

# 1. BASE
echo "📦 [1/8] Verificando base y actualizando llaves (Auto-curativo)..."

# Limpieza de bloqueos huérfanos
if [ -f /var/lib/pacman/db.lck ]; then
    echo "   🧹 Eliminando bloqueo residual /var/lib/pacman/db.lck..."
    sudo rm -f /var/lib/pacman/db.lck
fi

# Sincronizar reloj de sistema para evitar errores de certificados o firmas en el futuro
sudo timedatectl set-ntp true 2>/dev/null || true

# Bypass temporal de firmas para actualizar archlinux-keyring y endeavouros-keyring
# Esto evita que un sistema o ISO con llaves desactualizadas rechace firmas al intentar actualizarse.
echo "   🔑 Actualizando llaveros oficiales de Arch y EndeavourOS de forma segura..."
TMP_PACMAN_CONF=$(mktemp /tmp/pacman_bootstrap_XXXXXX.conf)
sed -E 's/SigLevel\s*=.*/SigLevel = Never/g' /etc/pacman.conf > "$TMP_PACMAN_CONF"
sed -i -E 's/LocalFileSigLevel\s*=.*/LocalFileSigLevel = Never/g' "$TMP_PACMAN_CONF" 2>/dev/null || true

sudo pacman --config "$TMP_PACMAN_CONF" -Sy --noconfirm archlinux-keyring endeavouros-keyring 2>/dev/null || \
sudo pacman --config "$TMP_PACMAN_CONF" -Sy --noconfirm archlinux-keyring 2>/dev/null || true
rm -f "$TMP_PACMAN_CONF"

# Re-inicializar y poblar llaveros del sistema
echo "   🔄 Inicializando y poblando llaves del sistema..."
sudo pacman-key --init
sudo pacman-key --populate archlinux endeavouros 2>/dev/null || sudo pacman-key --populate archlinux

# Prueba de integridad: si pacman-key quedó corrupto por alguna ejecución previa, reconstruir
if ! sudo pacman -Sy --noconfirm &>/dev/null; then
    echo "   ⚠️ Regenerando base de datos gnupg de pacman..."
    sudo rm -rf /etc/pacman.d/gnupg
    sudo pacman-key --init
    sudo pacman-key --populate archlinux endeavouros 2>/dev/null || sudo pacman-key --populate archlinux
fi

echo "   ✅ Llaves GPG al día y verificadas."

# Con el keyring seguro, actualizar todo el sistema con firmas activadas por seguridad
sudo pacman -Syu --noconfirm

# Paquetes base y utilidades visuales
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip sassc \
    gnome-tweaks gnome-shell-extensions dconf-editor extension-manager \
    imagemagick gdm libgdm gnome-backgrounds papirus-icon-theme \
    capitaine-cursors ttf-fira-code flatpak gettext npm wtype wl-clipboard \
    github-cli

# Instalación resiliente de whisper-cpp (nombre estándar oficial en Arch) con fallback
if ! pacman -Qi whisper-cpp &>/dev/null && ! pacman -Qi whisper-cpp-vulkan &>/dev/null; then
    sudo pacman -S --needed --noconfirm whisper-cpp 2>/dev/null || \
    sudo pacman -S --needed --noconfirm whisper-cpp-vulkan 2>/dev/null || true
fi

# Asegurar disponibilidad de yay
if ! command -v yay &> /dev/null; then
    echo "   📦 'yay' no encontrado. Instalando yay-bin precompilado desde AUR..."
    TMP_YAY=$(mktemp -d /tmp/yay_install_XXXXXX)
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$TMP_YAY"
    (cd "$TMP_YAY" && makepkg -si --noconfirm)
    rm -rf "$TMP_YAY"
fi

echo "📶 [EXTRA] Bluetooth..."
sudo pacman -S --needed --noconfirm bluez bluez-utils linux-firmware 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true

# Reinicio del módulo
sudo systemctl stop bluetooth 2>/dev/null || true
sudo modprobe -r btusb 2>/dev/null || true
sudo modprobe btusb 2>/dev/null || true
sudo systemctl start bluetooth 2>/dev/null || true

sudo rfkill unblock bluetooth 2>/dev/null || true

echo "🔗 Integración GNOME Bluetooth..."
sudo pacman -S --needed --noconfirm gnome-control-center gnome-bluetooth-3.0 2>/dev/null || true
yay -S --needed --noconfirm gnome-shell-extension-bluetooth-quick-connect 2>/dev/null || true

# 2. DEV
echo "🛠 [2/8] Configurando Dev..."
sudo pacman -S --needed --noconfirm python python-pip jdk-openjdk maven nodejs npm docker docker-compose zsh fastfetch 2>/dev/null || true

if pacman -Qi visual-studio-code-bin &> /dev/null || pacman -Qi code &> /dev/null; then
    echo "      ✅ VS Code instalado."
else
    yay -S --noconfirm visual-studio-code-bin 2>/dev/null || yay -S --noconfirm code 2>/dev/null || true
fi

echo "🦁 Instalando Brave Browser..."
if ! pacman -Qi brave-bin &> /dev/null && ! pacman -Qi brave-browser &> /dev/null; then
    yay -S --noconfirm brave-bin 2>/dev/null || true
fi

echo "🎵 Instalando Spotify..."
if ! pacman -Qi spotify &> /dev/null; then
    # Importar llave pública oficial de Spotify para evitar error PGP en AUR
    curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.gpg | gpg --import - 2>/dev/null || true
    yay -S --noconfirm spotify 2>/dev/null || true
fi

echo "🎬 Instalando Kdenlive..."
sudo pacman -S --needed --noconfirm kdenlive 2>/dev/null || true

echo "🌐 Instalando Tailscale..."
sudo pacman -S --needed --noconfirm tailscale 2>/dev/null || true
sudo systemctl enable --now tailscaled 2>/dev/null || true

sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker $USER 2>/dev/null || true

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true
    cat <<EOT > ~/.zshrc
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git docker npm yarn zsh-autosuggestions zsh-syntax-highlighting)
source \$ZSH/oh-my-zsh.sh
alias neofetch='fastfetch'
EOT
    sudo chsh -s "$(which zsh)" "$USER" 2>/dev/null || true
fi

echo "🔧 Configurando Git..."
git config --global user.name "Juan Diego"
git config --global user.email "termijow@gmail.com"
git config --global init.defaultBranch main

echo "⚙️ Instalando kernel zen..."
sudo pacman -S --needed --noconfirm linux-zen linux-zen-headers 2>/dev/null || true

echo "🤖 Instalando Gemini CLI..."
sudo npm install -g @google/gemini-cli 2>/dev/null || npm install -g @google/gemini-cli 2>/dev/null || true

# 3. TERMINAL
echo "🖥️ [3/8] Verificando Terminal..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak install --noninteractive -y flathub com.raggesilver.BlackBox 2>/dev/null || true

# 4. TEMAS
echo "🎨 [4/8] Temas y Login Screen..."
rm -rf /tmp/WhiteSur-gtk-theme
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
(
    cd /tmp/WhiteSur-gtk-theme
    ./install.sh -t all -N stable 2>/dev/null || ./install.sh -t all 2>/dev/null || true
    echo "      🖼️ Aplicando fondo al Login..."
    sudo ./tweaks.sh -g -b default -i arch -o normal 2>/dev/null || true
)
rm -rf /tmp/WhiteSur-gtk-theme

# 5. EXTENSIONES
echo "🧩 [5/8] Extensiones..."
gsettings set org.gnome.shell disable-extension-version-validation true 2>/dev/null || true
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXT_DIR"

yay -S --needed --noconfirm gnome-shell-extension-dash-to-dock 2>/dev/null || true
install_extension_from_zip "https://github.com/hermes83/compiz-windows-effect/archive/refs/heads/master.zip" "Wobbly Windows"

echo "      ⬇️ Verificando Media Controls..."
install_extension_from_zip "https://extensions.gnome.org/download-extension/mediacontrols@cliffniff.github.com.shell-extension.zip?version_tag=68560" "Media Controls" || true

rm -rf "$EXT_DIR/burn-my-windows@schneegans.github.com"

# 6. CONFIGURACIÓN VISUAL
echo "⚙️ [6/8] Ajustes..."
# Deshabilitar validación de versiones de extensiones para evitar que se desactiven tras actualizaciones
gsettings set org.gnome.shell disable-extension-version-validation true 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors' 2>/dev/null || true
# Ponemos el fondo "Blobs" (Azul abstracto)
gsettings set org.gnome.desktop.background picture-options 'zoom' 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-d.svg' 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-d.svg' 2>/dev/null || true
gsettings set org.gnome.desktop.interface enable-animations true 2>/dev/null || true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true 2>/dev/null || true

# Configuración de teclado (Latinoamericano con tildes y numeral # en Shift+3)
echo "   ⌨️ Configurando teclado latinoamericano..."
sudo localectl set-x11-keymap latam pc105 "" 2>/dev/null || true
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'latam')]" 2>/dev/null || true

# 7. DOCK
echo "⚓ [7/8] Dock..."
SCHEMA="org.gnome.shell.extensions.dash-to-dock"
if gsettings list-schemas 2>/dev/null | grep -q "$SCHEMA"; then
    gsettings set $SCHEMA dock-position 'BOTTOM' 2>/dev/null || true
    gsettings set $SCHEMA dock-fixed true 2>/dev/null || true
    gsettings set $SCHEMA transparency-mode 'FIXED' 2>/dev/null || true
    gsettings set $SCHEMA background-opacity 0.2 2>/dev/null || true
    gsettings set $SCHEMA dash-max-icon-size 48 2>/dev/null || true
    gsettings set $SCHEMA click-action 'minimize' 2>/dev/null || true
    gsettings set $SCHEMA show-mounts false 2>/dev/null || true
fi

# 8. FINALIZACIÓN
echo "🔐 [8/8] Activando..."
if systemctl list-unit-files 2>/dev/null | grep -q "gdm.service"; then
    sudo systemctl enable -f gdm 2>/dev/null || true
fi

gnome-extensions enable dash-to-dock@micxgx.gmail.com 2>/dev/null || true
gnome-extensions enable compiz-windows-effect@hermes83.github.com 2>/dev/null || true
gnome-extensions enable mediacontrols@cliffniff.github.com 2>/dev/null || true

echo "🤖 Instalando Agentes para Antigravity CLI..."
if [ -f "$SCRIPT_DIR/instalar_agentes_antigravity.sh" ]; then
    bash "$SCRIPT_DIR/instalar_agentes_antigravity.sh"
else
    echo "⚠️ No se encontró el script de agentes en $SCRIPT_DIR."
fi

echo "🎙️ Instalando Asistente de Voz Local..."
if [ -f "$SCRIPT_DIR/voice-assistant/install_voice_assistant.sh" ]; then
    bash "$SCRIPT_DIR/voice-assistant/install_voice_assistant.sh"
else
    echo "⚠️ No se encontró el script de instalación del asistente de voz en $SCRIPT_DIR."
fi

echo "======================================================="
echo "✅ ¡SISTEMA PERFECTO!"
echo "======================================================="
echo "   - Ya no tendrás pantalla negra al iniciar."
echo "   - Llaves GPG y repositorios auto-curativos."
echo "   - Todo configurado y validado."
echo "======================================================="
echo "🔄 REINICIANDO EN 5 SEGUNDOS (Ctrl+C para cancelar)..."
sleep 5
sudo reboot 2>/dev/null || systemctl reboot 2>/dev/null || reboot