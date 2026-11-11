-- Queries on the full warehouse and the K-Means district segments.

-- ======================================================================
-- Market segment queries (run after notebook 02)
-- ======================================================================

-- 1. Deals and median price per m² by year and quarter
SELECT d.year, d.quarter, COUNT(*) AS deals, SUM(f.price) AS total_value_sar,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.price_per_m2)::numeric, 0) AS median_price_per_m2
FROM fact_deals f JOIN dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;

-- 2. Deals per source file
SELECT s.source_file, s.year, s.quarter, COUNT(*) AS deals
FROM fact_deals f JOIN dim_source s ON f.source_key = s.source_key
GROUP BY s.source_file, s.year, s.quarter
ORDER BY s.year, s.quarter;

-- 3. Segment profiles
SELECT segment_id, segment_name, COUNT(*) AS districts, SUM(deals) AS deals,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_price_per_m2)::numeric, 0) AS typical_price_per_m2,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_area)::numeric, 0) AS typical_area_m2,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_growth)::numeric, 2) AS typical_growth
FROM district_segment
GROUP BY segment_id, segment_name
ORDER BY segment_id;

-- 4. Residential price trend per segment
SELECT ds.segment_name, d.year, COUNT(*) AS deals,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.price_per_m2)::numeric, 0) AS median_price_per_m2
FROM fact_deals f
JOIN district_segment ds ON f.location_key = ds.location_key
JOIN dim_date d          ON f.date_key     = d.date_key
JOIN dim_property p      ON f.property_key = p.property_key
WHERE p.property_class = 'سكني'
GROUP BY ds.segment_id, ds.segment_name, d.year
ORDER BY ds.segment_id, d.year;

-- 5. Roll-up: segment > region
SELECT CASE WHEN GROUPING(ds.segment_name) = 1 THEN 'ALL SEGMENTS' ELSE ds.segment_name END AS segment,
       CASE WHEN GROUPING(l.region) = 1 THEN '-- segment total --' ELSE l.region END AS region,
       COUNT(DISTINCT ds.location_key) AS districts,
       SUM(ds.deals) AS deals
FROM district_segment ds JOIN dim_location l ON ds.location_key = l.location_key
GROUP BY ROLLUP (ds.segment_name, l.region)
ORDER BY GROUPING(ds.segment_name), ds.segment_name, GROUPING(l.region), deals DESC;

-- 6. Pivot: districts per segment in each region
SELECT l.region,
       COUNT(*) FILTER (WHERE ds.segment_id = 1) AS seg_1,
       COUNT(*) FILTER (WHERE ds.segment_id = 2) AS seg_2,
       COUNT(*) FILTER (WHERE ds.segment_id = 3) AS seg_3,
       COUNT(*) FILTER (WHERE ds.segment_id = 4) AS seg_4,
       COUNT(*) FILTER (WHERE ds.segment_id = 5) AS seg_5,
       COUNT(*) FILTER (WHERE ds.segment_id = 6) AS seg_6,
       COUNT(*) AS districts
FROM district_segment ds JOIN dim_location l ON ds.location_key = l.location_key
GROUP BY l.region
ORDER BY districts DESC;

-- 7. Top 5 districts per segment by number of deals
SELECT segment_name, rank, city, district, deals, median_price_per_m2, price_growth
FROM (
    SELECT ds.segment_id, ds.segment_name, l.city, l.district, ds.deals, ds.median_price_per_m2, ds.price_growth,
           RANK() OVER (PARTITION BY ds.segment_id ORDER BY ds.deals DESC) AS rank
    FROM district_segment ds JOIN dim_location l ON ds.location_key = l.location_key
) t
WHERE rank <= 5
ORDER BY segment_id, rank;
