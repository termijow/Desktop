#!/bin/bash
set -e

echo "🚀 Actualizando sistema..."
sudo pacman -Syu --noconfirm

echo "📦 Instalando herramientas básicas..."
sudo pacman -S --noconfirm git base-devel curl wget

echo "🐳 Instalando Docker..."
sudo pacman -S --noconfirm docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

echo "💻 Instalando Node.js y npm..."
sudo pacman -S --noconfirm nodejs npm

echo "🖊 Instalando VSCode..."
sudo pacman -S --noconfirm code

echo "🖼 Instalando Flatpak (para Spotify)..."
sudo pacman -S --noconfirm flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "🎵 Instalando Spotify vía Flatpak..."
sudo flatpak install -y flathub com.spotify.Client

echo "✅ Todo listo. Cierra sesión y vuelve a entrar para que Docker funcione sin sudo."
