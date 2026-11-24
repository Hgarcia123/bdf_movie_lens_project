-- Checks on the curated tables from the Glue job (Step 4).
-- Expected: ratings 32,000,204 | movies 87,585 | links 87,585;
-- avg(rating) 3.5403956487277393 (same as raw); 615 movies without a year
-- (local SQL: 613, but 3 of those local years are wrong, see step4 notes).
-- Run with: .\aws\athena_run.ps1 aws\athena\checks\03_curated_checks.sql -MaxRows 40

SELECT 'ratings_curated' AS tbl, count(*) AS row_count FROM movielens.ratings_curated;
SELECT 'movies_curated'  AS tbl, count(*) AS row_count FROM movielens.movies_curated;
SELECT 'links_curated'   AS tbl, count(*) AS row_count FROM movielens.links_curated;

SHOW PARTITIONS movielens.ratings_curated;

SELECT count(*) AS partitions, min(rating_year) AS first_year, max(rating_year) AS last_year
FROM "movielens"."ratings_curated$partitions";

SELECT avg(rating) AS avg_rating, min(rating) AS min_rating, max(rating) AS max_rating
FROM movielens.ratings_curated;

SELECT count_if(yearOfRelease IS NULL) AS null_yearOfRelease FROM movielens.movies_curated;

SELECT movieId, title FROM movielens.movies_curated
WHERE yearOfRelease IS NULL ORDER BY movieId LIMIT 10;

SELECT rating_year, count(*) AS ratings
FROM movielens.ratings_curated
GROUP BY rating_year ORDER BY rating_year;
