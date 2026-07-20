"""
Part 4: Python + SQL Integration
Command-line tool: pick a report type (daily/weekly/monthly) + a date range,
connect to SQLite, print a summary report with a comparison to the
previous equivalent period. Uses only sqlite3 + argparse (both stdlib).
"""
import argparse
import os
import sqlite3
from datetime import datetime, timedelta

_HERE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(_HERE, "..", "data", "ecommerce.db")

PERIOD_DAYS = {"daily": 1, "weekly": 7, "monthly": 30}


def get_summary(conn, start: str, end: str) -> dict:
    cur = conn.cursor()

    cur.execute("""
        SELECT COUNT(DISTINCT o.order_id), COUNT(DISTINCT o.customer_id)
        FROM orders o
        WHERE o.order_date >= ? AND o.order_date < ?
    """, (start, end))
    total_orders, unique_customers = cur.fetchone()
    total_orders = total_orders or 0
    unique_customers = unique_customers or 0

    cur.execute("""
        SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)), 2)
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.order_id
        WHERE o.order_date >= ? AND o.order_date < ? AND oi.quantity > 0
    """, (start, end))
    revenue = cur.fetchone()[0] or 0.0

    cur.execute("""
        SELECT p.product_name,
               ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)), 2) AS rev
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.order_id
        JOIN products p ON p.product_id = oi.product_id
        WHERE o.order_date >= ? AND o.order_date < ? AND oi.quantity > 0
        GROUP BY p.product_name
        ORDER BY rev DESC
        LIMIT 3
    """, (start, end))
    top_products = cur.fetchall()

    return {
        "total_orders": total_orders,
        "revenue": revenue,
        "unique_customers": unique_customers,
        "top_products": top_products,
    }


def pct_change(current: float, previous: float):
    if not previous:
        return None
    return round(100.0 * (current - previous) / previous, 2)


def print_report(report_type: str, start_date: str, end_date: str, db_path: str = None):
    db_path = db_path or DB_PATH
    start_dt = datetime.strptime(start_date, "%Y-%m-%d")
    end_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)  # exclusive upper bound
    period_len = end_dt - start_dt
    prev_end_dt = start_dt
    prev_start_dt = prev_end_dt - period_len

    conn = sqlite3.connect(db_path)
    current = get_summary(conn, start_dt.strftime("%Y-%m-%d"), end_dt.strftime("%Y-%m-%d"))
    previous = get_summary(conn, prev_start_dt.strftime("%Y-%m-%d"), prev_end_dt.strftime("%Y-%m-%d"))
    conn.close()

    print(f"\n{'=' * 50}")
    print(f"{report_type.upper()} REPORT: {start_date} to {end_date}")
    print(f"{'=' * 50}")
    print(f"Total Orders:      {current['total_orders']}")
    print(f"Revenue:           {current['revenue']:,.2f}")
    print(f"Unique Customers:  {current['unique_customers']}")
    print("\nTop 3 Products:")
    if current["top_products"]:
        for name, rev in current["top_products"]:
            print(f"  - {name}: {rev:,.2f}")
    else:
        print("  (no sales in this period)")

    print(f"\nComparison with previous period "
          f"({prev_start_dt.date()} to {(prev_end_dt - timedelta(days=1)).date()}):")
    orders_chg = pct_change(current["total_orders"], previous["total_orders"])
    revenue_chg = pct_change(current["revenue"], previous["revenue"])
    customers_chg = pct_change(current["unique_customers"], previous["unique_customers"])
    print(f"  Orders:     {previous['total_orders']} -> {current['total_orders']} "
          f"({fmt_pct(orders_chg)})")
    print(f"  Revenue:    {previous['revenue']:,.2f} -> {current['revenue']:,.2f} "
          f"({fmt_pct(revenue_chg)})")
    print(f"  Customers:  {previous['unique_customers']} -> {current['unique_customers']} "
          f"({fmt_pct(customers_chg)})")
    print(f"{'=' * 50}\n")


def fmt_pct(val):
    if val is None:
        return "N/A (no prior data)"
    sign = "+" if val >= 0 else ""
    return f"{sign}{val}%"


def main():
    parser = argparse.ArgumentParser(description="E-Commerce summary report generator")
    parser.add_argument("--type", choices=["daily", "weekly", "monthly"],
                         help="Report type. If omitted, you'll be prompted.")
    parser.add_argument("--start", help="Start date YYYY-MM-DD. If omitted, you'll be prompted.")
    parser.add_argument("--end", help="End date YYYY-MM-DD. If omitted, you'll be prompted.")
    parser.add_argument("--db", help=f"Path to SQLite db (default: {DB_PATH})")
    args = parser.parse_args()

    report_type = args.type or input("Report type (daily/weekly/monthly): ").strip().lower()
    start_date = args.start or input("Start date (YYYY-MM-DD): ").strip()
    end_date = args.end or input("End date (YYYY-MM-DD): ").strip()

    print_report(report_type, start_date, end_date, args.db)


if __name__ == "__main__":
    main()
