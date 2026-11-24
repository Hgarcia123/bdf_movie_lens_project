import duckdb
con = duckdb.connect()
r = "'data/parquet/ratings.parquet'"; m = "'data/parquet/movies.parquet'"
q = lambda s: print(con.sql(s))
print("rating column type:"); q(f"DESCRIBE SELECT rating FROM {r}")
q(f"""SELECT count(*) FILTER (WHERE rating % 1 <> 0) AS half_star_ratings,
           round(100.0*count(*) FILTER (WHERE rating % 1 <> 0)/count(*),1) AS pct_half,
           round(avg(rating),4) AS avg_original,
           round(avg(TRY_CAST(rating AS INTEGER)),4) AS avg_int_cast FROM {r}""")
q(f"SELECT rating, TRY_CAST(rating AS INTEGER) AS as_int, count(*) n FROM {r} GROUP BY ALL ORDER BY 1")
print("titles whose year comes out NULL (sample):")
q(f"""SELECT title AS raw_title, LEFT(title, LENGTH(title)-7) AS parsed_title FROM {m}
      WHERE TRY_CAST(RIGHT(TRIM(title),5)[1:4] AS INTEGER) IS NULL LIMIT 8""")
q(f"SELECT count(*) AS titles_with_trailing_space FROM {m} WHERE title <> TRIM(title)")
q(f"""SELECT count(*) AS duplicate_titles, sum(n) AS movieIds_involved FROM
      (SELECT LEFT(title, LENGTH(title)-7) t, count(*) n FROM {m} GROUP BY t HAVING n>1)""")
