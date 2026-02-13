#--- Si da problemas de permisos, ejecutar esto (Es en Terminal)---
icacls "labsuser.pem" /inheritance:r

icacls "labsuser.pem" /grant:r "$($env:USERNAME):F"

#--- Ejemplo de conexión a la instancia EC2 Master (Es en Terminal)---
ssh -i "labsuser.pem" ubuntu@IP_PUBLICA

#Si en algún momento se ha establecido conexion en una sesion anterior y ahora da error de permisos seguir estos pasos
#Por ejemplo, en master, elimina
sudo docker rm -f spark-master

#PARA INICIAR LOS CONTENEDORES, SI YA SE HAN CREADO ANTES, SOLO HAY QUE INICIARLOS CON ESTOS COMANDO:
#Para MASTER:
sudo docker start spark-master

#Para WORKER-1, WORKER-2 y WORKER-3:
sudo docker start spark-worker

#Para SUBMIT:
sudo docker start spark-submit


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

# Crea el Master usando la red del host (vital para que los workers lo vean)
sudo docker run -d --net=host -e SPARK_ROLE=master --name spark-master mi-spark-image:v1

# Ejecutar en las máquinas WORKER-1, WORKER-2 y WORKER-3 porque esto crea al worker, donde está la IP es la del MASTER, CAMBIARLA.
sudo docker run -d --net=host -e SPARK_ROLE=worker -e SPARK_MASTER_URL=spark://172.31.27.125:7077 --name spark-worker mi-spark-image:v1

#RECORDAR CAMBIAR IP por la del MASTER POR la de cada uno
# Sirve para crear un contenedor spark-submit que se conecte al master usando la red del host para que puedan comunicarse correctamente
sudo docker run -it --net=host --name spark-submit \
  -e SPARK_ROLE=submit \
  -e SPARK_MASTER_URL=spark://172.31.27.125:7077 \
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
    aws_access_key_id = PEGA_AQUI...
    aws_secret_access_key = PEGA_AQUI...
    aws_session_token = PEGA_AQUI...

#Configuramos la region
nano ~/.aws/config
    [default]
    region=us-east-1
    output=json

#Ejecutamos este comando para generar los datos en S3 
#(Sustituir mi nombre por el que se tenga en el bucket y la ruta correcta del archivo)
#Si da error es porque no se ha copiado bien
python3 scripts/generar_datos.py --bucket comercio360-datos-alejandro --prefix comercio360/raw --seed 123

#Ejecutamos este comando para correr el script de Spark que procesa los datos generados en S3 y los guarda en formato Parquet, sustituyendo la IP por la del MASTER y la ruta del script
#Si da error ejecutando este comando revisar las credenciales porque cambian con cada ejecución del LABORATORIO
#Ir a archivo credentials y cambiarlas por las NUEVAS que se han generado, luego ejecutar este comando para correr el script de Spark
# 1. Recuperamos las claves NUEVAS que acabas de pegar
export AWS_ACCESS_KEY_ID=$(grep -i aws_access_key_id ~/.aws/credentials | cut -d'=' -f2 | tr -d ' \t')
export AWS_SECRET_ACCESS_KEY=$(grep -i aws_secret_access_key ~/.aws/credentials | cut -d'=' -f2 | tr -d ' \t')
export AWS_SESSION_TOKEN=$(grep -i aws_session_token ~/.aws/credentials | cut -d'=' -f2 | tr -d ' \t')
export AWS_DEFAULT_REGION=us-east-1

# 2. El comando con la configuración perfecta (450m)
# Cambiar el nombre del bucket al que tengas tu en S3 y la ruta del script main.py
sudo docker run --rm --net=host \
  -e SPARK_ROLE=submit \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
  -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
  -v ~/spark-aws:/app \
  mi-spark-image:v1 \
  /opt/spark/bin/spark-submit \
  --master spark://172.31.27.125:7077 \
  --conf spark.executor.memory=450m \
  --conf spark.driver.memory=450m \
  --conf spark.network.timeout=800s \
  --conf spark.executor.heartbeatInterval=60s \
  --conf spark.rpc.message.maxSize=512 \
  --packages org.apache.hadoop:hadoop-aws:3.3.4 \
  /app/src/main.py comercio360-datos-alejandro

#Comprobación de que ha salido bien
  #1.
  sudo snap install aws-cli --classic
  #2.
  aws sts get-caller-identity
  #3.
  aws s3 ls s3://comercio360-datos-alejandro/comercio360/analytics/

#Otra manera de comprobar:
python3 -c "import boto3; s3 = boto3.client('s3'); print('\n ARCHIVOS EN ANALYTICS:'); [print(o['Key']) for o in s3.list_objects_v2(Bucket='comercio360-datos-alejandro', Prefix='comercio360/analytics/')['Contents']]"
