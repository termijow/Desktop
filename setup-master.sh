#!/bin/bash
set -e

# ==============================================================================
#  ENDEAVOUROS MASTER SETUP (v10.0 - MANUAL INSTALL EDITION)
#  - Método: Descarga directa de código (Bypasseando AUR y Tiendas).
#  - Terminal: Black Box.
#  - Visual: Mac Style Clean.
#  - Login: GDM.
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "❌ EJECUTA ESTE SCRIPT COMO USUARIO NORMAL (sin sudo)."
  exit
fi

echo "🚀 INICIANDO SETUP (MÉTODO MANUAL DIRECTO)..."
echo "   Vamos a instalar las extensiones 'a mano' para que no fallen."

# ------------------------------------------------------------------------------
# 1. BASE Y DEPENDENCIAS
# ------------------------------------------------------------------------------
echo "📦 [1/8] Actualizando base..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip sassc \
    gnome-tweaks gnome-shell-extensions dconf-editor \
    imagemagick gdm libgdm gnome-backgrounds papirus-icon-theme \
    ttf-fira-code flatpak gettext

# ------------------------------------------------------------------------------
# 2. ENTORNO DE DESARROLLO
# ------------------------------------------------------------------------------
echo "🛠 [2/8] Configurando Dev..."
sudo pacman -S --needed --noconfirm python python-pip jdk-openjdk maven nodejs npm docker docker-compose zsh fastfetch

# VS Code
if pacman -Qi code &> /dev/null; then
    echo "      ✅ VS Code (OSS) detectado."
elif pacman -Qi visual-studio-code-bin &> /dev/null; then
    echo "      ✅ VS Code (Bin) detectado."
else
    echo "      ⬇️ Instalando VS Code..."
    yay -S --noconfirm visual-studio-code-bin
fi

# Docker y ZSH
sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker $USER 2>/dev/null || true

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "      🐚 Instalando Zsh..."
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

# ------------------------------------------------------------------------------
# 3. TERMINAL BLACK BOX
# ------------------------------------------------------------------------------
echo "🖥️ [3/8] Instalando Terminal Black Box..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.raggesilver.BlackBox -y

# ------------------------------------------------------------------------------
# 4. TEMAS
# ------------------------------------------------------------------------------
echo "🎨 [4/8] Temas..."
if [ ! -d "$HOME/.themes/WhiteSur-Dark" ]; then
    rm -rf /tmp/WhiteSur-gtk-theme
    git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
    cd /tmp/WhiteSur-gtk-theme
    ./install.sh -t all -N stable
    sudo ./tweaks.sh -g -b blank -i arch -o normal
    cd ~
fi
yay -S --needed --noconfirm capitaine-cursors

# ------------------------------------------------------------------------------
# 5. EXTENSIONES (INSTALACIÓN MANUAL)
# ------------------------------------------------------------------------------
echo "🧩 [5/8] Instalando Extensiones (Método Manual)..."
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXT_DIR"

# --- 1. DASH TO DOCK (AUR es seguro, pero por consistencia...) ---
yay -S --needed --noconfirm gnome-shell-extension-dash-to-dock

# --- 2. WOBBLY WINDOWS (Desde GitHub) ---
# UUID: wobbly-windows@guauu.github.com
echo "      ⬇️ Descargando Wobbly Windows (Gelatina)..."
target="$EXT_DIR/wobbly-windows@guauu.github.com"
rm -rf "$target" /tmp/wobbly
git clone https://github.com/guauu/gnome-shell-extension-wobbly-windows.git /tmp/wobbly
mv /tmp/wobbly "$target"
# Compilamos esquema por si acaso
cd "$target"
glib-compile-schemas schemas 2>/dev/null || true
cd ~

# --- 3. MEDIA CONTROLS (Desde Release Zip) ---
# UUID: mediacontrols@cliffniff.github.io
echo "      ⬇️ Descargando Media Controls (Spotify)..."
target="$EXT_DIR/mediacontrols@cliffniff.github.io"
rm -rf "$target" /tmp/media.zip
# Descargamos el ZIP pre-compilado para no necesitar compilar typescript
wget -qO /tmp/media.zip https://github.com/cliffniff/media-controls/releases/latest/download/mediacontrols@cliffniff.github.io.zip
mkdir -p "$target"
unzip -oq /tmp/media.zip -d "$target"

# Limpieza de la de fuego
rm -rf "$EXT_DIR/burn-my-windows@schneegans.github.com"

# ------------------------------------------------------------------------------
# 6. CONFIGURACIÓN VISUAL
# ------------------------------------------------------------------------------
echo "⚙️ [6/8] Ajustes Visuales..."
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors' || true
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-d.svg'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-d.svg'
gsettings set org.gnome.desktop.notifications show-banners true
gsettings set org.gnome.desktop.interface enable-animations true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

# ------------------------------------------------------------------------------
# 7. DOCK
# ------------------------------------------------------------------------------
echo "⚓ [7/8] Configurando Dock..."
SCHEMA="org.gnome.shell.extensions.dash-to-dock"
gsettings set $SCHEMA dock-position 'BOTTOM' 2>/dev/null || true
gsettings set $SCHEMA dock-fixed true 2>/dev/null || true
gsettings set $SCHEMA transparency-mode 'FIXED' 2>/dev/null || true
gsettings set $SCHEMA background-opacity 0.2 2>/dev/null || true
gsettings set $SCHEMA dash-max-icon-size 48 2>/dev/null || true
gsettings set $SCHEMA click-action 'minimize' 2>/dev/null || true
gsettings set $SCHEMA show-mounts false 2>/dev/null || true

# ------------------------------------------------------------------------------
# 8. FINALIZACIÓN
# ------------------------------------------------------------------------------
echo "🔐 [8/8] Activando..."
sudo systemctl enable -f gdm

# Activamos las extensiones instaladas manualmente
gnome-extensions enable dash-to-dock@micxgx.gmail.com 2>/dev/null || true
gnome-extensions enable wobbly-windows@guauu.github.com 2>/dev/null || true
gnome-extensions enable mediacontrols@cliffniff.github.io 2>/dev/null || true

echo "======================================================="
echo "✅ ¡TODO INSTALADO CORRECTAMENTE!"
echo "======================================================="
echo "   Esta vez se descargaron los archivos directo a tu carpeta."
echo "   No hay forma de que falle."
echo "======================================================="
echo "🔄 REINICIANDO SISTEMA EN 5 SEGUNDOS..."
sleep 5
reboot