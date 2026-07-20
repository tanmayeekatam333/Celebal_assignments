-- Part 3: SQL Analysis
-- Run against ecommerce.db (SQLite). Tables: orders, order_items, products, customers.

-- ============ BASIC QUERIES ============

-- 1. Total revenue per category
SELECT
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)), 2) AS total_revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
WHERE oi.quantity > 0
GROUP BY p.category
ORDER BY total_revenue DESC;

-- 2. Top 10 customers by total order value
SELECT
    c.customer_id,
    c.customer_name,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)), 2) AS total_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.quantity > 0
GROUP BY c.customer_id, c.customer_name
ORDER BY total_value DESC
LIMIT 10;

-- 3. Month-wise order count for the last 12 months
SELECT
    strftime('%Y-%m', order_date) AS year_month,
    COUNT(*) AS order_count
FROM orders
WHERE order_date >= date((SELECT MAX(order_date) FROM orders), '-12 months')
GROUP BY year_month
ORDER BY year_month;

-- ============ INTERMEDIATE QUERIES ============

-- 4. Customers who placed orders but never had any item delivered
SELECT DISTINCT o.customer_id
FROM orders o
WHERE o.customer_id IS NOT NULL
  AND o.customer_id NOT IN (
      SELECT customer_id FROM orders WHERE status = 'DELIVERED' AND customer_id IS NOT NULL
  );

-- 5. Products that were ordered but had more returns than purchases
SELECT
    p.product_id,
    p.product_name,
    SUM(CASE WHEN oi.quantity > 0 THEN oi.quantity ELSE 0 END) AS purchased_qty,
    SUM(CASE WHEN oi.quantity < 0 THEN -oi.quantity ELSE 0 END) AS returned_qty
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
HAVING returned_qty > purchased_qty;

-- 6. Return rate (returned items / total items) per category
SELECT
    p.category,
    SUM(CASE WHEN oi.quantity < 0 THEN -oi.quantity ELSE 0 END) AS returned_items,
    SUM(ABS(oi.quantity)) AS total_items,
    ROUND(100.0 * SUM(CASE WHEN oi.quantity < 0 THEN -oi.quantity ELSE 0 END)
          / NULLIF(SUM(ABS(oi.quantity)), 0), 2) AS return_rate_pct
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category;

-- ============ ADVANCED QUERIES ============

-- 7. Running total of revenue per region, ordered by date
WITH daily AS (
    SELECT
        o.region_code,
        date(o.order_date) AS order_date,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)) AS daily_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE oi.quantity > 0
    GROUP BY o.region_code, date(o.order_date)
)
SELECT
    region_code,
    order_date,
    ROUND(daily_revenue, 2) AS daily_revenue,
    ROUND(SUM(daily_revenue) OVER (
        PARTITION BY region_code ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS running_total
FROM daily
ORDER BY region_code, order_date;

-- 8. Rank products by total revenue within each category (DENSE_RANK, ties share rank)
WITH rev AS (
    SELECT
        p.category,
        p.product_name,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)) AS total_revenue
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    WHERE oi.quantity > 0
    GROUP BY p.category, p.product_name
)
SELECT
    category,
    product_name,
    ROUND(total_revenue, 2) AS total_revenue,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rank_in_category
FROM rev
ORDER BY category, rank_in_category;

-- 9. Days between consecutive orders per customer; flag "At Risk" if avg gap > 30 days
WITH ordered AS (
    SELECT
        customer_id,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order_date
    FROM orders
    WHERE customer_id IS NOT NULL
),
gaps AS (
    SELECT
        customer_id,
        order_date,
        previous_order_date,
        CASE WHEN previous_order_date IS NOT NULL
             THEN julianday(order_date) - julianday(previous_order_date)
        END AS days_gap
    FROM ordered
),
avg_gap AS (
    SELECT customer_id, AVG(days_gap) AS avg_gap
    FROM gaps
    WHERE days_gap IS NOT NULL
    GROUP BY customer_id
)
SELECT
    g.customer_id,
    g.order_date,
    g.previous_order_date,
    ROUND(g.days_gap, 1) AS days_gap,
    CASE WHEN a.avg_gap > 30 THEN 'At Risk' ELSE 'Normal' END AS risk_flag
FROM gaps g
JOIN avg_gap a ON a.customer_id = g.customer_id
ORDER BY g.customer_id, g.order_date;

-- 10. Multi-level CTE: monthly revenue per customer -> category -> monthly counts
WITH monthly_rev AS (
    SELECT
        o.customer_id,
        strftime('%Y-%m', o.order_date) AS year_month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.customer_id IS NOT NULL AND oi.quantity > 0
    GROUP BY o.customer_id, year_month
),
categorized AS (
    SELECT
        customer_id,
        year_month,
        revenue,
        CASE
            WHEN revenue > 10000 THEN 'High'
            WHEN revenue >= 5000 THEN 'Medium'
            ELSE 'Low'
        END AS value_category
    FROM monthly_rev
)
SELECT
    year_month,
    value_category,
    COUNT(DISTINCT customer_id) AS customer_count
FROM categorized
GROUP BY year_month, value_category
ORDER BY year_month, value_category;

-- 11. NTILE quartiles by customer lifetime value
WITH ltv AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)) AS total_value
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.customer_id IS NOT NULL AND oi.quantity > 0
    GROUP BY o.customer_id
)
SELECT
    customer_id,
    ROUND(total_value, 2) AS total_value,
    NTILE(4) OVER (ORDER BY total_value DESC) AS quartile,
    CASE NTILE(4) OVER (ORDER BY total_value DESC)
        WHEN 1 THEN 'Platinum'
        WHEN 2 THEN 'Gold'
        WHEN 3 THEN 'Silver'
        WHEN 4 THEN 'Bronze'
    END AS quartile_label
FROM ltv
ORDER BY total_value DESC;

-- 12. Year-over-year comparison per month
WITH monthly AS (
    SELECT
        CAST(strftime('%Y', o.order_date) AS INTEGER) AS year,
        CAST(strftime('%m', o.order_date) AS INTEGER) AS month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE oi.quantity > 0
    GROUP BY year, month
)
SELECT
    m.year,
    m.month,
    ROUND(m.revenue, 2) AS revenue,
    ROUND(p.revenue, 2) AS prev_year_revenue,
    CASE WHEN p.revenue IS NOT NULL AND p.revenue != 0
         THEN ROUND(100.0 * (m.revenue - p.revenue) / p.revenue, 2)
         ELSE NULL
    END AS yoy_growth_percent
FROM monthly m
LEFT JOIN monthly p ON p.year = m.year - 1 AND p.month = m.month
ORDER BY m.year, m.month;

-- 13. First vs. most recent purchased category per customer
WITH cat_orders AS (
    SELECT
        o.customer_id,
        o.order_date,
        p.category,
        ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_date ASC) AS rn_first,
        ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_date DESC) AS rn_last
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.customer_id IS NOT NULL
)
SELECT
    f.customer_id,
    f.category AS first_category,
    l.category AS most_recent_category,
    CASE WHEN f.category != l.category THEN 'Yes' ELSE 'No' END AS category_shift
FROM (SELECT * FROM cat_orders WHERE rn_first = 1) f
JOIN (SELECT * FROM cat_orders WHERE rn_last = 1) l ON l.customer_id = f.customer_id
ORDER BY f.customer_id;

-- 14. Cumulative revenue distribution across customers
WITH cust_rev AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100.0)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.customer_id IS NOT NULL AND oi.quantity > 0
    GROUP BY o.customer_id
),
total AS (SELECT SUM(revenue) AS grand_total FROM cust_rev)
SELECT
    customer_id,
    ROUND(revenue, 2) AS revenue,
    ROUND(SUM(revenue) OVER (ORDER BY revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS cumulative_revenue,
    ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / (SELECT grand_total FROM total), 2) AS cumulative_percent
FROM cust_rev
ORDER BY revenue DESC;

-- 15. Cohort analysis by registration month
WITH cohorts AS (
    SELECT customer_id, strftime('%Y-%m', registration_date) AS cohort_month
    FROM customers
),
customer_orders AS (
    SELECT DISTINCT customer_id, strftime('%Y-%m', order_date) AS order_month
    FROM orders
    WHERE customer_id IS NOT NULL
),
cohort_activity AS (
    SELECT
        c.cohort_month,
        c.customer_id,
        (CAST(strftime('%Y', co.order_month || '-01') AS INTEGER) * 12
            + CAST(strftime('%m', co.order_month || '-01') AS INTEGER))
        -
        (CAST(strftime('%Y', c.cohort_month || '-01') AS INTEGER) * 12
            + CAST(strftime('%m', c.cohort_month || '-01') AS INTEGER)) AS month_offset
    FROM cohorts c
    JOIN customer_orders co ON co.customer_id = c.customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size FROM cohorts GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    cs.cohort_size,
    SUM(CASE WHEN ca.month_offset = 0 THEN 1 ELSE 0 END) AS month_0,
    SUM(CASE WHEN ca.month_offset = 1 THEN 1 ELSE 0 END) AS month_1,
    SUM(CASE WHEN ca.month_offset = 2 THEN 1 ELSE 0 END) AS month_2,
    SUM(CASE WHEN ca.month_offset = 3 THEN 1 ELSE 0 END) AS month_3,
    ROUND(100.0 * SUM(CASE WHEN ca.month_offset = 1 THEN 1 ELSE 0 END) / cs.cohort_size, 1) AS retention_m1_pct,
    ROUND(100.0 * SUM(CASE WHEN ca.month_offset = 2 THEN 1 ELSE 0 END) / cs.cohort_size, 1) AS retention_m2_pct,
    ROUND(100.0 * SUM(CASE WHEN ca.month_offset = 3 THEN 1 ELSE 0 END) / cs.cohort_size, 1) AS retention_m3_pct
FROM cohort_activity ca
JOIN cohort_sizes cs ON cs.cohort_month = ca.cohort_month
GROUP BY ca.cohort_month, cs.cohort_size
ORDER BY ca.cohort_month;

-- 16. Products frequently bought together (self-join within the same order)
SELECT
    p1.product_name AS product_a,
    p2.product_name AS product_b,
    COUNT(*) AS times_bought_together
FROM order_items oi1
JOIN order_items oi2 ON oi1.order_id = oi2.order_id AND oi1.product_id < oi2.product_id
JOIN products p1 ON p1.product_id = oi1.product_id
JOIN products p2 ON p2.product_id = oi2.product_id
WHERE oi1.quantity > 0 AND oi2.quantity > 0
GROUP BY p1.product_name, p2.product_name
ORDER BY times_bought_together DESC
LIMIT 50;
