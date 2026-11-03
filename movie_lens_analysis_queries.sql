--------------- SUPPORT TABLES --------------------------

--------------- t_movies (movies.csv) -------------------

CREATE OR REPLACE TEMP TABLE t_movies AS
SELECT 
    movieId,
    LEFT(title, LENGTH(title)-7) AS title,
    TRY_CAST(RIGHT(TRIM(title), 5)[1:4] AS INTEGER) as yearOfRelease,
    genres
FROM './data/parquet/movies.parquet';

-- Count n_rows in table
SELECT count(*) as totalRows FROM t_movies;

-- Check nulls in year of release 
SELECT count(*) as yearNulls FROM t_movies
WHERE yearOfRelease is null;

-- Preview table
SELECT * FROM t_movies
LIMIT 30;

--------------- t_ratings (ratings.csv) -------------------
CREATE OR REPLACE TEMP TABLE t_ratings AS
SELECT
    userId,
    movieId,
    TRY_CAST(rating AS INTEGER) as rating,
    CAST(to_timestamp(timestamp) AS DATE) as dateOfRating
FROM './data/parquet/ratings.parquet';

-- Count n_rows in table
SELECT count(*) FROM t_ratings;


-- Count nulls in rating
SELECT count(*) FROM t_ratings
WHERE rating is NULL;

-- Preview table
SELECT * FROM t_ratings LIMIT 50;

--------------- ANALYSIS ---------------

-- Compare volume and average of ratings in year of release vs later years

-- Create table with join tables of movies and ratings
-- flag column for year of release
-- Aggregate count of ratings per year of rating

COPY(
    WITH movies_ratings AS(
        SELECT
            mov.title,
            mov.yearOfRelease,
            year(rat.dateOfRating) as yearOfRating,
            (year(rat.dateOfRating) = mov.yearOfRelease) as isReleaseYear,
            count(*) as n_ratings,
            ROUND(avg(rating), 1) as avg_rating
        FROM t_ratings rat
        LEFT JOIN t_movies mov ON rat.movieId = mov.movieId
        GROUP BY
            title,
            mov.yearOfRelease,
            yearOfRating,
            isReleaseYear
    )
    select 
        *
    from movies_ratings
    ORDER BY n_ratings DESC
) TO './query_results_csv/ratings_per_year.csv';