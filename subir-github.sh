#!/bin/bash
# ==============================================================================
# Script para subir y sincronizar cambios del repositorio con GitHub
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Sincronizando cambios con GitHub..."

# 1. Asegurar repositorio Git y remoto configurado
if [ ! -d ".git" ]; then
    echo "📦 Inicializando repositorio git local..."
    git init -b main
    git remote add origin git@github.com:termijow/Desktop.git
fi

# Configurar identidad de Git si no existe
if [ -z "$(git config user.email)" ]; then
    git config user.name "termijow"
    git config user.email "termijow@gmail.com"
fi

# 2. Comprobar si hay cambios pendientes
if [ -z "$(git status --porcelain)" ]; then
    echo "✅ No hay cambios pendientes por subir. Todo está al día."
    exit 0
fi

echo "📝 Archivos modificados/nuevos:"
git status -s

# 3. Pedir mensaje de commit (o usar argumento o mensaje por defecto)
COMMIT_MSG="$1"
if [ -z "$COMMIT_MSG" ]; then
    echo ""
    read -r -p "💬 Mensaje del commit (Enter para 'Actualizar setup master'): " input_msg
    COMMIT_MSG="${input_msg:-Actualizar setup master}"
fi

# 4. Añadir cambios y crear commit
git add -A
git commit -m "$COMMIT_MSG"

# 5. Intentar subir cambios
echo "⬆️ Subiendo a GitHub (rama main)..."
if git push origin main; then
    echo ""
    echo "🎉 ¡Cambios subidos a GitHub exitosamente!"
else
    echo ""
    echo "⚠️ La subida falló por falta de autenticación."
    echo "💡 Puedes iniciar sesión en la terminal ejecutando:"
    echo "   gh auth login"
    echo "   (o configurar tu Personal Access Token / llave SSH)"
    echo "Luego vuelve a ejecutar: ./subir-github.sh"
    exit 1
fi
