-- Ratings per rating year from the curated, partitioned ratings table.
-- Run with: .\aws\athena_run.ps1 aws\athena\exports\rows_per_year.sql -SaveCsv docs\aws\results\rows_per_year.csv -MaxRows 40

SELECT rating_year, count(*) AS "rows"
FROM movielens.ratings_curated
GROUP BY rating_year
ORDER BY rating_year;
