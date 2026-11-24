-- Creates the raw Parquet tables movielens.ratings_parquet, movies_parquet, tags_parquet
-- and links_parquet, one external table per folder s3://bdf26-movielens-6339/raw/parquet/<table>/.
-- Column types match the Parquet schema written by convert_csv_to_parquet.py
-- (DuckDB: BIGINT -> BIGINT, DOUBLE -> DOUBLE, VARCHAR -> STRING).
-- Run with: .\aws\athena_run.ps1 aws\athena\ddl\02_raw_parquet.sql

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.ratings_parquet (
  userId      BIGINT,
  movieId     BIGINT,
  rating      DOUBLE,
  `timestamp` BIGINT
)
STORED AS PARQUET
LOCATION 's3://bdf26-movielens-6339/raw/parquet/ratings/';

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.movies_parquet (
  movieId BIGINT,
  title   STRING,
  genres  STRING
)
STORED AS PARQUET
LOCATION 's3://bdf26-movielens-6339/raw/parquet/movies/';

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.tags_parquet (
  userId      BIGINT,
  movieId     BIGINT,
  tag         STRING,
  `timestamp` BIGINT
)
STORED AS PARQUET
LOCATION 's3://bdf26-movielens-6339/raw/parquet/tags/';

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.links_parquet (
  movieId BIGINT,
  imdbId  STRING,
  tmdbId  BIGINT
)
STORED AS PARQUET
LOCATION 's3://bdf26-movielens-6339/raw/parquet/links/';
