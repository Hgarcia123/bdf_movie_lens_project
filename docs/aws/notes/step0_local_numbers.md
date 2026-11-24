# Step 0 — Local pipeline numbers (MovieLens 32M)

Run date: 2026-11-19 · branch `paulo_aws` (from `master` @ 1a8be6e) · single run, warm OS cache not controlled.

## Machine

| Item | Value |
|---|---|
| CPU | AMD Ryzen 5 5500U, 6 cores / 12 threads |
| RAM | 15.3 GB |
| Disk | NVMe SSD (SK hynix BC711, 512 GB) — repo folder is inside OneDrive |
| OS | Windows 11 Home 10.0.26200 |
| Python | 3.13.7 (64-bit), `.venv` |
| duckdb (Python package) | 2.0.0 (no duckdb CLI installed) |
| pandas | 3.1.1 |

## Conversion CSV → Parquet (`convert_csv_to_parquet.py`)

Total wall time (Measure-Command, incl. Python start-up): **9.95 s** for all 4 files.

| File | CSV (MB) | Parquet (MB) | Compression ratio |
|---|---:|---:|---:|
| links | 1.86 | 1.27 | 1.46× |
| movies | 4.05 | 2.11 | 1.92× |
| ratings | 836.45 | 208.81 | 4.01× |
| tags | 69.00 | 20.21 | 3.41× |
| **Total** | **911.35** | **232.41** | **3.92×** |

MB = MiB (1024²). Parquet written with DuckDB defaults (Snappy).

## `movie_lens_analysis_queries.sql` (via `scratch/run_sql.py`, one in-memory connection)

| # | Statement | Runtime (s) | Result |
|---|---|---:|---|
| 1 | CREATE TEMP TABLE t_movies | 0.155 | 87,585 rows |
| 2 | count(*) t_movies | 0.011 | 87,585 |
| 3 | nulls in yearOfRelease | 0.004 | 613 |
| 4 | preview t_movies (LIMIT 30) | 0.002 | |
| 5 | CREATE TEMP TABLE t_ratings | 1.682 | 32,000,204 rows |
| 6 | count(*) t_ratings | 0.005 | 32,000,204 |
| 7 | nulls in rating | 0.003 | 0 |
| 8 | preview t_ratings (LIMIT 50) | 0.005 | |
| 9 | COPY ratings_per_year → CSV | 5.431 | 487,289 rows, 19.90 MB |
| | **Total (statements)** | **7.316** | |
| | Wall time incl. Python start-up | 10.9 | |

## Row counts and nulls

| Check | Value | Expected |
|---|---:|---:|
| ratings rows | 32,000,204 | ≈ 32,000,204 ✔ |
| movies rows | 87,585 | 87,585 ✔ |
| yearOfRelease nulls | 613 (0.70%) | |
| rating nulls (after INTEGER cast) | 0 | |
| ratings with no matching movie | 0 | |

## Data-quality findings (for Henrique, not fixed)

| Finding | Number |
|---|---:|
| Half-star ratings distorted by `TRY_CAST(rating AS INTEGER)` | 10,005,686 (31.3%) |
| Ratings of 0.5 that become **0** (outside 1–5 scale) | 525,132 |
| Rounding is half-to-even: 1.5→2, 2.5→2, 3.5→4, 4.5→4 | |
| Global avg: original DOUBLE vs INTEGER cast | 3.5404 vs 3.5347 |
| Titles with no `(yyyy)` that still lose 7 chars (e.g. "Terrible Joe Moran" → "Terrible Jo") | 613 |
| Titles with trailing whitespace (LEFT uses untrimmed length) | 156 |
| (title, year) groups shared by >1 movieId, merged by the GROUP BY title | 215 groups / 472 movieIds |
