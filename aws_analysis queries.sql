--Ratings per Year
WITH movies_ratings AS (
    SELECT
        mov.title,
        mov.yearofrelease,
        rat.rating_year AS yearOfRating,
        (CAST(rat.rating_year AS INT) = mov.yearOfRelease) AS isReleaseYear,
        COUNT(*) AS n_ratings,
        ROUND(AVG(rat.rating), 1) AS avg_rating
    FROM "ratings" rat
    LEFT JOIN "movies" mov ON rat.movieId = mov.movieId
    GROUP BY
        mov.title,
        mov.yearofrelease,
        rat.rating_year
)
SELECT *
FROM movies_ratings
ORDER BY n_ratings DESC

--Tags and Genres similarity
-- Tags and Genres similarity
WITH genre_set AS (
    -- one row per movie per genre (genres are seperated by '|')
    SELECT m.movieId,
       lower(trim(g)) AS genre
    FROM movies m
    CROSS JOIN UNNEST(split(m.genres, '|')) AS u(g)
),
tag_set AS (
    -- one row per movie per distinct tag, with how often it was used
    SELECT movieId,
       lower(trim(tag)) AS tag,
       COUNT(*) AS tag_uses
    FROM tags
    GROUP BY movieId, lower(trim(tag))
),
genre_counts AS (
    SELECT movieId, COUNT(*) AS n_genres
    FROM genre_set
    GROUP BY movieId
),
tag_counts AS (
    SELECT movieId,
       COUNT(*)      AS n_tags,
       SUM(tag_uses) AS total_tag_uses
    FROM tag_set
    GROUP BY movieId
),
matches AS (
    -- case-insensitive matches between a tag and a genre
    SELECT g.movieId,
       COUNT(DISTINCT g.genre) AS matched_genres,
       SUM(t.tag_uses)         AS matched_tag_uses
    FROM genre_set g
    JOIN tag_set t
      ON g.movieId = t.movieId
     AND g.genre   = t.tag
    GROUP BY g.movieId
)
SELECT m.movieId,
   m.title,
   m.genres,
   gc.n_genres,
   COALESCE(tc.n_tags, 0)           AS n_distinct_tags,
   COALESCE(mt.matched_genres, 0)   AS matched_genres,

   -- Genre coverage: percentage of the movie's genres that also appear as tags
   CAST(COALESCE(mt.matched_genres, 0) AS double) / gc.n_genres
     AS genre_coverage,

   -- Tag precision: percentage of all tag usages that equal a genre
   CASE WHEN tc.total_tag_uses > 0
        THEN CAST(COALESCE(mt.matched_tag_uses, 0) AS double) / tc.total_tag_uses
        ELSE 0 END
     AS tag_precision
FROM movies m
JOIN genre_counts gc ON gc.movieId = m.movieId
LEFT JOIN tag_counts tc ON tc.movieId = m.movieId
LEFT JOIN matches mt ON mt.movieId = m.movieId
ORDER BY tag_precision DESC, n_distinct_tags DESC;

-- Wilhelm Scream average rating
SELECT
    AVG(rat.rating) as movielens_avg_rating,
    AVG(imdb_rating) as imdb_avg_rating,
    count(DISTINCT whs.imdb_id) as nr_films
FROM "wilhelmscreamdb_2026_11_06" whs
LEFT JOIN links lnk ON whs.imdb_id = lnk.imdb_tt
LEFT JOIN ratings rat ON lnk.movieid = rat.movieid;

-- Wilhelm Scream Genre Distribution
WITH exploded_genres AS (
    SELECT mov.title, g.genre
    FROM "wilhelmscreamdb_2026_11_06" whs
    INNER JOIN links lnk
        ON lnk.imdb_tt = whs.imdb_id
    INNER JOIN movies mov
        ON mov.movieid = lnk.movieid
    CROSS JOIN UNNEST(split(mov.genres, '|')) AS g(genre)
)
SELECT genre, count(*) AS movie_count
FROM exploded_genres
GROUP BY genre
ORDER BY movie_count DESC;

--Wilhelm Scream used scene types
WITH scenes_class AS (
    SELECT imdb_id,
       scene_description AS descr,
       CASE
         -- falls / being thrown
         WHEN regexp_like(lower(scene_description), '\b(fall|falls|falling|fell|thrown|throws?|knocked|ledge|cliff|pit|off the|over the|over a|tumbles?|plunges?|jumps?)\b') THEN 'Fall / thrown'
         -- explosions
         WHEN regexp_like(lower(scene_description), 'explo|\b(blast|blasted|bomb|grenade|blown)') THEN 'Explosion'
         -- ranged weapons
         WHEN regexp_like(lower(scene_description), '\b(shot|shoots?|shooting|fires?|firing|gun|guns|gunfire|weapons?|blaster|arrow|laser|rifle)') THEN 'Shot / arrow'
         -- melee combat
         WHEN regexp_like(lower(scene_description), '\b(stab|stabbed|sword|punch|punched|kick|kicked|fight|hit|spear|beat|beats|attacks?)') THEN 'Melee'
         -- creatures / monsters
         WHEN regexp_like(lower(scene_description), '\b(eaten|bitten|monster|creature|dinosaur|zombie|alien)') THEN 'Creature'
         -- vehicles / crashes
         WHEN regexp_like(lower(scene_description), '\b(car|cars|truck|crash|crashes|train|vehicle|plane|drives?|driving|limo|runs over|motorcycle)\b') THEN 'Vehicle'
         ELSE 'Other'
       END AS scene_type
    FROM "wilhelmscreamdb_2026_11_06"
    WHERE scene_description IS NOT NULL
)
SELECT scene_type,
   COUNT(*) AS n,
   ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct  -- share of all scenes
FROM scenes_class
GROUP BY scene_type
ORDER BY n DESC

-- Wilhelm scream rated peercentage
WITH wilhelm_movies AS (
    SELECT DISTINCT lnk.movieId
    FROM "wilhelmscreamdb_2026_11_06" wsh
    INNER JOIN links lnk
        ON wsh.imdb_id = lnk.imdb_tt
),
u AS (
    SELECT r.userId,
           COUNT_IF(wm.movieId IS NOT NULL) AS n_wilhelm
    FROM ratings r
    LEFT JOIN wilhelm_movies wm
        ON r.movieId = wm.movieId
    GROUP BY r.userId
)
SELECT COUNT(*)                                               AS n_users,
       ROUND(100.0 * COUNT_IF(n_wilhelm > 0) / COUNT(*), 1)   AS pct_users_rated_wilhelm,
       approx_percentile(n_wilhelm, 0.5)                      AS median_wilhelm_movies_per_user
FROM u