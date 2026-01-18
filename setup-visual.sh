#!/bin/bash
set -e

# Verificar no root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Ejecuta este script como usuario normal, NO como root."
  exit
fi

echo "==============================="
echo "🍎 GNOME macOS-like Setup"
echo "   EndeavourOS (Finalizando...)"
echo "==============================="

# 1. Herramientas Base (Se saltará si ya está listo)
echo "📦 Verificando herramientas..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip sassc gnome-tweaks gnome-shell-extensions dconf-editor

# 2. Dash to Dock (Se saltará si ya está listo)
echo "⚓ Verificando Dock..."
yay -S --noconfirm --needed gnome-shell-extension-dash-to-dock

# 3. Tema WhiteSur
# Como ya te salió "Done!" antes, el tema ya está en tu carpeta personal.
# No necesitamos volver a descargarlo ni compilarlo.
echo "✅ El tema WhiteSur ya está instalado (saltando paso de compilación)."

# 4. Instalar Iconos y Cursores (Aquí se quedó antes)
echo "🖱️ Instalando Iconos y Cursores..."
yay -S --noconfirm --needed whitesur-icon-theme-git
yay -S --noconfirm --needed capitaine-cursors

# 5. Configuración del Dock
echo "🎯 Configurando Dock..."
SCHEMA="org.gnome.shell.extensions.dash-to-dock"
# Aplicamos configuración (ignoramos errores si la extensión no está activa)
gsettings set $SCHEMA dock-position 'BOTTOM' 2>/dev/null || true
gsettings set $SCHEMA dock-fixed true 2>/dev/null || true
gsettings set $SCHEMA transparency-mode 'FIXED' 2>/dev/null || true
gsettings set $SCHEMA background-opacity 0.2 2>/dev/null || true
gsettings set $SCHEMA dash-max-icon-size 48 2>/dev/null || true
gsettings set $SCHEMA click-action 'minimize' 2>/dev/null || true
gsettings set $SCHEMA custom-theme-shrink true 2>/dev/null || true
gsettings set $SCHEMA show-mounts false 2>/dev/null || true
gsettings set $SCHEMA show-trash false 2>/dev/null || true

# 6. Aplicar Estilo Visual
echo "🛠 Aplicando Look & Feel..."

# Botones a la izquierda (Semáforo Mac)
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'

# Aplicar Temas
echo "🎨 Aplicando temas en GNOME..."
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' || true
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur' || true
gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors' || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Touchpad natural
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true

# Fuente (Opcional, para que se vea más limpio)
gsettings set org.gnome.desktop.interface font-name 'Cantarell 11'

echo "======================================================="
echo "✅ ¡Instalación completada!"
echo "🔄 REINICIA AHORA TU SISTEMA."
echo "======================================================="
echo "PASOS POST-REINICIO:"
echo "1. Abre la app 'Extensiones' (Extensions) y activa 'Dash to Dock'."
echo "2. Si ves los iconos viejos, abre 'Retoques' (Tweaks) y pon:"
echo "   - Aplicaciones: WhiteSur-Dark"
echo "   - Iconos: WhiteSur"
echo "======================================================="
