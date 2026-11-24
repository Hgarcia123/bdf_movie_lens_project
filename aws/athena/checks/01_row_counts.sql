-- Row count of each raw table (CSV and Parquet), one statement per table so the
-- runner logs runtime and data scanned per table. Expected (DuckDB, local):
-- ratings 32,000,204 | movies 87,585 | tags 2,000,072 | links 87,585
-- Run with: .\aws\athena_run.ps1 aws\athena\checks\01_row_counts.sql

SELECT 'ratings_csv'     AS tbl, count(*) AS row_count FROM movielens.ratings_csv;
SELECT 'movies_csv'      AS tbl, count(*) AS row_count FROM movielens.movies_csv;
SELECT 'tags_csv'        AS tbl, count(*) AS row_count FROM movielens.tags_csv;
SELECT 'links_csv'       AS tbl, count(*) AS row_count FROM movielens.links_csv;
SELECT 'ratings_parquet' AS tbl, count(*) AS row_count FROM movielens.ratings_parquet;
SELECT 'movies_parquet'  AS tbl, count(*) AS row_count FROM movielens.movies_parquet;
SELECT 'tags_parquet'    AS tbl, count(*) AS row_count FROM movielens.tags_parquet;
SELECT 'links_parquet'   AS tbl, count(*) AS row_count FROM movielens.links_parquet;
