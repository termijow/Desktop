#!/bin/bash

echo "=========================================================="
echo " Instalador Automático de Agentes para Antigravity CLI"
echo "=========================================================="
echo "Clonando repositorio de agentes en una carpeta temporal..."

# Descargar el repositorio en la carpeta temporal /tmp
git clone https://github.com/VoltAgent/awesome-claude-code-subagents.git /tmp/awesome-claude-code-subagents

echo "Instalando agentes globalmente en ~/.gemini/config/skills/..."
BASE_DEST=~/.gemini/config/skills

# Buscar todos los archivos .md (ignorando readmes)
matches=($(find /tmp/awesome-claude-code-subagents/categories -type f -name "*.md" | grep -v -i "readme"))

count=0
for agent_path in "${matches[@]}"; do
    agent_name=$(basename "$agent_path" .md)
    dest_dir="$BASE_DEST/$agent_name"
    
    mkdir -p "$dest_dir"
    cp "$agent_path" "$dest_dir/SKILL.md"
    
    ((count++))
done

echo "✅ Se instalaron un total de $count agentes exitosamente en: $BASE_DEST"

# Limpiar la carpeta temporal
echo "Limpiando archivos temporales..."
rm -rf /tmp/awesome-claude-code-subagents

echo "¡Todo listo! Tus agentes están instalados y listos para usar."
