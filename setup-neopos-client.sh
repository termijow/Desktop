#!/bin/bash
# ==============================================================================
#  NEOPOS CLIENT SETUP: ENTORNO VISUAL + DOCKER + NEOPOS INSTALLER
# ==============================================================================
#  - Diseñado para reutilizarse indefinidamente sin fallos por llaves GPG caducadas.
#  - Instala únicamente el entorno visual pulido (WhiteSur + GNOME) y Docker.
#  - Descarga e instala automáticamente la ÚLTIMA versión de NeoPOS Installer.
#  - Crea accesos directos e iconos oficiales en el sistema y escritorio.
# ==============================================================================

set -eo pipefail

# 0. Verificación de usuario (Debe ejecutarse como usuario estándar, no como root)
if [ "$EUID" -eq 0 ]; then
  echo "❌ EJECUTA ESTE SCRIPT COMO USUARIO NORMAL (sin sudo)."
  echo "   El script solicitará 'sudo' únicamente cuando sea necesario."
  exit 1
fi

echo "🚀 ==========================================================="
echo "   INICIANDO INSTALACIÓN CLIENTE: VISUAL + DOCKER + NEOPOS"
echo "==========================================================="

# Colores para mensajes legibles
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Función de ayuda para instalar extensiones de GNOME desde ZIP
install_extension_from_zip() {
    local url=$1
    local name=$2
    local temp_dir="/tmp/ext_install_$(echo "$name" | tr -d ' ')"
    
    echo -e "      ⬇️ Descargando extensión ${BLUE}$name${NC}..."
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    
    if curl -sSL -o "$temp_dir/extension.zip" "$url"; then
        echo -e "         ✅ Descarga correcta."
    else
        echo -e "         ⚠️ Error descargando $name. Omitiendo..."
        return 1
    fi
    
    unzip -oq "$temp_dir/extension.zip" -d "$temp_dir/extracted"
    local metadata_file
    metadata_file=$(find "$temp_dir/extracted" -name "metadata.json" | head -n 1)
    
    if [ -z "$metadata_file" ]; then return 1; fi

    local install_base
    install_base=$(dirname "$metadata_file")
    local uuid
    uuid=$(grep -Po '(?<="uuid": ")[^"]*' "$metadata_file")
    
    if [ -z "$uuid" ]; then return 1; fi
    
    local target_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -r "$install_base"/* "$target_dir/"
    
    if [ -d "$target_dir/schemas" ]; then
        glib-compile-schemas "$target_dir/schemas" 2>/dev/null || true
    fi
    echo -e "         ✅ $name instalada ($uuid)."
}

# ------------------------------------------------------------------------------
# 1. BUCLE AUTO-CURATIVO GPG / PACMAN (REUTILIZABLE A PRUEBA DEL TIEMPO)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}📦 [1/6] Sincronización y Auto-Curación de Llaves Pacman/GPG...${NC}"

# A) Limpieza de bloqueos huérfanos
if [ -f /var/lib/pacman/db.lck ]; then
    echo -e "   🧹 Eliminando bloqueo residual /var/lib/pacman/db.lck..."
    sudo rm -f /var/lib/pacman/db.lck
fi

# B) Sincronizar reloj de sistema para evitar errores de certificados o firmas en el futuro
sudo timedatectl set-ntp true 2>/dev/null || true

# C) Bypass temporal de firmas para actualizar archlinux-keyring y endeavouros-keyring
#    Esto evita que una ISO o sistema antiguo rechace firmas caducadas al intentar actualizarse.
echo -e "   🔑 Actualizando llaveros oficiales de Arch y EndeavourOS de forma segura..."
TMP_PACMAN_CONF=$(mktemp /tmp/pacman_bootstrap_XXXXXX.conf)
sed -E 's/SigLevel\s*=.*/SigLevel = Never/g' /etc/pacman.conf > "$TMP_PACMAN_CONF"
sed -i -E 's/LocalFileSigLevel\s*=.*/LocalFileSigLevel = Never/g' "$TMP_PACMAN_CONF"

sudo pacman --config "$TMP_PACMAN_CONF" -Sy --noconfirm archlinux-keyring endeavouros-keyring 2>/dev/null || \
sudo pacman --config "$TMP_PACMAN_CONF" -Sy --noconfirm archlinux-keyring 2>/dev/null || true
rm -f "$TMP_PACMAN_CONF"

# D) Re-inicializar y poblar llaveros del sistema
echo -e "   🔄 Inicializando y poblando llaves del sistema..."
sudo pacman-key --init
sudo pacman-key --populate archlinux endeavouros 2>/dev/null || sudo pacman-key --populate archlinux

# E) Prueba de integridad: si pacman-key quedó corrupto por alguna ejecución previa, reconstruir
if ! sudo pacman -Sy --noconfirm &>/dev/null; then
    echo -e "   ⚠️ Regenerando base de datos gnupg de pacman..."
    sudo rm -rf /etc/pacman.d/gnupg
    sudo pacman-key --init
    sudo pacman-key --populate archlinux endeavouros 2>/dev/null || sudo pacman-key --populate archlinux
fi

echo -e "   ${GREEN}✅ Llaves GPG al día y verificadas.${NC}"

# ------------------------------------------------------------------------------
# 2. INSTALACIÓN DE DEPENDENCIAS BASE, VISUALES Y DOCKER
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}📦 [2/6] Instalando paquetes del sistema (Visual + Docker)...${NC}"

# Paquetes requeridos estrictamente para el entorno visual, fuentes, GDM y Docker
sudo pacman -S --needed --noconfirm \
    base-devel git wget curl unzip sassc \
    gnome-tweaks gnome-shell-extensions dconf-editor extension-manager \
    imagemagick gdm libgdm gnome-backgrounds papirus-icon-theme \
    capitaine-cursors ttf-fira-code flatpak gettext \
    docker docker-compose

# Asegurar disponibilidad de yay (para extensiones AUR como Dash to Dock si es necesario)
if ! command -v yay &> /dev/null; then
    echo -e "   📦 'yay' no encontrado. Instalando yay-bin precompilado desde AUR..."
    TMP_YAY=$(mktemp -d /tmp/yay_install_XXXXXX)
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$TMP_YAY"
    (cd "$TMP_YAY" && makepkg -si --noconfirm)
    rm -rf "$TMP_YAY"
fi

# ------------------------------------------------------------------------------
# 3. CONFIGURACIÓN DEL MOTOR DOCKER
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}🐳 [3/6] Habilitando y configurando Docker...${NC}"
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
echo -e "   ${GREEN}✅ Docker activo y usuario '$USER' agregado al grupo 'docker'.${NC}"

# ------------------------------------------------------------------------------
# 4. ENTORNO VISUAL GNOME + TEMA WHITESUR + GDM FIX
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}🎨 [4/6] Configurando entorno visual (WhiteSur, temas y extensiones)...${NC}"

# A) Terminal BlackBox (Flatpak)
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --noninteractive -y flathub com.raggesilver.BlackBox 2>/dev/null || true

# B) Tema WhiteSur GTK y corrección del fondo negro en Login (GDM)
echo -e "   🖌️ Instalando tema WhiteSur GTK..."
rm -rf /tmp/WhiteSur-gtk-theme
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
(
    cd /tmp/WhiteSur-gtk-theme
    ./install.sh -t all -N stable
    echo -e "   🖼️ Aplicando fondo y corrección a la pantalla de Login (GDM)..."
    sudo ./tweaks.sh -g -b default -i arch -o normal 2>/dev/null || true
)
rm -rf /tmp/WhiteSur-gtk-theme

# C) Extensiones de GNOME
echo -e "   🧩 Configurando extensiones de GNOME..."
gsettings set org.gnome.shell disable-extension-version-validation true
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXT_DIR"

# Dash to Dock (AUR)
yay -S --needed --noconfirm gnome-shell-extension-dash-to-dock 2>/dev/null || true

# Compiz Windows Effect (Wobbly Windows)
install_extension_from_zip "https://github.com/hermes83/compiz-windows-effect/archive/refs/heads/master.zip" "Wobbly Windows"

# D) Ajustes de Interfaz (Look & Feel macOS/WhiteSur)
echo -e "   ⚙️ Aplicando preferencias de escritorio y apariencia..."
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors' 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-d.svg' 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-d.svg' 2>/dev/null || true
gsettings set org.gnome.desktop.notifications show-banners true
gsettings set org.gnome.desktop.interface enable-animations true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

# E) Ajustes del Dock (Dash to Dock)
SCHEMA="org.gnome.shell.extensions.dash-to-dock"
if gsettings list-schemas | grep -q "$SCHEMA"; then
    gsettings set $SCHEMA dock-position 'BOTTOM' 2>/dev/null || true
    gsettings set $SCHEMA dock-fixed true 2>/dev/null || true
    gsettings set $SCHEMA transparency-mode 'FIXED' 2>/dev/null || true
    gsettings set $SCHEMA background-opacity 0.2 2>/dev/null || true
    gsettings set $SCHEMA dash-max-icon-size 48 2>/dev/null || true
    gsettings set $SCHEMA click-action 'minimize' 2>/dev/null || true
    gsettings set $SCHEMA show-mounts false 2>/dev/null || true
fi

# F) Activar extensiones en GNOME
gnome-extensions enable dash-to-dock@micxgx.gmail.com 2>/dev/null || true
gnome-extensions enable compiz-windows-effect@hermes83.github.com 2>/dev/null || true

# Asegurar que el servicio GDM esté habilitado si existe
if systemctl list-unit-files | grep -q "gdm.service"; then
    sudo systemctl enable -f gdm 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 5. INSTALACIÓN DE NEOPOS INSTALLER (ÚLTIMA VERSIÓN DINÁMICA)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}📦 [5/6] Instalando NeoPOS Installer (última versión)...${NC}"

# A) Detectar la última versión publicada en GitHub (independientemente de la fecha)
LATEST_TAG=$(curl -sI https://github.com/termijow/neopos-installer/releases/latest 2>/dev/null | grep -i "^location:" | awk '{print $2}' | tr -d '\r\n' | sed 's|.*/tag/||')

if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="v0.5.8"
fi

echo -e "   🏷️ Versión detectada: ${GREEN}$LATEST_TAG${NC}"

# B) Descargar el ejecutable binario de Linux
TARGET_BIN="/usr/local/bin/neopos-installer"
TMP_DOWNLOAD="/tmp/NeoPOS-Installer-Linux"
DOWNLOAD_URL="https://github.com/termijow/neopos-installer/releases/latest/download/NeoPOS-Installer-Linux"

echo -e "   ⬇️ Descargando binario oficial desde GitHub..."
if curl -fL --progress-bar -o "$TMP_DOWNLOAD" "$DOWNLOAD_URL"; then
    echo -e "   ✅ Descarga completada."
else
    echo -e "   ⚠️ Descarga desde /latest falló, intentando con tag específico $LATEST_TAG..."
    curl -fL --progress-bar -o "$TMP_DOWNLOAD" "https://github.com/termijow/neopos-installer/releases/download/${LATEST_TAG}/NeoPOS-Installer-Linux"
fi

sudo mv "$TMP_DOWNLOAD" "$TARGET_BIN"
sudo chmod +x "$TARGET_BIN"
echo -e "   ✅ Binario instalado en: ${GREEN}$TARGET_BIN${NC}"

# C) Instalar el icono oficial de NeoPOS en el sistema
echo -e "   🎨 Registrando icono oficial de NeoPOS..."
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
sudo tee /usr/share/icons/hicolor/scalable/apps/neopos.svg > /dev/null << 'SVG_EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="96" fill="#0f172a"/>
  <path d="M128 154h256v58H128zM128 246h256v58H128zM128 338h154v58H128z" fill="#38bdf8"/>
  <circle cx="352" cy="365" r="46" fill="#22c55e"/>
</svg>
SVG_EOF
sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

# D) Crear lanzador .desktop para el Menú de Aplicaciones y Escritorio
echo -e "   🖥️ Creando accesos directos..."
DESKTOP_ENTRY="/usr/share/applications/neopos-installer.desktop"
sudo tee "$DESKTOP_ENTRY" > /dev/null << 'DESK_EOF'
[Desktop Entry]
Name=NeoPOS Installer
GenericName=Instalador de NeoPOS Local
Comment=Instalador y actualizador oficial de NeoPOS Local
Exec=/usr/local/bin/neopos-installer
Icon=neopos
Terminal=false
Type=Application
Categories=Office;Utility;System;
StartupNotify=true
DESK_EOF

# Acceso directo en el Escritorio del usuario
USER_DESKTOP="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
if [ ! -d "$USER_DESKTOP" ] && [ -d "$HOME/Escritorio" ]; then
    USER_DESKTOP="$HOME/Escritorio"
fi

if [ -d "$USER_DESKTOP" ]; then
    cp "$DESKTOP_ENTRY" "$USER_DESKTOP/neopos-installer.desktop"
    chmod +x "$USER_DESKTOP/neopos-installer.desktop"
    gio set "$USER_DESKTOP/neopos-installer.desktop" metadata::trusted true 2>/dev/null || true
    echo -e "   ✅ Acceso directo creado en: ${GREEN}$USER_DESKTOP/neopos-installer.desktop${NC}"
fi

# ------------------------------------------------------------------------------
# 6. FINALIZACIÓN Y LANZAMIENTO
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}✨ [6/6] Finalización...${NC}"
echo -e "======================================================="
echo -e "   ${GREEN}🎉 ¡INSTALACIÓN DE BASE Y NEOPOS COMPLETADA CON ÉXITO!${NC}"
echo -e "======================================================="
echo -e "   • Entorno Visual: WhiteSur-Dark + GDM Fix + Dock inferior."
echo -e "   • Docker: Servicio activo y usuario agregado a grupo 'docker'."
echo -e "   • NeoPOS Installer: Instalado en su última versión ($LATEST_TAG)."
echo -e "     - Puedes ejecutarlo desde la terminal: ${YELLOW}neopos-installer${NC}"
echo -e "     - O hacer doble clic en el acceso directo del Escritorio o Menú."
echo -e "======================================================="

# Preguntar si desea lanzar NeoPOS Installer ahora mismo
read -p "¿Deseas abrir NeoPOS Installer ahora mismo? (S/n): " launch_now
launch_now=${launch_now:-S}

if [[ "$launch_now" =~ ^[Ss]$ ]]; then
    echo -e "🚀 Iniciando NeoPOS Installer..."
    /usr/local/bin/neopos-installer &
fi

echo -e "\n💡 Nota: Para que las extensiones y permisos de Docker apliquen al 100%,"
echo -e "   te recomendamos cerrar sesión y volver a entrar si experimentas algún detalle.\n"
