#!/bin/bash

# 1. Actualizar el sistema
echo "--- Actualizando lista de paquetes ---"
sudo apt-get update

# 2. Instalar herramientas necesarias para permitir HTTPS
echo "--- Instalando dependencias previas ---"
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 3. Añadir la clave oficial GPG de Docker
echo "--- Añadiendo clave GPG de Docker ---"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. Configurar el repositorio estable de Docker
echo "--- Configurando repositorio de Docker ---"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Instalar Docker Engine
echo "--- Instalando Docker ---"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 6. Configurar permisos (para no usar sudo siempre con docker)
echo "--- Configurando permisos de usuario ---"
sudo usermod -aG docker ubuntu

# 7. Reiniciar permisos de grupo en la sesión actual (o pedir reinicio)
echo "--- INSTALACIÓN COMPLETADA ---"
echo "Por favor, sal de la sesión (exit) y vuelve a entrar para aplicar los cambios de grupo."
