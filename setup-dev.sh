#!/bin/bash
set -e

# Verificar no root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Ejecuta este script como usuario normal (./setup-dev.sh), no como root."
  exit
fi

echo "🚀 Iniciando configuración del entorno de desarrollo..."

# 1️⃣ Actualizar sistema e instalar herramientas base
# Se añade --needed para que no reinstale lo que ya tienes
echo "📦 Instalando herramientas base..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git wget curl unzip htop fastfetch zsh

# 2️⃣ Instalar Lenguajes
echo "🐍 Instalando Python, Node, Java..."
sudo pacman -S --needed --noconfirm python python-pip jdk-openjdk maven nodejs npm

# 3️⃣ Instalar Docker y Docker Compose
echo "🐳 Configurando Docker..."
sudo pacman -S --needed --noconfirm docker docker-compose
sudo systemctl enable --now docker
# Añadir usuario actual al grupo docker
sudo usermod -aG docker $USER

# 4️⃣ Instalar Visual Studio Code
echo "💻 Verificando Visual Studio Code..."
# Comprobamos si 'code' (repo oficial) o 'visual-studio-code-bin' (AUR) ya existen
if pacman -Qi code &> /dev/null || pacman -Qi visual-studio-code-bin &> /dev/null; then
    echo "✅ Visual Studio Code ya está instalado. Saltando instalación..."
else
    echo "⬇️ Instalando VS Code (versión binaria)..."
    yay -S --noconfirm visual-studio-code-bin
fi

# 5️⃣ Herramientas Frontend
echo "⚛️ Instalando herramientas globales de JS..."
# Configurar npm para usar una carpeta local y no requerir sudo
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"

# Instalar yarn y CLI tools
# Nota: Si ya están instalados, npm updateará o los dejará igual
npm install -g yarn @vue/cli @angular/cli typescript

# 6️⃣ Configurar ZSH y Oh My Zsh
echo "🐚 Configurando Zsh..."

# Instalar Oh My Zsh desatendido (Solo si no existe la carpeta)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "✅ Oh My Zsh ya está instalado."
fi

# Instalar plugins útiles
echo "🔌 Configurando plugins de Zsh..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true

# Crear .zshrc
cat <<EOT > ~/.zshrc
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git docker npm yarn zsh-autosuggestions zsh-syntax-highlighting)

source \$ZSH/oh-my-zsh.sh

# Alias para mostrar información del sistema
alias neofetch='fastfetch'

# Path para NPM global
export PATH=\$PATH:\$HOME/.npm-global/bin
EOT

# Cambiar shell por defecto
echo "🔑 Cambiando shell por defecto a Zsh (te pedirá contraseña)..."
# Verificamos si zsh ya es el shell actual para no pedir pass en vano
if [ "$SHELL" != "/usr/bin/zsh" ] && [ "$SHELL" != "/bin/zsh" ]; then
    chsh -s $(which zsh)
else
    echo "✅ Zsh ya es tu shell por defecto."
fi

echo "======================================================="
echo "✅ Entorno de desarrollo listo."
echo "🔁 Por favor REINICIA el sistema para aplicar cambios de Docker y Shell."
echo "======================================================="
