import argparse
import csv
import io
import random
import boto3
from datetime import datetime, timedelta
from decimal import Decimal

# Configuración de esquemas según PDF 
CATEGORIES = ['Electronica', 'Hogar', 'Moda', 'Deportes', 'Juguetes']
CITIES = ['Logroño', 'Madrid', 'Barcelona', 'Sevilla', 'Bilbao', 'Valencia']
PAYMENT_METHODS = ['card', 'cash', 'transfer', 'bizum']

def generate_data(args):
    s3 = boto3.client('s3')
    random.seed(args.seed)
    
    print(f"Generando datos para bucket: {args.bucket}, prefijo: {args.prefix}")

    # 1. Stores
    stores = []
    store_buffer = io.StringIO()
    writer = csv.writer(store_buffer)
    writer.writerow(['store_id', 'store_name', 'city'])
    for i in range(1, args.stores + 1):
        store_id = i
        stores.append(store_id)
        writer.writerow([store_id, f'Tienda {i}', random.choice(CITIES)])
    upload_to_s3(s3, args.bucket, f"{args.prefix}/stores.csv", store_buffer)

    # 2. Products
    products = []
    prod_buffer = io.StringIO()
    writer = csv.writer(prod_buffer)
    writer.writerow(['product_id', 'product_name', 'category', 'list_price'])
    for i in range(1, args.products + 1):
        prod_id = i
        price = round(random.uniform(10, 500), 2)
        products.append({'id': prod_id, 'price': price})
        writer.writerow([prod_id, f'Producto {i}', random.choice(CATEGORIES), price])
    upload_to_s3(s3, args.bucket, f"{args.prefix}/products.csv", prod_buffer)

    # 3. Customers
    customers = []
    cust_buffer = io.StringIO()
    writer = csv.writer(cust_buffer)
    writer.writerow(['customer_id', 'email', 'city', 'signup_date'])
    for i in range(1, args.customers + 1):
        cust_id = i
        customers.append(cust_id)
        date = (datetime(2023, 1, 1) + timedelta(days=random.randint(0, 365))).strftime("%Y-%m-%d")
        writer.writerow([cust_id, f'cliente{i}@email.com', random.choice(CITIES), date])
    upload_to_s3(s3, args.bucket, f"{args.prefix}/customers.csv", cust_buffer)

    # 4. Orders & Order Items
    orders_buffer = io.StringIO()
    items_buffer = io.StringIO()
    w_orders = csv.writer(orders_buffer)
    w_items = csv.writer(items_buffer)
    
    w_orders.writerow(['order_id', 'customer_id', 'store_id', 'order_date', 'payment_method'])
    w_items.writerow(['order_item_id', 'order_id', 'product_id', 'quantity', 'unit_price', 'discount'])
    
    item_counter = 1
    for i in range(1, args.orders + 1):
        order_id = i
        order_date = (datetime(2024, 1, 1) + timedelta(days=random.randint(0, 365))).strftime("%Y-%m-%d")
        w_orders.writerow([
            order_id, 
            random.choice(customers), 
            random.choice(stores), 
            order_date, 
            random.choice(PAYMENT_METHODS)
        ])
        
        # Items per order
        num_items = random.randint(1, args.max_items)
        for _ in range(num_items):
            prod = random.choice(products)
            qty = random.randint(1, 5)
            discount = round(random.uniform(0, 0.35), 2)
            final_price = round(prod['price'] * (1 - discount), 2)
            
            w_items.writerow([item_counter, order_id, prod['id'], qty, final_price, discount])
            item_counter += 1

    upload_to_s3(s3, args.bucket, f"{args.prefix}/orders.csv", orders_buffer)
    upload_to_s3(s3, args.bucket, f"{args.prefix}/order_items.csv", items_buffer)

def upload_to_s3(s3, bucket, key, buffer):
    print(f"Subiendo {key}...")
    s3.put_object(Body=buffer.getvalue(), Bucket=bucket, Key=key)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bucket', required=True)
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--seed', type=int, default=123)
    parser.add_argument('--customers', type=int, default=500)
    parser.add_argument('--products', type=int, default=150)
    parser.add_argument('--stores', type=int, default=10)
    parser.add_argument('--orders', type=int, default=4000)
    parser.add_argument('--max-items', type=int, default=6)
    
    args = parser.parse_args()
    generate_data(args)