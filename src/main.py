from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum, round, desc, current_timestamp
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType, DateType
import sys

def main():
    # 1. Inicialización de la Sesión Spark (Optimizado para S3)
    spark = SparkSession.builder \
        .appName("Comercio360_Analytics") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.aws.credentials.provider", "com.amazonaws.auth.DefaultAWSCredentialsProviderChain") \
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

    # 3. Transformaciones (Lógica de Negocio)
    
    # KPI 1: Ventas Totales por Categoría
    # Hacemos Join de Items -> Products
    ventas_detalle = df_items.join(df_products, "product_id")
    
    # Calculamos el total de venta por línea (cantidad * precio)
    ventas_detalle = ventas_detalle.withColumn("total_linea", col("quantity") * col("unit_price"))

    kpi_categoria = ventas_detalle.groupBy("category") \
        .agg(round(sum("total_linea"), 2).alias("ingresos_totales")) \
        .orderBy(desc("ingresos_totales"))

    print("--- KPI 1: Top Categorías por Ingresos ---")
    kpi_categoria.show()

    # KPI 2: Ventas por Método de Pago (Análisis Financiero)
    # Join Orders -> Items (para tener el montante)
    # Primero agrupamos items por order_id para tener el total del pedido
    total_pedido = df_items.groupBy("order_id") \
        .agg(sum(col("quantity") * col("unit_price")).alias("monto_pedido"))
    
    finanzas = df_orders.join(total_pedido, "order_id")
    
    kpi_pagos = finanzas.groupBy("payment_method") \
        .agg(round(sum("monto_pedido"), 2).alias("volumen_transaccionado")) \
        .orderBy(desc("volumen_transaccionado"))

    print("--- KPI 2: Volumen por Método de Pago ---")
    kpi_pagos.show()

    # 4. Escritura de Resultados (Data Lake - Capa Analytics)
    # Guardamos en formato PARQUET (columnar, comprimido, estándar Big Data)
    
    print(f"Escribiendo resultados en: {output_path}")
    
    kpi_categoria.write.mode("overwrite").parquet(f"{output_path}/ventas_por_categoria")
    kpi_pagos.write.mode("overwrite").parquet(f"{output_path}/ventas_por_metodo_pago")

    print("--- Procesamiento Finalizado Exitosamente ---")
    spark.stop()

if __name__ == "__main__":
    main()