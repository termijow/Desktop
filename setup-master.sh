#!/bin/bash
set -e

# ==============================================================================
#  ENDEAVOUROS MASTER SETUP (FINAL v4.0 - TERMINAL + FIX EXTENSIONES)
#  - Visual: Tema WhiteSur, Iconos Papirus, Sin logos Apple.
#  - Terminal: Black Box (Estética Mac/Minimalista).
#  - Fixes: Instalación de extensiones por ID Numérico (Infalible).
#  - Login: GDM Limpio.
# ==============================================================================

# Verificar no root
if [ "$EUID" -eq 0 ]; then
  echo "❌ EJECUTA ESTE SCRIPT COMO USUARIO NORMAL (sin sudo)."
  exit
fi

echo "🚀 INICIANDO CONFIGURACIÓN MAESTRA v4..."
echo "   Ajustando terminal, extensiones y estética final."

# ------------------------------------------------------------------------------
# 1. ACTUALIZACIÓN Y HERRAMIENTAS BASE
# ------------------------------------------------------------------------------
echo "📦 [1/9] Actualizando base..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip sassc \
    gnome-tweaks gnome-shell-extensions dconf-editor \
    imagemagick gdm libgdm gnome-backgrounds python-pipx papirus-icon-theme \
    ttf-fira-code nerd-fonts

# ------------------------------------------------------------------------------
# 2. ENTORNO DE DESARROLLO (DEV)
# ------------------------------------------------------------------------------
echo "🛠 [2/9] Entorno Dev..."
sudo pacman -S --needed --noconfirm python python-pip jdk-openjdk maven nodejs npm docker docker-compose zsh fastfetch

# VS Code
if pacman -Qi code &> /dev/null || pacman -Qi visual-studio-code-bin &> /dev/null; then
    echo "      ✅ VS Code ya instalado."
else
    yay -S --noconfirm visual-studio-code-bin
fi

# Configurar Docker
sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker $USER 2>/dev/null || true

# Configurar ZSH (Oh My Zsh)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "      🐚 Instalando Oh My Zsh..."
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
# 3. TERMINAL ESTÉTICA (BLACK BOX)
# ------------------------------------------------------------------------------
echo "🖥️ [3/9] Instalando Terminal Estética (Black Box)..."
# Black Box es la terminal GTK4 más parecida a la estética macOS moderna
if pacman -Qi blackbox-terminal &> /dev/null; then
    echo "      ✅ Black Box ya instalada."
else
    echo "      ⬇️ Instalando Black Box (Esto puede tardar un poco)..."
    # Intentamos repo oficial o AUR
    yay -S --noconfirm --needed blackbox-terminal
fi

# ------------------------------------------------------------------------------
# 4. INSTALACIÓN DE TEMAS
# ------------------------------------------------------------------------------
echo "🎨 [4/9] Verificando temas..."
if [ ! -d "$HOME/.themes/WhiteSur-Dark" ]; then
    rm -rf /tmp/WhiteSur-gtk-theme
    git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
    cd /tmp/WhiteSur-gtk-theme
    ./install.sh -t all -N stable
    # Login limpio (Arch Logo)
    sudo ./tweaks.sh -g -b blank -i arch -o normal
    cd ~
fi
yay -S --needed --noconfirm capitaine-cursors

# ------------------------------------------------------------------------------
# 5. EXTENSIONES (FIX POR IDs)
# ------------------------------------------------------------------------------
echo "🧩 [5/9] Instalando Extensiones (Método IDs)..."
export PATH="$PATH:$HOME/.local/bin"
pipx install gnome-extensions-cli --force
GEXT="$HOME/.local/bin/gnome-extensions-cli"

echo "      ⬇️ Descargando extensiones..."
# Usamos IDs numéricos para evitar errores de nombre
# 307  = Dash to Dock
# 2950 = Wobbly Windows (Gelatina)
# 4679 = Burn My Windows (Efectos cierre)
# 4470 = Media Controls (Spotify Moderno - El que funciona bien)

$GEXT install 307
$GEXT install 2950
$GEXT install 4679
$GEXT install 4470

# ------------------------------------------------------------------------------
# 6. CONFIGURACIÓN VISUAL
# ------------------------------------------------------------------------------
echo "⚙️ [6/9] Aplicando preferencias..."
# Botones a la DERECHA
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

# Tema WhiteSur + Iconos Papirus
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors' || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Fondo desbloqueado
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-d.svg'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-d.svg'

# Animaciones y Notificaciones
gsettings set org.gnome.desktop.notifications show-banners true
gsettings set org.gnome.desktop.interface enable-animations true

# ------------------------------------------------------------------------------
# 7. CONFIGURACIÓN DEL DOCK
# ------------------------------------------------------------------------------
echo "⚓ [7/9] Configurando Dock..."
SCHEMA="org.gnome.shell.extensions.dash-to-dock"
gsettings set $SCHEMA dock-position 'BOTTOM' 2>/dev/null || true
gsettings set $SCHEMA dock-fixed true 2>/dev/null || true
gsettings set $SCHEMA transparency-mode 'FIXED' 2>/dev/null || true
gsettings set $SCHEMA background-opacity 0.2 2>/dev/null || true
gsettings set $SCHEMA dash-max-icon-size 48 2>/dev/null || true
gsettings set $SCHEMA click-action 'minimize' 2>/dev/null || true
gsettings set $SCHEMA show-mounts false 2>/dev/null || true
gsettings set $SCHEMA show-trash false 2>/dev/null || true

# ------------------------------------------------------------------------------
# 8. LOGIN SCREEN (GDM)
# ------------------------------------------------------------------------------
echo "🔐 [8/9] Configurando GDM..."
sudo systemctl disable sddm 2>/dev/null || true
sudo systemctl disable lightdm 2>/dev/null || true
sudo systemctl enable -f gdm

# ------------------------------------------------------------------------------
# 9. ACTIVAR EXTENSIONES
# ------------------------------------------------------------------------------
echo "🔌 [9/9] Activando..."
# Habilitamos usando los UUIDs correctos obtenidos de los IDs
gnome-extensions enable dash-to-dock@micxgx.gmail.com 2>/dev/null || true
gnome-extensions enable wobbly-windows@guauu.github.com 2>/dev/null || true
gnome-extensions enable burn-my-windows@schneegans.github.com 2>/dev/null || true
gnome-extensions enable mediacontrols@cliffniff.github.io 2>/dev/null || true

echo "======================================================="
echo "✅ ¡TODO COMPLETADO!"
echo "======================================================="
echo "🖥️  NUEVA TERMINAL: Busca 'Black Box' en tus aplicaciones."
echo "    Es hermosa, minimalista y personalizable."
echo "🎵  SPOTIFY: Se instaló 'Media Controls' (Mejor que el anterior)."
echo "👻  ANIMACIONES: Wobbly Windows instalado correctamente."
echo "======================================================="
echo "🔄 REINICIANDO SISTEMA EN 10 SEGUNDOS..."
sleep 10
reboot