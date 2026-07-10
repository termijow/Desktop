#!/bin/bash
set -e

# ==============================================================================
#  ENDEAVOUROS MASTER SETUP (v18.0 - GDM BACKGROUND FIX)
#  - Todo lo anterior validado.
#  - Fix: El fondo de pantalla de bloqueo ya no será negro.
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "❌ EJECUTA ESTE SCRIPT COMO USUARIO NORMAL (sin sudo)."
  exit
fi

echo "🚀 INICIANDO SETUP FINAL (CON FIX DE FONDO)..."

# Función de instalación ZIP (Validada)
install_extension_from_zip() {
    local url=$1
    local name=$2
    local temp_dir="/tmp/ext_install_$(echo $name | tr -d ' ')"
    
    echo "      ⬇️ Descargando $name..."
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    
    if wget -O "$temp_dir/extension.zip" "$url"; then
        echo "         ✅ Descarga correcta."
    else
        echo "         ⚠️ Error descargando $name. Continuando..."
        return 1
    fi
    
    unzip -oq "$temp_dir/extension.zip" -d "$temp_dir/extracted"
    local metadata_file=$(find "$temp_dir/extracted" -name "metadata.json" | head -n 1)
    
    if [ -z "$metadata_file" ]; then return 1; fi

    local install_base=$(dirname "$metadata_file")
    local uuid=$(grep -Po '(?<="uuid": ")[^"]*' "$metadata_file")
    
    if [ -z "$uuid" ]; then return 1; fi
    
    local target_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -r "$install_base"/* "$target_dir/"
    
    if [ -d "$target_dir/schemas" ]; then
        glib-compile-schemas "$target_dir/schemas" 2>/dev/null || true
    fi
    echo "         ✅ $name instalado."
}

# 1. BASE
echo "📦 [1/8] Verificando base y actualizando llaves..."

# Bucle auto-curativo de llaves GPG de Pacman
echo "🔑 Inicializando y poblando base de llaves de Pacman..."
sudo pacman-key --init
sudo pacman-key --populate archlinux endeavouros

# Intentar instalar/actualizar archlinux-keyring de forma segura.
# Si falla debido a firmas caducadas o corruptas, se aplica un bypass temporal de firmas para este paquete básico.
if ! sudo pacman -Sy --noconfirm archlinux-keyring; then
    echo "⚠️ Error de firmas GPG detectado. Aplicando bypass temporal para instalar archlinux-keyring..."
    
    # Crear una configuración de pacman temporal desactivando firmas
    tmp_conf="/tmp/pacman_siglevel_never.conf"
    if [ -f /etc/pacman.conf ]; then
        # Copiar y sustituir niveles de firma a Never
        cat /etc/pacman.conf | sed -E 's/SigLevel\s*=\s*.*/SigLevel = Never/g' > "$tmp_conf"
    else
        # Si por alguna razón no existe, usar valor genérico
        echo -e "[options]\nSigLevel = Never" > "$tmp_conf"
    fi
    
    # Instalar keyring sin verificar firmas
    sudo pacman --config "$tmp_conf" -Sy --noconfirm archlinux-keyring
    rm -f "$tmp_conf"
    
    # Reinicializar y repoblar el llavero con las llaves seguras recién instaladas
    echo "🔑 Re-inicializando llaves de pacman actualizadas..."
    sudo pacman-key --init
    sudo pacman-key --populate archlinux endeavouros
fi

# Con el keyring seguro, actualizar todo el sistema con firmas activadas por seguridad
sudo pacman -Syu --noconfirm

sudo pacman -S --needed --noconfirm base-devel git wget curl unzip sassc \
    gnome-tweaks gnome-shell-extensions dconf-editor extension-manager \
    imagemagick gdm libgdm gnome-backgrounds papirus-icon-theme \
    ttf-fira-code flatpak gettext npm wtype wl-clipboard whisper-cpp-vulkan

echo "📶 [EXTRA] Bluetooth..."
sudo pacman -S --needed --noconfirm bluez bluez-utils linux-firmware
sudo systemctl enable --now bluetooth

# Reinicio del módulo
sudo systemctl stop bluetooth
sudo modprobe -r btusb || true
sudo modprobe btusb
sudo systemctl start bluetooth

sudo rfkill unblock bluetooth

echo "🔗 Integración GNOME Bluetooth..."
sudo pacman -S --needed --noconfirm gnome-control-center gnome-bluetooth-3.0
yay -S --needed --noconfirm gnome-shell-extension-bluetooth-quick-connect || true

# 2. DEV
echo "🛠 [2/8] Configurando Dev..."
sudo pacman -S --needed --noconfirm python python-pip jdk-openjdk maven nodejs npm docker docker-compose zsh fastfetch

if pacman -Qi visual-studio-code-bin &> /dev/null || pacman -Qi code &> /dev/null; then
    echo "      ✅ VS Code instalado."
else
    yay -S --noconfirm visual-studio-code-bin
fi

echo "🎵 Instalando Spotify..."
if ! pacman -Qi spotify &> /dev/null; then
    yay -S --noconfirm spotify
fi

echo "🎬 Instalando Kdenlive..."
sudo pacman -S --needed --noconfirm kdenlive

sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker $USER 2>/dev/null || true

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true
    cat <<EOT > ~/.zshrc
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git docker npm yarn zsh-autosuggestions zsh-syntax-highlighting)
source \$ZSH/oh-my-zsh.sh
alias neofetch='fastfetch'
EOT
    sudo chsh -s $(which zsh) $USER
fi

echo "🔧 Configurando Git..."
git config --global user.name "Juan Diego"
git config --global user.email "termijow@gmail.com"
git config --global init.defaultBranch main

echo "⚙️ Instalando kernel zen..."
sudo pacman -S --needed --noconfirm linux-zen linux-zen-headers

echo "🤖 Instalando Gemini CLI..."
npm install -g @google/gemini-cli || true

# 3. TERMINAL
echo "🖥️ [3/8] Verificando Terminal..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.raggesilver.BlackBox -y

# 4. TEMAS
echo "🎨 [4/8] Temas y Login Screen..."
# Clonamos siempre para asegurar que tenemos el script tweaks.sh
rm -rf /tmp/WhiteSur-gtk-theme
git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
cd /tmp/WhiteSur-gtk-theme

# Instalar tema de escritorio
./install.sh -t all -N stable

# --- FIX FONDO NEGRO GDM ---
# Antes usábamos '-b blank' (negro). Ahora le decimos que use el fondo por defecto.
# -b default : Usa la imagen borrosa del tema (Azul macOS)
# -i arch    : Pone el logo de Arch
echo "      🖼️ Aplicando fondo al Login..."
sudo ./tweaks.sh -g -b default -i arch -o normal

cd ~
yay -S --needed --noconfirm capitaine-cursors

# 5. EXTENSIONES
echo "🧩 [5/8] Extensiones..."
gsettings set org.gnome.shell disable-extension-version-validation true
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXT_DIR"

yay -S --needed --noconfirm gnome-shell-extension-dash-to-dock
install_extension_from_zip "https://github.com/hermes83/compiz-windows-effect/archive/refs/heads/master.zip" "Wobbly Windows"

echo "      ⬇️ Verificando Media Controls..."
if ! yay -S --needed --noconfirm gnome-shell-extension-mediacontrols 2>/dev/null; then
    yay -S --needed --noconfirm gnome-shell-extension-mediacontrols-git 2>/dev/null || true
fi

rm -rf "$EXT_DIR/burn-my-windows@schneegans.github.com"

# 6. CONFIGURACIÓN VISUAL
echo "⚙️ [6/8] Ajustes..."
# Deshabilitar validación de versiones de extensiones para evitar que se desactiven tras actualizaciones
gsettings set org.gnome.shell disable-extension-version-validation true
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' || true

gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors' || true
# Ponemos el fondo "Blobs" (Azul abstracto)
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-d.svg'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-d.svg'
gsettings set org.gnome.desktop.notifications show-banners true
gsettings set org.gnome.desktop.interface enable-animations true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

# 7. DOCK
echo "⚓ [7/8] Dock..."
SCHEMA="org.gnome.shell.extensions.dash-to-dock"
gsettings set $SCHEMA dock-position 'BOTTOM' 2>/dev/null || true
gsettings set $SCHEMA dock-fixed true 2>/dev/null || true
gsettings set $SCHEMA transparency-mode 'FIXED' 2>/dev/null || true
gsettings set $SCHEMA background-opacity 0.2 2>/dev/null || true
gsettings set $SCHEMA dash-max-icon-size 48 2>/dev/null || true
gsettings set $SCHEMA click-action 'minimize' 2>/dev/null || true
gsettings set $SCHEMA show-mounts false 2>/dev/null || true

# 8. FINALIZACIÓN
echo "🔐 [8/8] Activando..."
sudo systemctl enable -f gdm

gnome-extensions enable dash-to-dock@micxgx.gmail.com 2>/dev/null || true
gnome-extensions enable compiz-windows-effect@hermes83.github.com 2>/dev/null || true
gnome-extensions enable mediacontrols@cliffniff.github.io 2>/dev/null || true

echo "🤖 Instalando Agentes para Antigravity CLI..."
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/instalar_agentes_antigravity.sh" ]; then
    bash "$SCRIPT_DIR/instalar_agentes_antigravity.sh"
else
    echo "⚠️ No se encontró el script de agentes junto al master."
fi

echo "🎙️ Instalando Asistente de Voz Local..."
if [ -f "$SCRIPT_DIR/voice-assistant/install_voice_assistant.sh" ]; then
    bash "$SCRIPT_DIR/voice-assistant/install_voice_assistant.sh"
else
    echo "⚠️ No se encontró el script de instalación del asistente de voz."
fi

echo "======================================================="
echo "✅ ¡SISTEMA PERFECTO!"
echo "======================================================="
echo "   - Ya no tendrás pantalla negra al iniciar."
echo "   - Todo lo demás sigue funcionando."
echo "======================================================="
echo "🔄 REINICIANDO EN 5 SEGUNDOS..."
sleep 5
reboot