# Step 3 — Glue Data Catalog: row counts and first Athena numbers

Run on 2026-11-24 in us-east-1, workgroup `primary` (settings unchanged; results sent to
`s3://bdf26-movielens-6339/athena-results/` per query). Database `movielens`, 8 external tables
created by `aws/athena/ddl/00–02`. Runner: `aws/athena_run.ps1`, full log in `scratch/athena_log.csv`.

## Row counts: `SELECT count(*)` per table (`aws/athena/checks/01_row_counts.sql`)

| Table | Rows in Athena | Rows in DuckDB | Match? | Runtime (ms) | Data scanned (MB) |
|---|---:|---:|:---:|---:|---:|
| ratings_csv | 32,000,204 | 32,000,204 | ✅ | 1,455 | 836.47 |
| movies_csv | 87,585 | 87,585 | ✅ | 625 | 4.05 |
| tags_csv | 2,000,072 | 2,000,072 | ✅ | 1,179 | 69.00 |
| links_csv | 87,585 | 87,585 | ✅ | 578 | 1.86 |
| ratings_parquet | 32,000,204 | 32,000,204 | ✅ | 732 | 0.00 |
| movies_parquet | 87,585 | 87,585 | ✅ | 595 | 0.00 |
| tags_parquet | 2,000,072 | 2,000,072 | ✅ | 493 | 0.00 |
| links_parquet | 87,585 | 87,585 | ✅ | 491 | 0.00 |

MB = 1024² bytes. Single run each; runtimes are Athena engine time, not wall-clock.

**CSV vs Parquet for `count(*)`:** on CSV, Athena has to read the whole file to count lines (ratings_csv: 877,101,951 bytes, i.e. the full 836 MB object plus a little read overhead). On Parquet it scanned **0 bytes**: the row count is stored in each file's footer metadata, so no column data is read. Athena still bills a minimum of 10 MB per query, so even the Parquet counts aren't strictly free.

## Sanity checks (`aws/athena/checks/02_sanity.sql`)

| Query | Result | DuckDB | Match? | Runtime (ms) | Data scanned (MB) |
|---|---|---|:---:|---:|---:|
| ratings_csv: avg(rating), min/max(timestamp) | 3.5403956487277393, 789652004, 1697164147 | same | ✅ | 2,536 | 836.47 |
| ratings_parquet: same query | 3.5403956487277393, 789652004, 1697164147 | same | ✅ | 1,332 | 135.54 |
| links_csv: empty tmdbId, imdbId with leading zero | 124, 46,596 | 124, 46,596 | ✅ | 781 | 1.86 |

On a real aggregate, the Parquet table read only the two columns it needs (`rating`, `timestamp`): **135.5 MB vs 836.5 MB on CSV (6.2× less)** and about half the runtime. That's the first column-pruning number for Step 6.

## Notes

- imdbId is STRING in both CSV and Parquet (DuckDB kept it as VARCHAR), so the leading zeros survive (46,596 of 87,585). tmdbId is STRING in `links_csv` (124 empty values) and BIGINT in `links_parquet` (NULLs).
- `timestamp` is a reserved word: backticks in the DDL, but **double quotes in queries** (`"timestamp"`). The first run of 02_sanity.sql used backticks and was rejected with `MALFORMED_QUERY`; that attempt is in the log as `START_FAILED`.
