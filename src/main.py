#ESTE ES EL JOB PRINCIPAL DE PROCESAMIENTO DE DATOS PARA COMERCIO360
#Procesa datos de ventas desde S3, realiza análisis de ventas por categoría y método de pago, y almacena los resultados procesados de vuelta en S3.
# calcula análisis por categoría y método de pago, 
# y almacena los resultados procesados de vuelta en S3.

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as _sum, round, desc, rank, countDistinct, date_format, avg, stddev, when
from pyspark.sql.window import Window
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType, DateType
import sys

def main():
    # 1. Inicialización de la Sesión Spark (Optimizado para S3)
    spark = SparkSession.builder \
        .appName("Comercio360_Analytics") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .getOrCreate()


    # Validación de argumentos
    if len(sys.argv) != 2:
        print("Uso: main.py <nombre_bucket>")
        sys.exit(1)

    bucket_name = sys.argv[1]
    base_path = f"s3a://{bucket_name}/comercio360/raw"
    output_path = f"s3a://{bucket_name}/comercio360/analytics"

    print(f"--- Iniciando Procesamiento ETL para Comercio360 ---")
    print(f"Lectura desde: {base_path}")

    # 2. Lectura de Datos (Con esquemas definidos para mayor rendimiento)
    # Definimos esquemas para evitar que Spark tenga que "adivinar" (ahorra tiempo)
    
    products_schema = StructType([
        StructField("product_id", IntegerType(), True),
        StructField("product_name", StringType(), True),
        StructField("category", StringType(), True),
        StructField("list_price", DoubleType(), True)
    ])

    orders_schema = StructType([
        StructField("order_id", IntegerType(), True),
        StructField("customer_id", IntegerType(), True),
        StructField("store_id", IntegerType(), True),
        StructField("order_date", DateType(), True),
        StructField("payment_method", StringType(), True)
    ])

    items_schema = StructType([
        StructField("order_item_id", IntegerType(), True),
        StructField("order_id", IntegerType(), True),
        StructField("product_id", IntegerType(), True),
        StructField("quantity", IntegerType(), True),
        StructField("unit_price", DoubleType(), True),
        StructField("discount", DoubleType(), True)
    ])

    # Carga de DataFrames
    df_products = spark.read.csv(f"{base_path}/products.csv", header=True, schema=products_schema)
    df_orders = spark.read.csv(f"{base_path}/orders.csv", header=True, schema=orders_schema)
    df_items = spark.read.csv(f"{base_path}/order_items.csv", header=True, schema=items_schema)
    
# 3. Transformaciones (Punto 7 del Proyecto)
    
    # --- CONSULTA A: Top productos por facturación diaria ---
    print("--- Ejecutando Consulta A ---")
    df_join_a = df_orders.join(df_items, "order_id")
    
    df_agg_a = df_join_a.groupBy(col("order_date").alias("fecha"), col("product_id").alias("producto_id")) \
        .agg(
            _sum("quantity").alias("unidades"),
            round(_sum(col("quantity") * col("unit_price")), 2).alias("importe_total")
        )
        
    windowA = Window.partitionBy("fecha").orderBy(desc("importe_total"))
    df_consulta_a = df_agg_a.withColumn("ranking", rank().over(windowA)) \
        .filter(col("ranking") <= 10).orderBy("fecha", "ranking")
        
    df_consulta_a.show(5)

    # --- CONSULTA B: Ticket medio y clientes únicos por categoría (mensual) ---
    print("--- Ejecutando Consulta B ---")
    # Cruzamos pedidos, items y productos (para tener la categoría)
    df_join_b = df_orders.join(df_items, "order_id").join(df_products, "product_id")
    
    df_agg_b = df_join_b.withColumn("mes", date_format("order_date", "yyyy-MM")) \
        .groupBy("mes", "category") \
        .agg(
            countDistinct("customer_id").alias("clientes_unicos"),
            countDistinct("order_id").alias("num_pedidos"),
            round(_sum(col("quantity") * col("unit_price")), 2).alias("importe_total")
        )
        
    df_consulta_b = df_agg_b.withColumn("ticket_medio", round(col("importe_total") / col("num_pedidos"), 2)) \
        .orderBy(desc("mes"), "category")
        
    df_consulta_b.show(5)

    # --- CONSULTA C: Detección de outliers de ventas por tienda ---
    print("--- Ejecutando Consulta C ---")
    df_join_c = df_orders.join(df_items, "order_id")
    
    # 1. Ventas totales por día y tienda
    df_ventas_diarias = df_join_c.groupBy(col("store_id").alias("tienda_id"), col("order_date").alias("fecha")) \
        .agg(round(_sum(col("quantity") * col("unit_price")), 2).alias("ventas_dia"))
    
    # 2. Ventana de 30 días anteriores para calcular medias
    windowC = Window.partitionBy("tienda_id").orderBy("fecha").rowsBetween(-30, -1)
    
    df_consulta_c = df_ventas_diarias \
        .withColumn("media_30d", round(avg("ventas_dia").over(windowC), 2)) \
        .withColumn("desviacion_30d", round(stddev("ventas_dia").over(windowC), 2).na.fill(0)) \
        .withColumn("is_outlier", when(col("ventas_dia") > (col("media_30d") + 2 * col("desviacion_30d")), True).otherwise(False)) \
        .orderBy("tienda_id", "fecha")
        
    df_consulta_c.show(5)

    # --- PUNTO 10: Análisis del DAG ---
    print("--- PLAN DE EJECUCIÓN CONSULTA A (DAG) ---")
    df_consulta_a.explain(True)


    # 4. Escritura de Resultados (Data Lake - Capa Analytics)
    print(f"Escribiendo 3 consultas en: {output_path}")
    
    df_consulta_a.write.mode("overwrite").parquet(f"{output_path}/consulta_a_top_productos")
    df_consulta_b.write.mode("overwrite").parquet(f"{output_path}/consulta_b_ticket_medio")
    df_consulta_c.write.mode("overwrite").parquet(f"{output_path}/consulta_c_outliers")

    print("--- Procesamiento Finalizado Exitosamente ---")
    spark.stop()

if __name__ == "__main__":
    main()
