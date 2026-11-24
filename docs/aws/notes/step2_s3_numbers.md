# Step 2 — S3 raw zone: sizes and upload times

Bucket `bdf26-movielens-6339` (us-east-1, Block Public Access on), created and filled on 2026-11-23 by `aws/s3_upload.ps1`.
Layout: `raw/csv/<table>/<table>.csv` and `raw/parquet/<table>/<table>.parquet`. `curated/` and `athena-results/` come in later steps.

Sizes are object sizes in S3 (from `list-objects-v2`), in MB = 1024² bytes. Ratio = CSV size / Parquet size.

| Table | CSV size in S3 | Parquet size in S3 | Ratio | CSV upload time | Parquet upload time |
|---|---:|---:|---:|---:|---:|
| ratings | 836.45 MB | 208.81 MB | 4.01× | 21.6 s | 9.1 s |
| tags | 69.00 MB | 20.21 MB | 3.41× | 15.1 s | 5.1 s |
| movies | 4.05 MB | 2.11 MB | 1.92× | 9.2 s | 4.5 s |
| links | 1.86 MB | 1.27 MB | 1.46× | 3.7 s | 3.7 s |
| **Total** | **911.35 MB** | **232.41 MB** | **3.92×** | **49.6 s** | **22.4 s** |

Total upload time for all 8 files: 72.0 s (single run, each file timed separately with `Measure-Command`).

**Note on upload times:** these were measured from my home internet connection, so they measure the network (my upload bandwidth and latency), not AWS. Small files are dominated by fixed per-call overhead (CLI start-up, TLS, request round-trips), e.g. movies.csv (4 MB) took 9.2 s. The figures come from one run and aren't a benchmark; the stable result here is the size ratio, which shows Parquet storing the same data in about a quarter of the space.
