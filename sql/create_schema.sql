-- Star schema for the real estate data warehouse (PostgreSQL)
--
--   fact_deals        one row per transaction
--   dim_date          calendar attributes of the deal date
--   dim_location      region > city > district hierarchy
--   dim_property      property class (residential, commercial, ...)
--   dim_source        source file, year and quarter (lineage)
--   district_segment  K-Means market segment per district (filled by notebook 02)
--
-- Run this before each notebook. It drops and recreates every table.

DROP TABLE IF EXISTS district_segment, fact_deals, dim_date, dim_location, dim_property, dim_source CASCADE;

CREATE TABLE dim_date (
    date_key    INT PRIMARY KEY,
    full_date   DATE NOT NULL UNIQUE,
    day         INT NOT NULL,
    month       INT NOT NULL,
    month_name  VARCHAR(15) NOT NULL,
    quarter     INT NOT NULL,
    year        INT NOT NULL
);

CREATE TABLE dim_location (
    location_key  INT PRIMARY KEY,
    region        VARCHAR(100) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    district      VARCHAR(150),
    UNIQUE (region, city, district)
);

CREATE TABLE dim_property (
    property_key    INT PRIMARY KEY,
    property_class  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dim_source (
    source_key   INT PRIMARY KEY,
    source_file  VARCHAR(100) NOT NULL UNIQUE,
    year         INT NOT NULL,
    quarter      INT NOT NULL
);

CREATE TABLE fact_deals (
    deal_key        BIGINT PRIMARY KEY,
    deal_id         BIGINT NOT NULL,
    date_key        INT NOT NULL REFERENCES dim_date(date_key),
    location_key    INT NOT NULL REFERENCES dim_location(location_key),
    property_key    INT NOT NULL REFERENCES dim_property(property_key),
    source_key      INT NOT NULL REFERENCES dim_source(source_key),
    num_properties  INT,
    price           NUMERIC(15,2) NOT NULL CHECK (price > 0),
    area            NUMERIC(14,2) NOT NULL CHECK (area > 0),
    price_per_m2    NUMERIC(14,2)
);

CREATE TABLE district_segment (
    location_key        INT PRIMARY KEY REFERENCES dim_location(location_key),
    segment_id          INT NOT NULL,
    segment_name        VARCHAR(30) NOT NULL,
    deals               INT NOT NULL,
    median_price_per_m2 NUMERIC(14,2) NOT NULL,
    median_area         NUMERIC(14,2) NOT NULL,
    price_growth        NUMERIC(8,3) NOT NULL
);

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' ORDER BY table_name;
