"""
movielens_curate.py - Glue ETL job (PySpark) for the MovieLens 32M project.

Reproduces the local "support tables" (t_movies, t_ratings) in the cloud and adds
the links table for the Wilhelm join. Reads the raw Parquet files and writes
curated Parquet, all with mode overwrite:

  raw/parquet/movies/   -> curated/movies/    movieId, title (year removed), yearOfRelease, genres
  raw/parquet/ratings/  -> curated/ratings/   userId, movieId, rating (DOUBLE, half stars kept),
                                              dateOfRating (DATE, UTC), partitioned by rating_year
  raw/parquet/links/    -> curated/links/     movieId, imdbId (STRING), imdb_tt, tmdbId

Data-quality counts are printed to the job log and written as one CSV to
dq/movielens_curate/.

Job parameters: --BUCKET (e.g. bdf26-movielens-6339). Started by aws/glue/run_job.ps1.
"""
import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import Row
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME", "BUCKET"])
sc = SparkContext()
glue = GlueContext(sc)
spark = glue.spark_session
job = Job(glue)
job.init(args["JOB_NAME"], args)

# Dates come from unix timestamps; fix the time zone so they don't depend on the cluster.
spark.conf.set("spark.sql.session.timeZone", "UTC")

base = f"s3://{args['BUCKET']}"
raw = f"{base}/raw/parquet"
curated = f"{base}/curated"
dq_path = f"{base}/dq/movielens_curate/"

dq = []  # (table, metric, value)


def add_dq(table, metric, value):
    dq.append((table, metric, int(value)))
    print(f"DQ {table:<8} {metric:<32} {int(value):>12,}")


# --- movies --------------------------------------------------------------------
# A year at the end of the title: "(1995)", "(2007-)", "(1995-1997)" or with an
# en dash, optionally followed by spaces. The first 4-digit year is kept.
# ")+" also accepts one title with a doubled bracket, "... (1983))".
# Titles without this pattern keep their full title (only trimmed); titles that
# merely end in digits ("Irwin & Fran 2013") get no year.
YEAR_AT_END = r"\s*\((\d{4})(?:\s*[-–]\s*(?:\d{4})?)?\)+\s*$"

movies_raw = spark.read.parquet(f"{raw}/movies/")
year_str = F.regexp_extract(F.col("title"), YEAR_AT_END, 1)
movies = movies_raw.select(
    F.col("movieId").cast("bigint").alias("movieId"),
    F.trim(F.regexp_replace(F.col("title"), YEAR_AT_END, "")).alias("title"),
    F.when(year_str != "", year_str.cast("int")).alias("yearOfRelease"),
    F.col("genres"),
)
movies.write.mode("overwrite").parquet(f"{curated}/movies/")

add_dq("movies", "rows_in", movies_raw.count())
add_dq("movies", "rows_out", spark.read.parquet(f"{curated}/movies/").count())
add_dq("movies", "null_yearOfRelease", movies.filter(F.col("yearOfRelease").isNull()).count())

# --- ratings -------------------------------------------------------------------
ratings_raw = spark.read.parquet(f"{raw}/ratings/")
ratings = (
    ratings_raw.select(
        F.col("userId").cast("bigint").alias("userId"),
        F.col("movieId").cast("bigint").alias("movieId"),
        F.col("rating").cast("double").alias("rating"),
        F.to_date(F.from_unixtime(F.col("timestamp"))).alias("dateOfRating"),
    )
    .withColumn("rating_year", F.year("dateOfRating").cast("int"))
    .cache()
)

# One shuffle partition per year -> one file per rating_year folder.
(
    ratings.repartition("rating_year")
    .write.mode("overwrite")
    .partitionBy("rating_year")
    .parquet(f"{curated}/ratings/")
)

add_dq("ratings", "rows_in", ratings_raw.count())
add_dq("ratings", "rows_out", spark.read.parquet(f"{curated}/ratings/").count())
add_dq("ratings", "null_rating", ratings.filter(F.col("rating").isNull()).count())
add_dq("ratings", "rating_outside_0.5_5.0",
       ratings.filter((F.col("rating") < 0.5) | (F.col("rating") > 5.0)).count())
add_dq("ratings", "duplicate_userId_movieId_pairs",
       ratings.groupBy("userId", "movieId").count().filter(F.col("count") > 1).count())
add_dq("ratings", "ratings_without_movie",
       ratings.join(movies.select("movieId"), "movieId", "left_anti").count())
for r in ratings.groupBy("rating_year").count().orderBy("rating_year").collect():
    add_dq("ratings", f"rows_year_{r['rating_year']}", r["count"])

# --- links ---------------------------------------------------------------------
links_raw = spark.read.parquet(f"{raw}/links/")
links = links_raw.select(
    F.col("movieId").cast("bigint").alias("movieId"),
    F.col("imdbId").cast("string").alias("imdbId"),
    F.concat(F.lit("tt"), F.col("imdbId").cast("string")).alias("imdb_tt"),
    F.col("tmdbId").cast("bigint").alias("tmdbId"),
)
links.write.mode("overwrite").parquet(f"{curated}/links/")

add_dq("links", "rows_in", links_raw.count())
add_dq("links", "rows_out", spark.read.parquet(f"{curated}/links/").count())
add_dq("links", "null_tmdbId", links.filter(F.col("tmdbId").isNull()).count())

# --- data-quality report -------------------------------------------------------
(
    spark.createDataFrame([Row(table=t, metric=m, value=v) for t, m, v in dq])
    .coalesce(1)
    .write.mode("overwrite")
    .option("header", True)
    .csv(dq_path)
)
print(f"DQ report written to {dq_path}")

ratings.unpersist()
job.commit()
