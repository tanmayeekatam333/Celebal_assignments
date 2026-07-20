"""
Part 1: Data Generation
Generates orders.csv, order_items.csv, products.csv, customers.csv
with intentional data quality issues, as required by the spec.
"""
import csv
import os
import sys
import random
from datetime import datetime, timedelta

random.seed(42)

N_CUSTOMERS = 500
N_PRODUCTS = 500
N_ORDERS = 1500
N_ORDER_ITEMS = 4000

FIRST_NAMES = ["Aarav", "Vivaan", "Aditya", "Ishaan", "Kabir", "Ananya", "Diya",
               "Myra", "Sara", "Priya", "Rahul", "Neha", "Karan", "Pooja", "Arjun",
               "James", "Mary", "John", "Linda", "Robert", "Patricia", "Michael", "Jennifer"]
LAST_NAMES = ["Sharma", "Verma", "Gupta", "Reddy", "Iyer", "Nair", "Patel", "Khan",
              "Singh", "Das", "Smith", "Johnson", "Brown", "Davis", "Miller", "Wilson"]

CATEGORIES = {
    "Electronics": ["Mobiles", "Laptops", "Accessories", "Cameras"],
    "Clothing": ["Men", "Women", "Kids", "Footwear"],
    "Home": ["Furniture", "Kitchen", "Decor", "Bedding"],
    "Books": ["Fiction", "Non-Fiction", "Comics", "Academic"],
}

PRODUCT_WORDS = ["Pro", "Max", "Ultra", "Mini", "Classic", "Deluxe", "Basic",
                  "Smart", "Premium", "Eco", "Lite", "Plus"]

STATUSES = ["PLACED", "SHIPPED", "DELIVERED", "CANCELLED", "RETURNED"]
CUSTOMER_TYPES = ["REGULAR", "PREMIUM", "VIP"]

START_DATE = datetime(2023, 1, 1)
END_DATE = datetime(2026, 7, 20)  # "current date" — future-order test cases can exceed this


def random_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    seconds = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=seconds)


def make_messy_product_name(name: str) -> str:
    """Randomly inject extra spaces / mixed case issues into ~15% of names."""
    r = random.random()
    if r < 0.07:
        return "  " + name.lower() + "  "
    if r < 0.15:
        return name.upper()
    return name


def make_email(name: str, idx: int, invalid: bool) -> str:
    base = name.lower().replace(" ", ".")
    domains = ["example.com", "mail.com", "test.org", "shop.co.in"]
    if invalid:
        choice = random.choice(["no_at", "no_domain"])
        if choice == "no_at":
            return f"{base}{idx}{random.choice(domains)}"  # missing '@'
        else:
            return f"{base}{idx}@"  # missing domain
    return f"{base}{idx}@{random.choice(domains)}"


def generate_customers():
    rows = []
    n_invalid_email = int(N_CUSTOMERS * 0.02)
    invalid_idx = set(random.sample(range(N_CUSTOMERS), n_invalid_email))
    for i in range(1, N_CUSTOMERS + 1):
        fname = random.choice(FIRST_NAMES)
        lname = random.choice(LAST_NAMES)
        full_name = f"{fname} {lname}"
        reg_date = random_date(START_DATE, END_DATE - timedelta(days=1))
        rows.append({
            "customer_id": i,
            "customer_name": full_name,
            "email": make_email(full_name, i, invalid=(i - 1) in invalid_idx),
            "registration_date": reg_date.strftime("%Y-%m-%d %H:%M:%S"),
            "customer_type": random.choices(CUSTOMER_TYPES, weights=[0.6, 0.3, 0.1])[0],
        })
    return rows


def generate_products():
    rows = []
    for i in range(1, N_PRODUCTS + 1):
        category = random.choice(list(CATEGORIES.keys()))
        subcategory = random.choice(CATEGORIES[category])
        base_name = f"{subcategory} {random.choice(PRODUCT_WORDS)} {i}"
        rows.append({
            "product_id": i,
            "product_name": make_messy_product_name(base_name),
            "category": category,
            "subcategory": subcategory,
            "cost_price": round(random.uniform(5, 2000), 2),
        })
    return rows


def generate_orders(customer_ids, customers_reg_date):
    rows = []
    n_null_customer = int(N_ORDERS * 0.05)
    null_idx = set(random.sample(range(N_ORDERS), n_null_customer))

    # ~4% of orders get the wrong date format (DD-MM-YYYY) instead of YYYY-MM-DD HH:MM:SS
    n_wrong_fmt = int(N_ORDERS * 0.04)
    wrong_fmt_idx = set(random.sample(range(N_ORDERS), n_wrong_fmt))

    # small number of future-dated orders, for edge-case testing
    n_future = 5

    order_ids = []
    for i in range(1, N_ORDERS + 1):
        cust_id = "" if (i - 1) in null_idx else random.choice(customer_ids)
        if cust_id != "":
            min_date = datetime.strptime(customers_reg_date[cust_id], "%Y-%m-%d %H:%M:%S")
        else:
            min_date = START_DATE
        if min_date > END_DATE:
            min_date = START_DATE

        if i > N_ORDERS - n_future:
            odate = END_DATE + timedelta(days=random.randint(1, 30))  # future order
        else:
            odate = random_date(max(min_date, START_DATE), END_DATE)

        if (i - 1) in wrong_fmt_idx:
            date_str = odate.strftime("%d-%m-%Y")  # wrong format, no time component
        else:
            date_str = odate.strftime("%Y-%m-%d %H:%M:%S")

        status = random.choices(STATUSES, weights=[0.15, 0.2, 0.4, 0.1, 0.15])[0]
        rows.append({
            "order_id": i,
            "customer_id": cust_id,
            "order_date": date_str,
            "status": status,
            "region_code": random.choice(["N", "S", "E", "W", "C"]),
        })
        order_ids.append(i)
    return rows, order_ids


def generate_order_items(order_ids, product_ids):
    rows = []
    n_negative = int(N_ORDER_ITEMS * 0.03)
    negative_idx = set(random.sample(range(N_ORDER_ITEMS), n_negative))

    # a handful of items referencing a non-existent order_id, for referential-integrity testing
    n_orphan = 6
    max_order_id = max(order_ids)

    for i in range(1, N_ORDER_ITEMS + 1):
        if i > N_ORDER_ITEMS - n_orphan:
            oid = max_order_id + random.randint(1, 50)  # doesn't exist in orders.csv
        else:
            oid = random.choice(order_ids)

        qty = random.randint(1, 6)
        if (i - 1) in negative_idx:
            qty = -qty  # return

        discount = round(random.choice([0, 0, 0, 5, 10, 15, 20, 25, 30, 50]), 2)

        rows.append({
            "item_id": i,
            "order_id": oid,
            "product_id": random.choice(product_ids),
            "quantity": qty,
            "unit_price": round(random.uniform(5, 3000), 2),
            "discount_percent": discount,
        })
    return rows


def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main(out_dir: str = "."):
    os.makedirs(out_dir, exist_ok=True)

    customers = generate_customers()
    write_csv(f"{out_dir}/customers.csv", customers,
               ["customer_id", "customer_name", "email", "registration_date", "customer_type"])
    customers_reg_date = {c["customer_id"]: c["registration_date"] for c in customers}
    customer_ids = [c["customer_id"] for c in customers]

    products = generate_products()
    write_csv(f"{out_dir}/products.csv", products,
               ["product_id", "product_name", "category", "subcategory", "cost_price"])
    product_ids = [p["product_id"] for p in products]

    orders, order_ids = generate_orders(customer_ids, customers_reg_date)
    write_csv(f"{out_dir}/orders.csv", orders,
               ["order_id", "customer_id", "order_date", "status", "region_code"])

    order_items = generate_order_items(order_ids, product_ids)
    write_csv(f"{out_dir}/order_items.csv", order_items,
               ["item_id", "order_id", "product_id", "quantity", "unit_price", "discount_percent"])

    print(f"Generated: customers.csv ({len(customers)}), products.csv ({len(products)}), "
          f"orders.csv ({len(orders)}), order_items.csv ({len(order_items)}) -> {out_dir}/")


if __name__ == "__main__":
    default_out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "raw")
    out = sys.argv[1] if len(sys.argv) > 1 else default_out
    main(out)
