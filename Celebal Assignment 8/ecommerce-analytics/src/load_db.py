"""Loads the *cleaned* CSVs into a local SQLite database (ecommerce.db)."""
import os
import sys
import sqlite3
import pandas as pd


def load(data_dir: str = ".", db_path: str = "ecommerce.db"):
    conn = sqlite3.connect(db_path)

    orders = pd.read_csv(f"{data_dir}/orders_cleaned.csv")
    products = pd.read_csv(f"{data_dir}/products_cleaned.csv")
    customers = pd.read_csv(f"{data_dir}/customers_cleaned.csv")
    order_items = pd.read_csv(f"{data_dir}/order_items_cleaned.csv")

    # drop rows with orphan order_ids so the SQL foreign-key logic stays clean
    valid_order_ids = set(orders["order_id"])
    order_items = order_items[order_items["order_id"].isin(valid_order_ids)]

    orders.to_sql("orders", conn, if_exists="replace", index=False)
    products.to_sql("products", conn, if_exists="replace", index=False)
    customers.to_sql("customers", conn, if_exists="replace", index=False)
    order_items.to_sql("order_items", conn, if_exists="replace", index=False)

    conn.execute("CREATE INDEX IF NOT EXISTS idx_oi_order ON order_items(order_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_oi_product ON order_items(product_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)")
    conn.commit()
    conn.close()
    print(f"Loaded into {db_path}: orders={len(orders)}, products={len(products)}, "
          f"customers={len(customers)}, order_items={len(order_items)}")


if __name__ == "__main__":
    _here = os.path.dirname(os.path.abspath(__file__))
    _data_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(_here, "..", "data", "processed")
    _db_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_here, "..", "data", "ecommerce.db")
    load(_data_dir, _db_path)
