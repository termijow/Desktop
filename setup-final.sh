#!/bin/bash
set -e

# Verificar no root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Ejecuta este script como usuario normal, NO como root."
  exit
fi

echo "========================================"
echo "🔧 Ajustes Finales (Personalización)"
echo "   - Botones a la derecha"
echo "   - Iconos genéricos (Papirus)"
echo "   - Fix Fondo de Pantalla"
echo "========================================"

# 1. Instalar Iconos Papirus (Limpios, sin estilo Apple) y Fondos GNOME
echo "📦 Instalando iconos Papirus y fondos de pantalla..."
sudo pacman -S --needed --noconfirm papirus-icon-theme gnome-backgrounds

# 2. Configurar Botones a la DERECHA (Estándar Windows/Linux)
echo "🪟 Moviendo botones a la derecha..."
# Los dos puntos ':' al principio indican que lo que sigue va a la derecha
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

# 3. Cambiar Iconos (Adiós Finder)
echo "📁 Cambiando tema de iconos a Papirus-Dark..."
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# 4. Arreglar Fondo de Pantalla (Quitar bloqueo de color sólido)
echo "🖼️ Desbloqueando fondo de pantalla..."
# Reseteamos opciones de dibujado
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.background primary-color '#000000'
gsettings set org.gnome.desktop.background secondary-color '#000000'
# Ponemos un fondo por defecto de GNOME para verificar que funcione
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-d.svg'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-d.svg'

# 5. Notificaciones (Spotify y otros)
echo "🔔 Activando notificaciones emergentes..."
gsettings set org.gnome.desktop.notifications show-banners true
gsettings set org.gnome.desktop.notifications show-in-lock-screen true

# 6. Asegurar Animaciones
echo "✨ Forzando animaciones..."
gsettings set org.gnome.desktop.interface enable-animations true

echo "========================================"
echo "✅ Ajustes aplicados."
echo "   - Ahora tus carpetas son azules/normales."
echo "   - Los botones están a la derecha."
echo "   - Ya deberías poder cambiar el fondo (Click derecho escritorio -> Configuración)."
echo "========================================"