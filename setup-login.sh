#!/bin/bash
set -e

# Verificar no root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Ejecuta este script como usuario normal, NO como root."
  exit
fi

echo "========================================"
echo "🍏 Configuración de Login Screen (GDM)"
echo "   Cambio de SDDM/LightDM a GDM"
echo "   Estética limpia (Sin logos de Apple)"
echo "========================================"

# 1. Instalar GDM y herramientas
echo "📦 Verificando GDM..."
sudo pacman -S --needed --noconfirm gdm libgdm imagemagick

# 2. Descargar el tema
echo "🖌️ Preparando archivos del tema..."
rm -rf /tmp/WhiteSur-gtk-theme
git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
cd /tmp/WhiteSur-gtk-theme

# 3. Aplicar el tema al Login Screen
echo "🎨 Aplicando estética..."
# Explicación de las opciones:
# -g : Aplicar a GDM
# -b blank : Fondo limpio/oscuro (o desenfocado si detecta wallpaper)
# -i arch  : Usa el logo de Arch Linux en lugar del de Apple
# -o normal : Opacidad normal para los cuadros de texto
sudo ./tweaks.sh -g -b blank -i arch -o normal

# 4. Cambiar el Gestor de Arranque (La corrección clave)
echo "🔄 Configurando el arranque..."

# Intentamos desactivar los gestores comunes para evitar conflictos
# Usamos '|| true' para que si no tienes uno instalado, el script no falle
sudo systemctl disable sddm 2>/dev/null || true
sudo systemctl disable lightdm 2>/dev/null || true

# Forzamos (-f) la activación de GDM. Esto sobreescribe el error que te dio antes.
sudo systemctl enable -f gdm

echo "========================================"
echo "✅ Configuración terminada con éxito."
echo "⚠️  El sistema se reiniciará en 5 segundos para aplicar el cambio."
echo "========================================"
sleep 5
reboot