-- Creates the curated tables written by the Glue job aws/glue/movielens_curate.py:
-- movielens.movies_curated, links_curated (Parquet) and ratings_curated (Parquet,
-- partitioned by rating_year), then loads the ratings partitions with MSCK REPAIR TABLE.
-- Rerun MSCK REPAIR TABLE after a job run that adds new rating years.
-- Run with: .\aws\athena_run.ps1 aws\athena\ddl\03_curated.sql

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.movies_curated (
  movieId       BIGINT,
  title         STRING,
  yearOfRelease INT,
  genres        STRING
)
STORED AS PARQUET
LOCATION 's3://bdf26-movielens-6339/curated/movies/';

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.links_curated (
  movieId BIGINT,
  imdbId  STRING,
  imdb_tt STRING,
  tmdbId  BIGINT
)
STORED AS PARQUET
LOCATION 's3://bdf26-movielens-6339/curated/links/';

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.ratings_curated (
  userId       BIGINT,
  movieId      BIGINT,
  rating       DOUBLE,
  dateOfRating DATE
)
PARTITIONED BY (rating_year INT)
STORED AS PARQUET
LOCATION 's3://bdf26-movielens-6339/curated/ratings/';

MSCK REPAIR TABLE movielens.ratings_curated;
