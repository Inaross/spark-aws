#--- Ejemplo de conexión a la instancia EC2 Master (Es en Terminal)---
ssh -i "labsuser.pem" ubuntu@44.220.184.112

#--- Script de instalación de Docker y construcción de imagen (Es en Terminal)---
# 1. Volvemos a la raíz y actualizamos cambios
cd ~/spark-aws
git pull

# 2. Entramos a la carpeta deploy (donde ahora está TODO)
cd deploy

# 3. Damos permisos a los DOS scripts
chmod +x dockerInstall.sh
chmod +x entrypoint.sh

# 4. Instalamos Docker
echo "--- INSTALANDO DOCKER ---"
./dockerInstall.sh

# 5. Construimos la imagen
newgrp docker << END
    echo "--- CONSTRUYENDO IMAGEN ---"
    docker build -t mi-spark-image:v1 .
END


#--- Ejecutar esto en caso de error. (Es en Terminal)---
# Proceso: Corregir el error que provendrá de los archivos > deploy/Dockerfile
# > Subir a GitHub > Bajar en la instancia EC2 > Reconstruir la imagen Docker
# 1. Bajamos la última versión
git pull

# 2. Construimos la imagen (con sudo)
sudo docker build -t mi-spark-image:v1 .