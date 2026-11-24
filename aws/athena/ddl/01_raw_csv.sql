-- Creates the raw CSV tables movielens.ratings_csv, movies_csv, tags_csv and links_csv,
-- one external table per folder s3://bdf26-movielens-6339/raw/csv/<table>/.
-- OpenCSVSerDe handles quoted fields (movie titles and tags contain commas);
-- the header line is skipped. imdbId and tmdbId are STRING: imdbId keeps its
-- leading zeros (e.g. 0114709) and tmdbId has 124 empty values in links.csv.
-- Run with: .\aws\athena_run.ps1 aws\athena\ddl\01_raw_csv.sql

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.ratings_csv (
  userId      BIGINT,
  movieId     BIGINT,
  rating      DOUBLE,
  `timestamp` BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = ',', 'quoteChar' = '"', 'escapeChar' = '\\')
STORED AS TEXTFILE
LOCATION 's3://bdf26-movielens-6339/raw/csv/ratings/'
TBLPROPERTIES ('skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.movies_csv (
  movieId BIGINT,
  title   STRING,
  genres  STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = ',', 'quoteChar' = '"', 'escapeChar' = '\\')
STORED AS TEXTFILE
LOCATION 's3://bdf26-movielens-6339/raw/csv/movies/'
TBLPROPERTIES ('skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.tags_csv (
  userId      BIGINT,
  movieId     BIGINT,
  tag         STRING,
  `timestamp` BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = ',', 'quoteChar' = '"', 'escapeChar' = '\\')
STORED AS TEXTFILE
LOCATION 's3://bdf26-movielens-6339/raw/csv/tags/'
TBLPROPERTIES ('skip.header.line.count' = '1');

CREATE EXTERNAL TABLE IF NOT EXISTS movielens.links_csv (
  movieId BIGINT,
  imdbId  STRING,
  tmdbId  STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = ',', 'quoteChar' = '"', 'escapeChar' = '\\')
STORED AS TEXTFILE
LOCATION 's3://bdf26-movielens-6339/raw/csv/links/'
TBLPROPERTIES ('skip.header.line.count' = '1');
