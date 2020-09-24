-- Alternate method for third table in BDA_696 HW2
-- WORKS FOR MYSQL ONLY, WILL NOT RUN IN MARIADB
-- Significantly faster than self-join method

-- BEFORE RUNNING, disable full group by in mySQL:
-- SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));

USE baseball;

DROP TABLE IF EXISTS rolling_avg_day_faster

CREATE TABLE rolling_avg_day_faster
    SELECT DATE(g.local_date) AS game_date,
        batter,
        SUM(Hit)
            OVER (PARTITION BY batter 
            ORDER BY DATE(g.local_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING)
        /
        SUM(atBat)
            OVER (PARTITION BY batter
            ORDER BY DATE(g.local_date)
            RANGE BETWEEN INTERVAL '101' DAY PRECEDING AND INTERVAL '1' DAY PRECEDING) 
        AS roll_bat_avg
    FROM batter_counts bc
        JOIN game g ON bc.game_id = g.game_id 
            WHERE atBat > 0
    GROUP BY game_date, batter
    ORDER BY game_date;

SELECT *
FROM rolling_avg_day_faster;

SELECT *
FROM rolling_avg_day_faster WHERE batter = 110029;