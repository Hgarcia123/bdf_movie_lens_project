import duckdb
from pathlib import Path

DATA_DIR = Path("data/csv")

for csv in DATA_DIR.glob('*.csv'):
    print(f"Converting {csv} to parquet format...")

    out_dir = csv.parent.parent / "parquet"
    file = out_dir / csv.with_suffix(".parquet").name
    
    duckdb.sql(f"COPY (SELECT * FROM '{csv}') TO '{file}' (FORMAT parquet)")

    print("Done!")