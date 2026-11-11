-- Analysis, OLAP and data quality queries on the star schema.
-- Labels (A1, B1, ...) match the screenshots in docs/screenshots/.

-- ======================================================================
-- A. Basic analysis
-- ======================================================================

-- A1. Overall summary
SELECT COUNT(*)                         AS deals,
       SUM(price)                       AS total_value_sar,
       ROUND(AVG(price), 0)             AS avg_price,
       ROUND(AVG(area), 1)              AS avg_area_m2,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_m2)::numeric, 0) AS median_price_per_m2
FROM fact_deals;

-- A2. Sales by year
SELECT d.year,
       COUNT(*)                         AS deals,
       SUM(f.price)                     AS total_value_sar,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.price_per_m2)::numeric, 0) AS median_price_per_m2
FROM fact_deals f
JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.year
ORDER BY d.year;

-- A3. Sales by region
SELECT l.region,
       COUNT(*)                         AS deals,
       SUM(f.price)                     AS total_value_sar,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.price_per_m2)::numeric, 0) AS median_price_per_m2
FROM fact_deals f
JOIN dim_location l ON f.location_key = l.location_key
GROUP BY l.region
ORDER BY total_value_sar DESC;

-- A4. Sales by property class
SELECT p.property_class,
       COUNT(*)                         AS deals,
       SUM(f.price)                     AS total_value_sar,
       ROUND(AVG(f.price), 0)           AS avg_price
FROM fact_deals f
JOIN dim_property p ON f.property_key = p.property_key
GROUP BY p.property_class
ORDER BY deals DESC;

-- A5. Sales by source file
SELECT s.source_file, s.year,
       COUNT(*)                         AS deals,
       SUM(f.price)                     AS total_value_sar
FROM fact_deals f
JOIN dim_source s ON f.source_key = s.source_key
GROUP BY s.source_file, s.year
ORDER BY s.year;

-- ======================================================================
-- B. OLAP operations
-- ======================================================================

-- B1. Roll-up: region > city
SELECT CASE WHEN GROUPING(l.region) = 1 THEN 'ALL REGIONS' ELSE l.region END AS region,
       CASE WHEN GROUPING(l.city)   = 1 THEN '-- region total --' ELSE l.city END AS city,
       COUNT(*)     AS deals,
       SUM(f.price) AS total_value_sar
FROM fact_deals f
JOIN dim_location l ON f.location_key = l.location_key
GROUP BY ROLLUP (l.region, l.city)
ORDER BY GROUPING(l.region), l.region, GROUPING(l.city), total_value_sar DESC;

-- B2. Drill-down: year
SELECT d.year, COUNT(*) AS deals, SUM(f.price) AS total_value_sar
FROM fact_deals f JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.year
ORDER BY d.year;

-- B3. Drill-down: year > month
SELECT d.year, d.month, d.month_name, COUNT(*) AS deals, SUM(f.price) AS total_value_sar
FROM fact_deals f JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;

-- B4. Drill-down: top districts in Riyadh (الرياض)
SELECT l.city, l.district, COUNT(*) AS deals, SUM(f.price) AS total_value_sar
FROM fact_deals f JOIN dim_location l ON f.location_key = l.location_key
WHERE l.city = 'الرياض'
GROUP BY l.city, l.district
ORDER BY total_value_sar DESC
LIMIT 15;

-- B5. Slice: residential (سكني) deals only
SELECT d.year, COUNT(*) AS residential_deals,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.price_per_m2)::numeric, 0) AS median_price_per_m2
FROM fact_deals f
JOIN dim_property p ON f.property_key = p.property_key
JOIN dim_date d     ON f.date_key     = d.date_key
WHERE p.property_class = 'سكني'
GROUP BY d.year
ORDER BY d.year;

-- B6. Dice: residential deals in Riyadh and Eastern regions, 2024-2026
SELECT l.region, d.year, COUNT(*) AS deals,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.price_per_m2)::numeric, 0) AS median_price_per_m2
FROM fact_deals f
JOIN dim_location l ON f.location_key = l.location_key
JOIN dim_property p ON f.property_key = p.property_key
JOIN dim_date d     ON f.date_key     = d.date_key
WHERE p.property_class = 'سكني'
  AND (l.region LIKE '%الرياض%' OR l.region LIKE '%الشرقية%')
  AND d.year BETWEEN 2024 AND 2026
GROUP BY l.region, d.year
ORDER BY l.region, d.year;

-- B7. Ranking: most expensive Riyadh districts by median price per m² (50+ deals)
SELECT RANK() OVER (ORDER BY median_ppm DESC) AS rank, district, deals, median_ppm
FROM (
    SELECT l.district, COUNT(*) AS deals,
           ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.price_per_m2)::numeric, 0) AS median_ppm
    FROM fact_deals f JOIN dim_location l ON f.location_key = l.location_key
    WHERE l.city = 'الرياض' AND l.district <> 'غير محدد'
    GROUP BY l.district
    HAVING COUNT(*) >= 50
) t
ORDER BY rank
LIMIT 10;

-- B8. Cube: region x property class
SELECT COALESCE(l.region, 'ALL')          AS region,
       COALESCE(p.property_class, 'ALL')  AS property_class,
       COUNT(*) AS deals
FROM fact_deals f
JOIN dim_location l ON f.location_key = l.location_key
JOIN dim_property p ON f.property_key = p.property_key
GROUP BY CUBE (l.region, p.property_class)
ORDER BY l.region NULLS FIRST, p.property_class NULLS FIRST;

-- ======================================================================
-- C. Data quality checks
-- ======================================================================

-- C1. Reconciliation: staged vs loaded rows per file
SELECT s.source_file,
       s.staged,
       COALESCE(l.loaded, 0)              AS loaded,
       s.staged - COALESCE(l.loaded, 0)   AS rejected
FROM (SELECT source_file, COUNT(*) AS staged FROM stg_deals GROUP BY source_file) s
LEFT JOIN (SELECT ds.source_file, COUNT(*) AS loaded
           FROM fact_deals f JOIN dim_source ds ON f.source_key = ds.source_key
           GROUP BY ds.source_file) l
       ON s.source_file = l.source_file
ORDER BY s.source_file;

-- C2. Invalid values in the fact table
SELECT SUM(CASE WHEN price IS NULL OR price <= 0 THEN 1 ELSE 0 END) AS bad_price,
       SUM(CASE WHEN area  IS NULL OR area  <= 0 THEN 1 ELSE 0 END) AS bad_area,
       SUM(CASE WHEN price_per_m2 IS NULL        THEN 1 ELSE 0 END) AS missing_ppm
FROM fact_deals;

-- C3. Orphan foreign keys
SELECT
  (SELECT COUNT(*) FROM fact_deals f LEFT JOIN dim_date d     ON f.date_key     = d.date_key     WHERE d.date_key IS NULL)     AS orphan_date,
  (SELECT COUNT(*) FROM fact_deals f LEFT JOIN dim_location l ON f.location_key = l.location_key WHERE l.location_key IS NULL) AS orphan_location,
  (SELECT COUNT(*) FROM fact_deals f LEFT JOIN dim_property p ON f.property_key = p.property_key WHERE p.property_key IS NULL) AS orphan_property,
  (SELECT COUNT(*) FROM fact_deals f LEFT JOIN dim_source s   ON f.source_key   = s.source_key   WHERE s.source_key IS NULL)   AS orphan_source;

-- C4. Duplicate deals in staging
SELECT source_file, deal_id, COUNT(*) AS copies
FROM stg_deals
GROUP BY source_file, deal_id
HAVING COUNT(*) > 1
ORDER BY copies DESC
LIMIT 10;

-- C5. Price per m² outliers
SELECT COUNT(*) FILTER (WHERE price_per_m2 < 1)      AS below_1_sar_m2,
       COUNT(*) FILTER (WHERE price_per_m2 > 100000) AS above_100k_sar_m2
FROM fact_deals;
