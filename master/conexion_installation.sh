#--- Si da problemas de permisos, ejecutar esto (Es en Terminal)---
icacls "labsuser.pem" /inheritance:r

icacls "labsuser.pem" /grant:r "$($env:USERNAME):F"

ssh -i "labsuser.pem" ubuntu@44.192.33.183

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

# 2. Construimos la imagen
sudo docker build -t mi-spark-image:v1 .

#--- Probar la imagen (Es en Terminal)---
sudo docker run -it --rm -e SPARK_ROLE=submit mi-spark-image:v1 /opt/spark/bin/spark-submit --version

# Generamsos el docker-compose.yml para desplegar el cluster de Spark
nano docker-compose.yml

# Compronamos que el archivo se ha generado correctamente
sudo docker ps

