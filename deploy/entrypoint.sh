#!/bin/bash

case "$SPARK_ROLE" in
    "master")
        echo "--> Iniciando el Spark MASTER"
        # Iniciamos el Master y dejamos el log en primer plano para que Docker no se cierre
        start-master.sh
        # Para mantener el contenedor vivo viendo los logs
        tail -f $SPARK__HOME/logs/*
        ;;
    "worker")
        echo "--> Iniciando el Spark WORKER"
        #Verificamos que se haya pasado la IP del Master
        if [ -z "$SPARK_MASTER_URL"]; then
            echo "ERROR: Debes definir SPARK_MASTER_URL para el worker"
            exit 1
        fi
        start-worker.sh "$SPARK_MASTER_URL"
        # Para mantener el contenedor vivo viendo los logs
        tail -f $SPARK__HOME/logs/*
        ;;
    
    "submit")
        echo "--> Iniciando nodo SUBMIT (Cliente)"
        echo "Listo para enviar trabajos. Manteniendo contenedor vivo..."
        #Bucle infinito para que no se apague, esperando tus comandos
        tail -f /dev/null
        ;;
    *)
        echo "Rol no reconocido: $SPARK_ROLE"
        echo "Usa: master | worker | submit"
        exit 1
        ;;
esac
