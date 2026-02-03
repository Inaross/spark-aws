#Usamos Python 3.10 como imagen base sobre Debian (Slim) para que la imagen pese poco pero tenga lo necesario
FROM python:3.10-slim-bullseye

#Establecemos el directorio de trabajo dentro del contenedor
LABEL maintrainer="Alejandro - Desarrollador Aplicaciones Multiplataforma"
LABEL project="Cluster Spark AWS S3"
LABEL version="1.0"

#Evitar errores de interfaz en instalaciones
ENV DEBIAN_FRONTEND=noninteractive

#1. INSTALACION DE DEPENDENCIAS DEL SISTEMA
RUN apt-get update && apt-get install -y \
    openjdk-11-jre-headless \
    curl \
    wget \
    procps \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# 2. VARIABLES DE ENTORNO (Mapa del sistema)
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV SPARK_VERSION=3.5.0
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:&SPARK_HOME/sbin

# 3. INSTALACION DE APACHE SPARK
# Descargamos Spark oficial, lo descomprimimos, limpiamos el archivo zip para ahorrar espacio.

WORKDIR /opt
RUN wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    tar xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} spark && \
    rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

# 4. CONFIGURACION CRÍTICA PARA AWS S3 (PRO)
# LA MALLORIA FALLA AQUI. Descargamos los JAR necesarios para que Spark hable con S3
WORKDIR $SPARK_HOME/jars
RUN wget -q wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar

# 5. INSATALCION DEPENDENCIAS PYTHON
RUN pip install --no-cache-dir pyspark==${SPARK_VERSION} pandas boto3

# 6. PREPARAR EL ARRANQUE
WORKDIR /opt/spark-app
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# EXPONEMOS LOS PUERTOS CLAVE (Master UI, Worker UI, Spark Port)
EXPOSE 8080 7077 4040 7000-7010

# DEFINIMOS EL SCRIPT QUE SE EJECUTARÁ AL INICIAR
ENTRYPOINT ["/opt/entrypoint.sh"] 









