"""Run a .sql file statement by statement with the duckdb Python package.

Usage (from the repo root, because the SQL uses relative paths):
    .venv\\Scripts\\python.exe scratch\\run_sql.py movie_lens_analysis_queries.sql

Prints each statement, its result (first rows) and its runtime.
All statements share one in-memory connection, so TEMP tables persist.
"""
import sys
import time

import duckdb
import pandas as pd

pd.set_option("display.width", 200)
pd.set_option("display.max_columns", 20)

MAX_ROWS = 10


def main(path: str) -> None:
    sql = open(path, encoding="utf-8").read()
    con = duckdb.connect()  # in-memory
    statements = con.extract_statements(sql)
    timings = []
    total_start = time.perf_counter()

    for i, stmt in enumerate(statements, 1):
        text = stmt.query.strip()
        first_line = " ".join(text.split())[:90]
        print(f"\n=== [{i}/{len(statements)}] {first_line}")
        start = time.perf_counter()
        rel = con.execute(stmt)
        try:
            df = rel.fetchdf()
        except duckdb.InvalidInputException:
            df = None  # statement returned no result set
        elapsed = time.perf_counter() - start
        timings.append((i, first_line, elapsed))
        if df is not None and len(df.columns):
            print(df.head(MAX_ROWS).to_string(index=False))
            if len(df) > MAX_ROWS:
                print(f"... ({len(df)} rows total)")
        print(f"--- {elapsed:.3f} s")

    total = time.perf_counter() - total_start
    print("\n=== TIMINGS")
    for i, label, t in timings:
        print(f"{i:>2}  {t:8.3f} s  {label}")
    print(f"TOTAL {total:.3f} s")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "movie_lens_analysis_queries.sql")
