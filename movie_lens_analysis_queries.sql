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

--------------- t_links (links.csv) -------------------
CREATE OR REPLACE TEMP TABLE t_links AS
SELECT
    *
FROM './data/parquet/links.parquet';

-- Preview Table
SELECT
    movieId,
    imdbId,
    tmdbId
FROM t_links
Limit 40;

--------------- t_wilhelmscream (wilhelmscreamdb-2026-11-06.csv) -------------------
CREATE OR REPLACE TEMP TABLE t_wilhelmscream AS
SELECT
    Title,
    Year,
    "Media Type",
    "IMDb ID",
    -- Remove 'tt' characters at start of string to match keys on MovieLens Table
    substring("IMDb ID", 3) AS cln_imdb_id,
    "IMDb Rating",
    "Scream Timestamp",
    "Scene Description",
    "Video URL",
    "Entry URL",
    "Confirmed Votes",
    "Disputed Votes",
    Verification
FROM './data/parquet/wilhelmscreamdb-2026-11-06.parquet';

-- Preview Columns
DESCRIBE t_wilhelmscream;

-- Preview Table
SELECT
    Title,
    Year,
    "Media Type",
    "IMDb ID",
    cln_imdb_id,
    Verification
FROM t_wilhelmscream
LIMIT 100;

-- Check how many entries of wilhelm scream have a imdbID
SELECT
    SUM(CASE WHEN ("IMDb ID" is not null OR "IMDb ID" != '') then 1 ELSE 0 END) as count_nulls,
    count(*) as total
FROM t_wilhelmscream;

-- Only 5 Imdb Id's missing from 771, Let's continue.

-- There is a Verification column that specifies the sureness of the presence of the wilhelm scream 
SELECT
    Verification
    ,count(*) as count
FROM t_wilhelmscream
GROUP BY Verification
ORDER BY count(*) DESC;

-- 34 movies have been invalidated, so on the analysis we should filter these out.
-- 546 are unclear and 191 are verified. Unclear only means that it hasn't been manually verified that
-- the scream is used in the movie. So let's keep both 'Unclear' and 'Verified'.


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


-- Willhelm Scream Analysis
-- Create table with join tables of movies, links and wilhelmscream

CREATE OR REPLACE TEMP TABLE t_wilhelmscream_analysis AS
WITH movies_wilhelmscream AS(
    SELECT
        a.title, 
        a.genres,
        a.yearOfRelease,
        c."Media Type" as media_type,
        c."IMDb Rating" as imdb_rating,
        c.Verification
    FROM t_movies a
    INNER JOIN t_links b ON a.movieId = b.movieId
    INNER JOIN t_wilhelmscream c ON b.imdbId = c.cln_imdb_id
)
SELECT
    *
FROM movies_wilhelmscream
WHERE Verification <> 'Invalidated';

-- Total rows
SELECT count(*) FROM t_wilhelmscream_analysis;

-- Average rating of films with wilhelscream
SELECT
    AVG(imdb_rating) as avg_rating
FROM t_wilhelmscream_analysis;

-- Query to check the most recurring genres where th wilhelm scream appears

WITH exploded_genres AS (
    SELECT title, unnest(string_split(genres, '|')) AS genre
    FROM t_wilhelmscream_analysis
)
SELECT genre, count(*) AS movie_count
FROM exploded_genres
GROUP BY genre
ORDER BY movie_count DESC;

-- Query for distribution of wilhelm screams per year
SELECT
    yearOfRelease
    ,count(*)
FROM t_wilhelmscream_analysis
GROUP BY yearOfRelease
ORDER BY yearOfRelease ASC;

-- We can see the first time it was used, according to this data, was in 1950.
-- Let's check which movie this might be as it can be the original sample
SELECT
    *
FROM t_wilhelmscream_analysis
WHERE yearOfRelease = 1950;

-- We see that the film "Kim" is the first movie to have the Wilhelm scream, but the verification column marks it as "Unclear".
-- And performing a quick google research, the supposed original film using the Wilhelm scream was "Distant Drums (1951)".
-- To double check this, let's perform a query where it gets the first movie
-- ordered by yearOfRelease
with rank_films_by_year as(
    SELECT
        title,
        yearOfRelease,
        Verification,
        ROW_NUMBER() OVER(ORDER BY yearOfRelease ASC) as rn_appearence
    FROM t_wilhelmscream_analysis
    WHERE Verification <> 'Unclear'
)
SELECT
    *
FROM rank_films_by_year
where rn_appearence = 1;

-- This confirms it!