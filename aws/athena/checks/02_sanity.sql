-- Sanity checks that the CSV and Parquet tables hold the same values.
-- Expected (DuckDB, local): avg rating 3.5403956487..., timestamp min 789652004, max 1697164147;
-- links: 124 empty tmdbId, 46,596 imdbId with a leading zero.
-- Note: queries (Trino engine) quote the reserved word as "timestamp";
-- backticks only work in the DDL (Hive) statements.
-- Run with: .\aws\athena_run.ps1 aws\athena\checks\02_sanity.sql

SELECT 'ratings_csv' AS tbl, avg(rating) AS avg_rating,
       min("timestamp") AS min_ts, max("timestamp") AS max_ts
FROM movielens.ratings_csv;

SELECT 'ratings_parquet' AS tbl, avg(rating) AS avg_rating,
       min("timestamp") AS min_ts, max("timestamp") AS max_ts
FROM movielens.ratings_parquet;

SELECT 'links_csv' AS tbl,
       count_if(tmdbId IS NULL OR trim(tmdbId) = '') AS empty_tmdbid,
       count_if(imdbId LIKE '0%') AS imdbid_leading_zero
FROM movielens.links_csv;
