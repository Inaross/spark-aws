#--- Ejemplo de conexión a la instancia EC2 Master (Es en Terminal)---
ssh -i "labsuser.pem" ubuntu@IP_PUBLICA

#---Conexión a ---
# 1. Actualizar repositorios e instalar Docker y Git
sudo apt-get update && sudo apt-get install -y docker.io git

# 2. Iniciar el servicio de Docker
sudo systemctl start docker
sudo systemctl enable docker

# 3. Clonar TU repositorio actualizado
git clone https://github.com/Inaross/spark-aws.git

# 4. Entrar al directorio y construir la imagen
# (Asumo que el Dockerfile está en la carpeta 'deploy', si está en la raíz, quita el 'cd deploy')
cd spark-aws/deploy
sudo docker build -t mi-spark-image:v1 .

# Arranca el Master usando la red del host (vital para que los workers lo vean)
sudo docker run -d --net=host -e SPARK_ROLE=master --name spark-master mi-spark-image:v1

# Ejecutar en las máquinas WORKER-1, WORKER-2 y WORKER-3
sudo docker run -d --net=host -e SPARK_ROLE=worker -e SPARK_MASTER_URL=spark://172.31.27.125:7077 --name spark-worker mi-spark-image:v1

# Entramos en modo interactivo (-it) y con shell (/bin/bash)
sudo docker run -it --net=host --name spark-submit \
  -e SPARK_ROLE=submit \
  -e SPARK_MASTER_URL=spark://172.31.27.125:7077 \
  mi-spark-image:v1 /bin/bash

#Desde dentro del contenedor spark-submit, ejecutamos el comando para correr el ejemplo de SparkPi
/opt/spark/bin/spark-submit \
  --master spark://172.31.27.125:7077 \
  --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar 100