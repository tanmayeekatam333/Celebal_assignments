"""
Part 2: Data Cleaning
Cleans orders.csv and products.csv, validates emails, checks referential
integrity, writes cleaned CSVs plus a report of all issues found.
"""
import re
import os
import sys
import pandas as pd
from datetime import datetime

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def clean_orders(df: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    """
    Fix date formats (accepts 'YYYY-MM-DD HH:MM:SS' and 'DD-MM-YYYY'),
    handle NULL/empty customer_id.
    Returns (cleaned_df, issues_dict).
    """
    df = df.copy()
    issues = {"bad_date_format_fixed": 0, "unparseable_dates": 0, "null_customer_id": 0}

    def parse_date(val):
        if pd.isna(val) or str(val).strip() == "":
            return pd.NaT
        s = str(val).strip()
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
            try:
                return datetime.strptime(s, fmt)
            except ValueError:
                pass
        try:
            dt = datetime.strptime(s, "%d-%m-%Y")
            issues["bad_date_format_fixed"] += 1
            return dt
        except ValueError:
            issues["unparseable_dates"] += 1
            return pd.NaT

    df["order_date"] = df["order_date"].apply(parse_date)

    null_mask = df["customer_id"].isna() | (df["customer_id"].astype(str).str.strip() == "")
    issues["null_customer_id"] = int(null_mask.sum())
    df["customer_id"] = df["customer_id"].where(~null_mask, other=pd.NA)
    # keep as nullable integer where possible
    df["customer_id"] = pd.to_numeric(df["customer_id"], errors="coerce").astype("Int64")

    return df, issues


def clean_products(df: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    """Normalize product names: trim whitespace, title case."""
    df = df.copy()
    before = df["product_name"].copy()
    df["product_name"] = df["product_name"].astype(str).str.strip().str.title()
    changed = int((before.astype(str).str.strip().str.title() != before).sum())
    issues = {"product_names_normalized": changed}
    return df, issues


def validate_emails(df: pd.DataFrame) -> list:
    """Return list of customer_ids with invalid emails."""
    invalid_ids = []
    for _, row in df.iterrows():
        email = str(row.get("email", ""))
        if not EMAIL_RE.match(email):
            invalid_ids.append(row["customer_id"])
    return invalid_ids


def check_referential_integrity(orders_df: pd.DataFrame, order_items_df: pd.DataFrame) -> pd.DataFrame:
    """Find order_items rows whose order_id does not exist in orders."""
    valid_order_ids = set(orders_df["order_id"])
    orphans = order_items_df[~order_items_df["order_id"].isin(valid_order_ids)]
    return orphans


def run_pipeline(raw_dir: str = ".", out_dir: str = None):
    if out_dir is None:
        out_dir = raw_dir
    os.makedirs(out_dir, exist_ok=True)

    orders = pd.read_csv(f"{raw_dir}/orders.csv")
    products = pd.read_csv(f"{raw_dir}/products.csv")
    customers = pd.read_csv(f"{raw_dir}/customers.csv")
    order_items = pd.read_csv(f"{raw_dir}/order_items.csv")

    clean_orders_df, order_issues = clean_orders(orders)
    clean_products_df, product_issues = clean_products(products)
    invalid_emails = validate_emails(customers)
    orphan_items = check_referential_integrity(orders, order_items)

    # format order_date back to a consistent string for CSV output
    out_orders = clean_orders_df.copy()
    out_orders["order_date"] = out_orders["order_date"].dt.strftime("%Y-%m-%d %H:%M:%S")

    out_orders.to_csv(f"{out_dir}/orders_cleaned.csv", index=False)
    clean_products_df.to_csv(f"{out_dir}/products_cleaned.csv", index=False)
    customers.to_csv(f"{out_dir}/customers_cleaned.csv", index=False)
    order_items.to_csv(f"{out_dir}/order_items_cleaned.csv", index=False)

    report_lines = [
        "DATA QUALITY REPORT",
        "====================",
        f"Orders: fixed {order_issues['bad_date_format_fixed']} DD-MM-YYYY dates, "
        f"{order_issues['unparseable_dates']} unparseable dates, "
        f"{order_issues['null_customer_id']} NULL/empty customer_ids.",
        f"Products: normalized {product_issues['product_names_normalized']} product names.",
        f"Customers: {len(invalid_emails)} invalid emails found "
        f"(ids: {invalid_emails[:10]}{'...' if len(invalid_emails) > 10 else ''}).",
        f"Order items: {len(orphan_items)} rows reference a non-existent order_id "
        f"(item_ids: {list(orphan_items['item_id'])[:10]}"
        f"{'...' if len(orphan_items) > 10 else ''}).",
    ]
    report = "\n".join(report_lines)
    with open(f"{out_dir}/data_quality_report.txt", "w") as f:
        f.write(report)

    print(report)
    return {
        "order_issues": order_issues,
        "product_issues": product_issues,
        "invalid_emails": invalid_emails,
        "orphan_items": orphan_items,
    }


if __name__ == "__main__":
    _here = os.path.dirname(os.path.abspath(__file__))
    _raw = sys.argv[1] if len(sys.argv) > 1 else os.path.join(_here, "..", "data", "raw")
    _out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_here, "..", "data", "processed")
    run_pipeline(_raw, _out)
