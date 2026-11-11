# Data

The source CSV files are not committed because they total about 250 MB.

**Source:** Real Estate Sales Transactions (الصفقات العقارية), Saudi Ministry of Justice, on the
[Saudi National Open Data Portal](https://open.data.gov.sa). A consolidated mirror of the quarterly files is
available at [civillizard/Saudi-Real-Estate-Data](https://github.com/civillizard/Saudi-Real-Estate-Data) (`moj/sales/`).

## Expected files

Save each quarter as UTF-8 and rename it to `deals_<year>_q<quarter>.csv`:

```
data/
├── deals_2020_q1.csv
├── deals_2020_q2.csv
├── ...
└── deals_2026_q1.csv
```

- `notebooks/01_q1_warehouse_etl.ipynb` uses only the 7 Q1 files (2020 to 2026).
- `notebooks/02_full_warehouse_kmeans.ipynb` uses all 25 files.

## Layouts

The files come in three column layouts. The notebooks detect and map them automatically.

| Columns | Fields |
|---|---|
| 10 | region, city, city/district, deal id, Gregorian date, Hijri date, property class, number of properties, price, area |
| 11 | same as 10, plus property type |
| 13 | deal id, region, city, district, plan, plot, Gregorian date, property class, property type, number of properties, price, area, price per m² |
