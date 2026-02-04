#!/bin/bash

# Corrección: Asegúrate de usar la variable correcta (SPARK_HOME suele ser con un solo guion bajo)
SPARK_HOME=${SPARK_HOME:-"/opt/spark"} 

case "$SPARK_ROLE" in
    "master")
        echo "--> Iniciando el Spark MASTER"
        start-master.sh
        # Mantenemos vivo el log
        tail -f $SPARK_HOME/logs/*
        ;;
    "worker")
        echo "--> Iniciando el Spark WORKER"
        if [ -z "$SPARK_MASTER_URL" ]; then
            echo "ERROR: Debes definir SPARK_MASTER_URL para el worker"
            exit 1
        fi
        start-worker.sh "$SPARK_MASTER_URL"
        tail -f $SPARK_HOME/logs/*
        ;;
    "submit")
        echo "--> Iniciando nodo SUBMIT (Cliente)"
        
        # LÓGICA MEJORADA:
        # Si se pasan argumentos al comando (ej: spark-submit --version), ejecútalos.
        # Si NO hay argumentos, mantén el contenedor vivo (tail -f /dev/null).
        if [ $# -gt 0 ]; then
            exec "$@"
        else
            echo "Sin comandos específicos. Manteniendo contenedor vivo..."
            tail -f /dev/null
        fi
        ;;
    *)
        echo "Rol no reconocido: '$SPARK_ROLE'"
        echo "Usa la variable de entorno: SPARK_ROLE=master|worker|submit"
        exit 1
        ;;
esac