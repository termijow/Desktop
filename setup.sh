#!/bin/bash
# setup.sh - Instalación estable KDE + Latte Dock + utilidades

set -e  # Detener si algo falla

echo "Actualizando sistema..."
sudo pacman -Syu --noconfirm

echo "Instalando Plasma + aplicaciones esenciales..."
sudo pacman -S --noconfirm plasma-desktop plasma-wayland-session konsole dolphin kde-gtk-config

echo "Instalando Latte Dock (AUR)..."
yay -S --noconfirm latte-dock-git

echo "Instalando temas y utilidades KDE..."
sudo pacman -S --noconfirm breeze-icons kde-gtk-config kvantum qt5ct qt6ct

echo "Instalando fuentes útiles..."
sudo pacman -S --noconfirm ttf-jetbrains-mono ttf-dejavu

echo "Instalando navegadores..."
sudo pacman -S --noconfirm firefox
yay -S --noconfirm brave-bin

echo "Instalando Spotify (Snap precompilado para evitar errores de repo)..."
sudo pacman -S --noconfirm snapd
sudo systemctl enable --now snapd.socket
sudo snap install spotify

echo "Todo instalado. Reinicia tu sesión de KDE y disfruta :)"
