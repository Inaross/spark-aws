#--- Si da problemas de permisos, ejecutar esto (Es en Terminal)---
icacls "labsuser.pem" /inheritance:r

icacls "labsuser.pem" /grant:r "$($env:USERNAME):F"

ssh -i "labsuser.pem" ubuntu@44.192.33.183

#--- Ejemplo de conexión a la instancia EC2 Master (Es en Terminal)---
ssh -i "labsuser.pem" ubuntu@IP_PUBLICA

#---Conexión a ---
# 1. Actualizar repositorios e instalar Docker y Git
sudo apt-get update && sudo apt-get install -y docker.io git

# 2. Iniciar el servicio de Docker
sudo systemctl start docker
sudo systemctl enable docker

# 3. Clonar TU repositorio de Github actualizado
git clone https://github.com/Inaross/spark-aws.git

# 4. Entrar al directorio y construir la imagen
# (Asumo que el Dockerfile está en la carpeta 'deploy', si está en la raíz, quita el 'cd deploy')
cd spark-aws/deploy
sudo docker build -t mi-spark-image:v1 .

# Arranca el Master usando la red del host (vital para que los workers lo vean)
sudo docker run -d --net=host -e SPARK_ROLE=master --name spark-master mi-spark-image:v1

# Ejecutar en las máquinas WORKER-1, WORKER-2 y WORKER-3 RECORDANDO CAMBIAR IP_MASTER POR LA IP PÚBLICA DEL MASTER
sudo docker run -d --net=host -e SPARK_ROLE=worker -e SPARK_MASTER_URL=spark://IP_MASTER:7077 --name spark-worker mi-spark-image:v1

#RECORDAR CAMBIAR IP_MASTER POR LA IP PÚBLICA DEL MASTER
# Entramos en modo interactivo (-it) y con shell (/bin/bash)
sudo docker run -it --net=host --name spark-submit \
  -e SPARK_ROLE=submit \
  -e SPARK_MASTER_URL=spark://IP_MASTER:7077 \
  mi-spark-image:v1 /bin/bash

#RECORDAR CAMBIAR IP_MASTER POR LA IP PÚBLICA DEL MASTER
#Desde dentro del contenedor spark-submit, ejecutamos el comando para correr el ejemplo de SparkPi
/opt/spark/bin/spark-submit \
  --master spark://IP_MASTER:7077 \
  --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar 100

#Salimos de Spark-submit con exit y con el archivo generar_data.py lo metemos en la maquina Submit, instalamos python3-pip para instalar boto3 y luego ejecutamos el script para generar los datos en S3
sudo apt install python3-pip
sudo apt install python3-boto3 -y

#Para configurar las credenciales de AWS en la máquina Submit, e
#ejecutamos el siguiente comando para abrir o crear el archivo de credenciales en nano
#(Sustituir con tus propias credenciales indicado en el documento)
#Primero crear carpeta .aws en el home del usuario
mkdir -p ~/.aws
nano ~/.aws/credentials
    [default]
    export AWS_ACCESS_KEY_ID=PEGA_AQUI_TU_ACCESS_KEY
    export AWS_SECRET_ACCESS_KEY=PEGA_AQUI_TU_SECRET_KEY
    export AWS_SESSION_TOKEN=PEGA_AQUI_TU_SESSION_TOKEN

#Configuramos la region
nano ~/.aws/config
    [default]
    region=us-east-1
    output=json

#Ejecutamos este comando para generar los datos en S3 
#(Sustituir mi nombre por el que se tenga en el bucket y la ruta correcta del archivo)
#Si da error es porque no se ha copiado bien
python3 scripts/generar_datos.py --bucket comercio360-datos-alejandro --prefix comercio360/raw --seed 123
