# Step 4 — Glue ETL job: numbers

Job `bdf26-movielens-curate` (script `aws/glue/movielens_curate.py`, deployed and run by
`aws/glue/run_job.ps1`), run on 2026-11-24 in us-east-1. Reads `raw/parquet/`, writes
`curated/movies/`, `curated/ratings/` (partitioned by `rating_year`), `curated/links/` and the
dq report `dq/movielens_curate/`. Cataloged by `aws/athena/ddl/03_curated.sql`, checked by
`aws/athena/checks/03_curated_checks.sql`.

## Job run

| Item | Value |
|---|---|
| State | SUCCEEDED (first run) |
| Glue version | 5.0 (accepted, no fallback needed) |
| Workers | 2 × G.1X (1 DPU each) |
| ExecutionTime | 190 s (≈ 207 s from start request to SUCCEEDED) |
| DPU-seconds | 381 (reported by Glue) |
| Estimated cost | **$0.047** (381 / 3600 × $0.44 per DPU-hour) |

Single run. Learner Lab credit is used, not real money.

## Curated sizes in S3 (`aws s3 ls --summarize`)

MB = 1024² bytes. Raw Parquet sizes from Step 2 for comparison.

| Table | Objects | Curated size | Raw Parquet size | Note |
|---|---:|---:|---:|---|
| ratings | 29 (one per year) | 90.38 MB | 208.81 MB | `timestamp` → `dateOfRating`; rows grouped by year compress better |
| movies | 1 | 1.93 MB | 2.11 MB | year moved out of the title |
| links | 1 | 1.83 MB | 1.27 MB | extra `imdb_tt` column |

## Data-quality counts (`dq/movielens_curate/*.csv`, same values in the job log)

| Table | Metric | Value |
|---|---|---:|
| movies | rows in / out | 87,585 / 87,585 |
| movies | null yearOfRelease | 615 |
| ratings | rows in / out | 32,000,204 / 32,000,204 |
| ratings | null rating | 0 |
| ratings | rating outside 0.5–5.0 | 0 |
| ratings | duplicate (userId, movieId) pairs | 0 |
| ratings | ratings without a matching movie | 0 |
| links | rows in / out | 87,585 / 87,585 |
| links | null tmdbId | 124 |

## Athena checks on the curated tables

| Check | Athena | Expected / DuckDB | Match? | Runtime (ms) | Scanned (MB) |
|---|---|---|:---:|---:|---:|
| ratings_curated count | 32,000,204 | 32,000,204 | ✅ | 1,857 | 0.00 |
| movies_curated count | 87,585 | 87,585 | ✅ | 624 | 0.00 |
| links_curated count | 87,585 | 87,585 | ✅ | 748 | 0.00 |
| partitions | 29 (1995 → 2023) | 29 (1995 → 2023) | ✅ | 1,087 | 0.00 |
| avg(rating) | 3.5403956487277393 (min 0.5, max 5.0) | 3.5403956487277393 | ✅ | 1,271 | 14.42 |
| null yearOfRelease | 615 | 613 (local SQL) | see below | 602 | 0.08 |
| rows per rating_year | 29 years | 29 years, 0 differences | ✅ | 1,302 | 0.00 |

avg(rating) on `ratings_curated` scanned **14.4 MB**, against 135.5 MB on `ratings_parquet` and 836.5 MB on `ratings_csv` (Step 3). Rows per year scanned 0 bytes: Athena answered it from the partition layout and the Parquet metadata.

### Rows per rating_year: curated (Athena / Glue dq) vs DuckDB on the local Parquet

DuckDB ran with `SET TimeZone = 'UTC'`, the same zone as the Glue job. Size = curated Parquet file of that partition.

| Year | Curated size (MB) | Rows in Athena | Rows in DuckDB | Match? |
|---|---:|---:|---:|:---:|
| 1995 | 0.00 | 4 | 4 | ✅ |
| 1996 | 3.20 | 1,571,368 | 1,571,368 | ✅ |
| 1997 | 1.47 | 685,388 | 685,388 | ✅ |
| 1998 | 0.70 | 301,691 | 301,691 | ✅ |
| 1999 | 2.75 | 1,174,629 | 1,174,629 | ✅ |
| 2000 | 4.46 | 1,912,322 | 1,912,322 | ✅ |
| 2001 | 2.95 | 1,160,098 | 1,160,098 | ✅ |
| 2002 | 2.24 | 849,762 | 849,762 | ✅ |
| 2003 | 2.81 | 1,011,000 | 1,011,000 | ✅ |
| 2004 | 3.17 | 1,139,068 | 1,139,068 | ✅ |
| 2005 | 4.90 | 1,752,573 | 1,752,573 | ✅ |
| 2006 | 3.29 | 1,141,704 | 1,141,704 | ✅ |
| 2007 | 2.96 | 1,023,813 | 1,023,813 | ✅ |
| 2008 | 3.20 | 1,117,071 | 1,117,071 | ✅ |
| 2009 | 2.64 | 890,696 | 890,696 | ✅ |
| 2010 | 2.58 | 860,073 | 860,073 | ✅ |
| 2011 | 2.22 | 729,301 | 729,301 | ✅ |
| 2012 | 2.09 | 695,493 | 695,493 | ✅ |
| 2013 | 1.71 | 563,301 | 563,301 | ✅ |
| 2014 | 1.57 | 518,537 | 518,537 | ✅ |
| 2015 | 5.10 | 1,743,866 | 1,743,866 | ✅ |
| 2016 | 5.64 | 1,918,739 | 1,918,739 | ✅ |
| 2017 | 5.50 | 1,827,953 | 1,827,953 | ✅ |
| 2018 | 4.28 | 1,391,057 | 1,391,057 | ✅ |
| 2019 | 4.27 | 1,385,467 | 1,385,467 | ✅ |
| 2020 | 5.22 | 1,688,159 | 1,688,159 | ✅ |
| 2021 | 3.95 | 1,239,912 | 1,239,912 | ✅ |
| 2022 | 2.96 | 913,105 | 913,105 | ✅ |
| 2023 | 2.54 | 794,054 | 794,054 | ✅ |
| **Total** | **90.38** | **32,000,204** | **32,000,204** | ✅ |

No differences, so neither a time-zone effect nor a bug. Running DuckDB in Europe/Lisbon gives the same per-year counts too: Lisbon is UTC+0 around New Year, so no rating changes year. A UTC+1 or later zone could move ratings made just before midnight on 31 December into the next year.

### yearOfRelease: 615 (Glue) vs 613 (Henrique's local SQL)

The local SQL takes the last 5 characters of the trimmed title and casts the first 4 (`TRY_CAST(RIGHT(TRIM(title), 5)[1:4] AS INTEGER)`). The Glue job only takes a year from a `(yyyy…)` group at the end of the title. 5 movies differ:

| movieId | Title | Local year | Glue year | Correct |
|---:|---|---:|---:|---|
| 98063 | Mona and the Time of Burning Love (…) (1983)) | null | 1983 | Glue (doubled bracket in the source) |
| 171749 | Death Note: Desu nôto (2006–2007) | 2007 | 2006 | Glue (first year, as agreed) |
| 172451 | Irwin & Fran 2013 | 201 | null | Glue (no year in brackets; local gives a bogus value) |
| 175335 | The Garden of Afflictions 2017 | 201 | null | Glue (same) |
| 239314 | The Making of the Philadelphia Eagles Cheerleaders Lingerie Calendar 2005-2006 | -200 | null | Glue (same) |

So 613 + 3 (bogus local years now null) − 1 (doubled bracket now parsed) = 615. The local count is only lower because three titles get impossible years. This is worth raising with Henrique together with the title-cut issue: the Glue job keeps full titles when there's no year ("Terrible Joe Moran" stays whole).
